-- Executar depois do 01 ao 06 (como root ou dba_fincore).
USE fincore;
-- acentos: o cliente envia o texto em UTF-8 (sem isso o mysql do container usa latin1 e estraga ã, é etc.)
SET NAMES utf8mb4;

-- precisa disso pra criar trigger/function com o log binário ligado (ver 05_funcoes_id.sql)
SET GLOBAL log_bin_trust_function_creators = 1;

DROP TRIGGER   IF EXISTS trg_transacao_valida;
DROP TRIGGER   IF EXISTS trg_transacao_saldo;
DROP FUNCTION  IF EXISTS fn_saldo_disponivel;
DROP PROCEDURE IF EXISTS sp_transferir;
DROP PROCEDURE IF EXISTS sp_pagar_parcela;

DELIMITER //

-- 1. TRIGGERS

-- 1.1 trg_transacao_valida (antes de inserir transação): só deixa movimentar conta ATIVA
-- conta BLOQUEADA ou ENCERRADA não envia nem recebe dinheiro, venha da API, de procedure ou de INSERT manual
CREATE TRIGGER trg_transacao_valida
BEFORE INSERT ON transacao
FOR EACH ROW
BEGIN
    IF (SELECT status FROM conta WHERE id_conta = NEW.id_conta_origem) <> 'ATIVA' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conta de origem bloqueada ou encerrada';
    END IF;

    IF (SELECT status FROM conta WHERE id_conta = NEW.id_conta_destino) <> 'ATIVA' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conta de destino bloqueada ou encerrada';
    END IF;
END //

-- 1.2 trg_transacao_saldo (depois de inserir transação): debita a origem e credita o destino
-- assim o conta.saldo nunca fica diferente da soma das transações (RN08), ninguém precisa lembrar de atualizar
CREATE TRIGGER trg_transacao_saldo
AFTER INSERT ON transacao
FOR EACH ROW
BEGIN
    UPDATE conta SET saldo = saldo - NEW.valor WHERE id_conta = NEW.id_conta_origem;
    UPDATE conta SET saldo = saldo + NEW.valor WHERE id_conta = NEW.id_conta_destino;
END //

-- 2. FUNCTION

-- 2.1 fn_saldo_disponivel(id_conta): saldo + limite do cheque especial (poupança tem limite 0)
-- é o quanto a conta ainda pode gastar, se der negativo passou do limite (RN09); usada pelas procedures
CREATE FUNCTION fn_saldo_disponivel(p_id_conta BIGINT)
RETURNS DECIMAL(18,2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_saldo  DECIMAL(18,2);
    DECLARE v_limite DECIMAL(18,2);

    SELECT c.saldo, COALESCE(cc.limite_cheque_especial, 0)
    INTO v_saldo, v_limite
    FROM conta c
    LEFT JOIN conta_corrente cc ON cc.id_conta = c.id_conta
    WHERE c.id_conta = p_id_conta;

    RETURN v_saldo + v_limite;
END //

-- 3. PROCEDURES (com START TRANSACTION, COMMIT e ROLLBACK)

-- 3.1 sp_transferir(origem, destino, valor, chave): transfere entre duas contas, é a única forma da API mexer em dinheiro
-- são vários passos (gerar ID, gravar a transação, mexer em dois saldos): ou acontece tudo (COMMIT) ou nada (ROLLBACK)
-- a chave (chave_idempotencia) impede que a mesma transferência seja feita duas vezes
CREATE PROCEDURE sp_transferir(
    IN p_conta_origem  BIGINT,
    IN p_conta_destino BIGINT,
    IN p_valor         DECIMAL(18,2),
    IN p_chave         VARCHAR(64))
BEGIN
    DECLARE v_id_transacao BIGINT;

    -- se qualquer comando abaixo der erro: desfaz tudo e repassa o erro pra quem chamou
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- validações (cada erro tem uma mensagem própria, que a API mostra na tela)
    IF p_valor IS NULL OR p_valor <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Valor inválido: precisa ser maior que zero';
    END IF;
    IF p_conta_origem = p_conta_destino THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Origem e destino precisam ser contas diferentes';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM conta WHERE id_conta = p_conta_origem) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conta de origem não existe';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM conta WHERE id_conta = p_conta_destino) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conta de destino não existe';
    END IF;
    IF EXISTS (SELECT 1 FROM transacao WHERE chave_idempotencia = p_chave) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Chave repetida: esta transferência já foi feita';
    END IF;

    -- grava a transação (o trigger trg_transacao_saldo debita e credita os saldos)
    SET v_id_transacao = fn_gerar_id('transacao');
    INSERT INTO transacao (id_transacao, id_conta_origem, id_conta_destino, tipo, descricao, valor, chave_idempotencia)
    VALUES (v_id_transacao, p_conta_origem, p_conta_destino, 'TRANSFERENCIA', 'Transferência entre contas', p_valor, p_chave);

    -- confere o saldo depois do débito: se passou do limite o erro cai no EXIT HANDLER,
    -- que faz ROLLBACK e desfaz o INSERT, os dois saldos e o ID gerado
    IF fn_saldo_disponivel(p_conta_origem) < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Saldo insuficiente';
    END IF;

    COMMIT;

    -- devolve o resultado pra API
    SELECT v_id_transacao AS id_transacao,
           (SELECT saldo FROM conta WHERE id_conta = p_conta_origem)  AS saldo_origem,
           (SELECT saldo FROM conta WHERE id_conta = p_conta_destino) AS saldo_destino;
