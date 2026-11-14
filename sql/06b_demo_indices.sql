-- Executar depois do 06_views.sql, como root ou dba_fincore (demonstração pra apresentação).
-- apaga o índice, mostra o plano, recria e mostra de novo; no fim o banco fica igual estava
-- como ler o EXPLAIN: type ALL = lê a tabela inteira, type ref = vai direto nas linhas pelo índice,
-- key = índice usado (NULL = nenhum), rows = quantas linhas o MySQL acha que vai ler
USE fincore;
-- acentos: o cliente envia o texto em UTF-8 (sem isso o mysql do container usa latin1 e estraga ã, é etc.)
SET NAMES utf8mb4;

-- 1. antes: sem o índice no nome do cliente
DROP INDEX idx_cliente_nome ON cliente;

-- 1.1 esperado: type = ALL, key = NULL (lê a tabela inteira)
EXPLAIN SELECT id_cliente, nome_razao, email
FROM cliente
WHERE nome_razao = 'Bruno Lima';

-- 2. depois: com o índice
CREATE INDEX idx_cliente_nome ON cliente (nome_razao);

-- 2.1 esperado: type = ref, key = idx_cliente_nome (vai direto na linha)
EXPLAIN SELECT id_cliente, nome_razao, email
FROM cliente
WHERE nome_razao = 'Bruno Lima';

-- 3. extra: o extrato já usa o índice composto (id_conta_origem, dt_hora) do 01_schema.sql
-- esperado: key = idx_trans_origem, sem "Using filesort" (o índice já tá em ordem de data)
EXPLAIN SELECT id_transacao, dt_hora, valor
FROM transacao
WHERE id_conta_origem = 2
ORDER BY dt_hora;
