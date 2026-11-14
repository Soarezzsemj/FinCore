-- Executar depois do 07_triggers_procedures.sql (demonstração de COMMIT e ROLLBACK ao vivo).
-- no Workbench roda UM comando por vez (Ctrl+Enter com o cursor no comando), os erros são de propósito
-- e o Workbench para o script inteiro quando acha um erro
-- contas usadas: 2 = Ana (cheque especial de R$ 1.000), 4 = Bruno
USE fincore;
-- acentos: o cliente envia o texto em UTF-8 (sem isso o mysql do container usa latin1 e estraga ã, é etc.)
SET NAMES utf8mb4;

-- 1. transferência que dá certo (COMMIT)

-- 1.1 saldos antes
SELECT id_conta, titular, saldo, saldo_disponivel FROM vw_contas_cliente WHERE id_conta IN (2, 4);

-- 1.2 Ana transfere R$ 100,00 para o Bruno
CALL sp_transferir(2, 4, 100.00, 'demo-commit-001');

-- 1.3 saldos depois: Ana com 100 a menos e Bruno com 100 a mais
SELECT id_conta, titular, saldo, saldo_disponivel FROM vw_contas_cliente WHERE id_conta IN (2, 4);

-- 1.4 a transação aparece no extrato da Ana
SELECT * FROM vw_extrato_conta WHERE id_conta = 2 ORDER BY dt_hora DESC, id_transacao DESC LIMIT 3;

-- 2. transferência que falha e é desfeita (ROLLBACK)
-- a procedure grava a transação e debita a Ana, mas na conferência vê que passou do limite,
-- o erro dispara o ROLLBACK e desfaz tudo

-- 2.1 saldos e último ID de transação antes
SELECT id_conta, titular, saldo FROM vw_contas_cliente WHERE id_conta IN (2, 4);
SELECT ultimo_valor AS ultimo_id_transacao FROM sequencia WHERE nome = 'transacao';

-- 2.2 Ana tenta transferir R$ 1.000.000,00 (é pra dar erro "Saldo insuficiente")
CALL sp_transferir(2, 4, 1000000.00, 'demo-rollback-001');

-- 2.3 saldos e último ID depois: iguais aos do 2.1 (nada ficou gravado)
SELECT id_conta, titular, saldo FROM vw_contas_cliente WHERE id_conta IN (2, 4);
SELECT ultimo_valor AS ultimo_id_transacao FROM sequencia WHERE nome = 'transacao';
SELECT COUNT(*) AS transacoes_com_esta_chave FROM transacao WHERE chave_idempotencia = 'demo-rollback-001';

-- 3. outros erros, cada um com mensagem própria
CALL sp_transferir(2, 4, 100.00, 'demo-commit-001');   -- chave repetida
CALL sp_transferir(2, 999, 100.00, 'demo-erro-002');   -- conta de destino não existe
CALL sp_transferir(2, 4, -5.00, 'demo-erro-003');      -- valor inválido

-- 4. pagamento de parcela (baixa da parcela + débito na mesma transação)
SELECT nr_parcela, status, dt_pagamento FROM parcela_emprestimo WHERE id_emprestimo = 1 AND nr_parcela <= 2;
CALL sp_pagar_parcela(1, 2);
SELECT nr_parcela, status, dt_pagamento FROM parcela_emprestimo WHERE id_emprestimo = 1 AND nr_parcela <= 2;
CALL sp_pagar_parcela(1, 2);                            -- erro: parcela já está paga