END //

-- 3.2 sp_pagar_parcela(id_emprestimo, nr_parcela): paga uma parcela com o saldo da conta do cliente
-- dar baixa na parcela e debitar a conta precisam andar juntos: se o débito falhar (sem saldo) a baixa
-- também é desfeita pelo ROLLBACK; no fim, se não sobrou parcela em aberto, o empréstimo fica QUITADO
CREATE PROCEDURE sp_pagar_parcela(
    IN p_id_emprestimo BIGINT,
    IN p_nr_parcela    SMALLINT)
BEGIN
    DECLARE v_id_conta BIGINT;
    DECLARE v_valor    DECIMAL(12,2);
    DECLARE v_status   VARCHAR(10);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- busca a parcela e trava a linha (FOR UPDATE) pra ninguém pagar ao mesmo tempo
    SELECT e.id_conta, p.valor_parcela + p.valor_multa, p.status
    INTO v_id_conta, v_valor, v_status
    FROM parcela_emprestimo p
    INNER JOIN emprestimo e ON e.id_emprestimo = p.id_emprestimo
    WHERE p.id_emprestimo = p_id_emprestimo AND p.nr_parcela = p_nr_parcela
    FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Parcela não encontrada';
    END IF;
    IF v_status = 'PAGA' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Esta parcela já está paga';
    END IF;

    -- baixa da parcela
    UPDATE parcela_emprestimo
    SET status = 'PAGA', dt_pagamento = CURDATE()
    WHERE id_emprestimo = p_id_emprestimo AND nr_parcela = p_nr_parcela;

    -- débito na conta do cliente e crédito na conta 1 (conta interna do banco)
    INSERT INTO transacao (id_transacao, id_conta_origem, id_conta_destino, id_categoria, tipo, descricao, valor, chave_idempotencia)
    VALUES (fn_gerar_id('transacao'), v_id_conta, 1, 9, 'PAGAMENTO',
            CONCAT('Parcela ', p_nr_parcela, ' do empréstimo ', p_id_emprestimo),
            v_valor, CONCAT('parcela-', p_id_emprestimo, '-', p_nr_parcela));

    -- sem saldo: o erro dispara o ROLLBACK, que desfaz a baixa e o débito
    IF fn_saldo_disponivel(v_id_conta) < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Saldo insuficiente para pagar a parcela';
    END IF;

    -- se todas as parcelas estão pagas, o empréstimo está quitado
    UPDATE emprestimo
    SET status = 'QUITADO'
    WHERE id_emprestimo = p_id_emprestimo
      AND NOT EXISTS (SELECT 1 FROM parcela_emprestimo
                      WHERE id_emprestimo = p_id_emprestimo AND status <> 'PAGA');

    COMMIT;
END //

DELIMITER ;

-- 4. acesso da API (app_fincore)
-- a API só mexe em dinheiro pela sp_transferir: ganha EXECUTE só nela e perde o direito de alterar saldo
-- ou gravar transação direto (procedure e trigger rodam com os privilégios de quem criou)
-- a sp_pagar_parcela não é usada pela API, então a API não pode executar
GRANT EXECUTE ON PROCEDURE fincore.sp_transferir TO 'app_fincore'@'%';
REVOKE UPDATE ON fincore.conta     FROM 'app_fincore'@'%';
REVOKE INSERT ON fincore.transacao FROM 'app_fincore'@'%';

SHOW GRANTS FOR 'app_fincore'@'%';
