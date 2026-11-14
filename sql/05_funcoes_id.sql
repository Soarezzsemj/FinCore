-- Executar depois do 01, 02 e 04 (como root ou dba_fincore).
-- por que gerar o ID no banco e nao com AUTO_INCREMENT: nos dados criticos a numeração fica numa tabela
-- que dá pra consultar e corrigir, a procedure sabe o ID antes do INSERT e, se der ROLLBACK, o
-- incremento também é desfeito (sem "buracos"). as tabelas de apoio continuam com AUTO_INCREMENT (ver 01)
USE fincore;
-- acentos: o cliente envia o texto em UTF-8 (sem isso o mysql do container usa latin1 e estraga ã, é etc.)
SET NAMES utf8mb4;

-- com o log binário ligado (padrão do MySQL 8) só dá pra criar função que altera dados com isso ligado
SET GLOBAL log_bin_trust_function_creators = 1;

-- 1. sequencia: guarda o último ID usado de cada tabela (é o contador que a fn_gerar_id incrementa)
CREATE TABLE sequencia (
    nome         VARCHAR(30) PRIMARY KEY,   -- nome da tabela dona do ID
    ultimo_valor BIGINT      NOT NULL DEFAULT 0
);

-- 1.1 cada contador começa no maior ID que já veio dos dados de exemplo
INSERT INTO sequencia (nome, ultimo_valor)
SELECT 'cliente',       COALESCE(MAX(id_cliente), 0)    FROM cliente       UNION ALL
SELECT 'conta',         COALESCE(MAX(id_conta), 0)      FROM conta         UNION ALL
SELECT 'transacao',     COALESCE(MAX(id_transacao), 0)  FROM transacao     UNION ALL
SELECT 'cartao',        COALESCE(MAX(id_cartao), 0)     FROM cartao        UNION ALL
SELECT 'fatura_cartao', COALESCE(MAX(id_fatura), 0)     FROM fatura_cartao UNION ALL
SELECT 'compra_cartao', COALESCE(MAX(id_compra), 0)     FROM compra_cartao UNION ALL
SELECT 'emprestimo',    COALESCE(MAX(id_emprestimo), 0) FROM emprestimo    UNION ALL
SELECT 'aplicacao',     COALESCE(MAX(id_aplicacao), 0)  FROM aplicacao     UNION ALL
SELECT 'usuarios',      COALESCE(MAX(id_usuario), 0)    FROM usuarios;

-- 2. fn_gerar_id('conta'): devolve o próximo ID da tabela pedida (única forma de gerar ID nos dados criticos)
-- concorrência: o UPDATE trava a linha da sequência até o fim da transação, então se duas pessoas pedirem
-- ao mesmo tempo a segunda espera a primeira e nunca saem dois IDs iguais
-- LAST_INSERT_ID(valor) guarda o número novo só pra essa conexão e a função devolve sem outro SELECT
DROP FUNCTION IF EXISTS fn_gerar_id;

DELIMITER //
CREATE FUNCTION fn_gerar_id(p_nome_tabela VARCHAR(30))
RETURNS BIGINT
NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
    UPDATE sequencia
    SET ultimo_valor = LAST_INSERT_ID(ultimo_valor + 1)
    WHERE nome = p_nome_tabela;

    -- nenhuma linha alterada = nome de tabela que não tem sequência
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sequência não encontrada para esta tabela';
    END IF;

    RETURN LAST_INSERT_ID();
END //
DELIMITER ;

-- 3. exemplo de uso
-- INSERT INTO cliente (id_cliente, tipo, nome_razao, documento, email)
-- VALUES (fn_gerar_id('cliente'), 'PF', 'Fulano', '44444444444', 'fulano@email.com');

-- 3.1 teste: duas chamadas seguidas devolvem números diferentes e crescentes (descomenta ai pra testar)
-- SELECT fn_gerar_id('conta');
-- SELECT fn_gerar_id('conta');
