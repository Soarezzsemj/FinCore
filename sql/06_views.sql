-- Executar depois do 01 ao 05 (como root ou dba_fincore).
-- por que views: guardam no banco as consultas que a aplicação usa sempre (a API só faz SELECT * FROM vw_...,
-- sem repetir JOIN no C#) e a view roda com os privilégios de quem criou, então a API lê a view
-- sem ter acesso a todas as tabelas dela (ex.: cartao)
USE fincore;
-- acentos: o cliente envia o texto em UTF-8 (sem isso o mysql do container usa latin1 e estraga ã, é etc.)
SET NAMES utf8mb4;

-- 1. VIEWS

-- 1.1 vw_saldo_cliente: saldo total de cada cliente somando as contas em que ele é TITULAR
-- é a tela de posição dos clientes (GET /api/saldos); ignora a conta interna do banco (caixa)
CREATE OR REPLACE VIEW vw_saldo_cliente AS
SELECT cl.id_cliente,
       cl.nome_razao,
       cl.tipo,
       COUNT(c.id_conta) AS qtd_contas,
       SUM(c.saldo)      AS saldo_total
FROM cliente cl
INNER JOIN titularidade ti ON ti.id_cliente = cl.id_cliente AND ti.papel = 'TITULAR'
INNER JOIN conta c         ON c.id_conta = ti.id_conta
WHERE c.interna = 0
GROUP BY cl.id_cliente, cl.nome_razao, cl.tipo;

-- 1.2 vw_contas_cliente: cada conta com agência, titular, saldo, limite e saldo disponível
-- alimenta a lista de contas e a transferência (saldo disponível = saldo + cheque especial, o quanto ainda pode gastar)
CREATE OR REPLACE VIEW vw_contas_cliente AS
SELECT c.id_conta,
       ag.codigo                                    AS agencia,
       CONCAT(c.numero, '-', c.digito)              AS numero_conta,
       c.tipo,
       c.status,
       cl.id_cliente,
       cl.nome_razao                                AS titular,
       c.saldo,
       COALESCE(cc.limite_cheque_especial, 0)       AS limite_cheque_especial,
       c.saldo + COALESCE(cc.limite_cheque_especial, 0) AS saldo_disponivel
FROM conta c
INNER JOIN agencia ag      ON ag.id_agencia = c.id_agencia
INNER JOIN titularidade ti ON ti.id_conta = c.id_conta AND ti.papel = 'TITULAR'
INNER JOIN cliente cl      ON cl.id_cliente = ti.id_cliente
LEFT JOIN conta_corrente cc ON cc.id_conta = c.id_conta
WHERE c.interna = 0;

-- 1.3 vw_extrato_conta: extrato de todas as contas, uma linha por lançamento
-- cada transação aparece 2 vezes: débito (D, negativo) na origem e crédito (C, positivo) no destino,
-- a tela de extrato só filtra por conta
CREATE OR REPLACE VIEW vw_extrato_conta AS
SELECT t.id_conta_origem AS id_conta, t.id_transacao, t.dt_hora, t.tipo, t.descricao,
       cat.nome AS categoria, 'D' AS natureza, -t.valor AS valor
FROM transacao t
LEFT JOIN categoria cat ON cat.id_categoria = t.id_categoria
UNION ALL
SELECT t.id_conta_destino, t.id_transacao, t.dt_hora, t.tipo, t.descricao,
       cat.nome, 'C', t.valor
FROM transacao t
LEFT JOIN categoria cat ON cat.id_categoria = t.id_categoria;

-- 1.4 vw_fatura_cartao: cada fatura com o total das compras e o % do limite usado
-- o cliente vê a fatura sem a aplicação precisar somar compra por compra
CREATE OR REPLACE VIEW vw_fatura_cartao AS
SELECT f.id_fatura,
       ca.id_conta,
       ca.final_numero,
       ca.bandeira,
       f.competencia,
       f.dt_vencimento,
       f.status,
       COALESCE(SUM(co.valor), 0) AS valor_total,
       ca.limite_credito,
       ROUND(COALESCE(SUM(co.valor), 0) * 100 / ca.limite_credito, 2) AS percentual_limite
FROM fatura_cartao f
INNER JOIN cartao ca       ON ca.id_cartao = f.id_cartao
LEFT JOIN compra_cartao co ON co.id_fatura = f.id_fatura
GROUP BY f.id_fatura, ca.id_conta, ca.final_numero, ca.bandeira, f.competencia,
         f.dt_vencimento, f.status, ca.limite_credito;

-- 2. índices novos
-- o 01_schema.sql já tem os de extrato (origem/destino + data), categoria, cobrança de parcelas,
-- titularidade por cliente e compras por fatura (comentados lá), faltavam estes:

-- 2.1 busca de cliente pelo nome no atendimento (WHERE nome_razao = ? ou LIKE 'Ana%')
-- sem ele o MySQL lê a tabela cliente inteira (type: ALL), ver 06b_demo_indices.sql
CREATE INDEX idx_cliente_nome ON cliente (nome_razao);

-- 2.2 relatórios por período (transações do dia ou do mês)
-- os índices de extrato começam pela conta, então não servem pra filtrar só por data
CREATE INDEX idx_trans_data ON transacao (dt_hora);

-- 2.3 cobrança do cartão: faturas FECHADAS com vencimento passado
CREATE INDEX idx_fatura_cobranca ON fatura_cartao (status, dt_vencimento);

-- 3. acesso: a API (app_fincore) pode ler as views
GRANT SELECT ON fincore.vw_saldo_cliente  TO 'app_fincore'@'%';
GRANT SELECT ON fincore.vw_contas_cliente TO 'app_fincore'@'%';
GRANT SELECT ON fincore.vw_extrato_conta  TO 'app_fincore'@'%';
GRANT SELECT ON fincore.vw_fatura_cartao  TO 'app_fincore'@'%';

-- o analista (só leitura, sem acesso à autenticação) também usa as views nos relatórios
GRANT SELECT ON fincore.vw_saldo_cliente  TO 'analista_fincore'@'%';
GRANT SELECT ON fincore.vw_contas_cliente TO 'analista_fincore'@'%';
GRANT SELECT ON fincore.vw_extrato_conta  TO 'analista_fincore'@'%';
GRANT SELECT ON fincore.vw_fatura_cartao  TO 'analista_fincore'@'%';
