-- Executar depois do 01 e do 02.
USE fincore;

-- 4. SELECTs

-- 4.1 Extrato da conta da Ana: débitos e créditos
SELECT t.id_transacao, t.dt_hora, 'D' AS natureza, t.tipo, t.descricao, t.valor
FROM transacao t
WHERE t.id_conta_origem = 2
UNION
SELECT t.id_transacao, t.dt_hora, 'C', t.tipo, t.descricao, t.valor
FROM transacao t
WHERE t.id_conta_destino = 2
ORDER BY dt_hora, id_transacao;

-- 4.2 Saldo consolidado por cliente
SELECT cl.nome_razao, COUNT(c.id_conta) AS qtd_contas, SUM(c.saldo) AS saldo_total
FROM cliente cl
INNER JOIN titularidade ti ON ti.id_cliente = cl.id_cliente AND ti.papel = 'TITULAR'
INNER JOIN conta c ON c.id_conta = ti.id_conta
WHERE c.interna = 0
GROUP BY cl.id_cliente, cl.nome_razao
ORDER BY saldo_total DESC;

-- 4.3 Contas com saldo diferente de créditos - débitos (deve retornar 0 linhas)
SELECT c.id_conta, c.saldo,
       (SELECT COALESCE(SUM(valor), 0) FROM transacao WHERE id_conta_destino = c.id_conta)
     - (SELECT COALESCE(SUM(valor), 0) FROM transacao WHERE id_conta_origem = c.id_conta) AS saldo_calculado
FROM conta c
WHERE c.saldo <> (SELECT COALESCE(SUM(valor), 0) FROM transacao WHERE id_conta_destino = c.id_conta)
               - (SELECT COALESCE(SUM(valor), 0) FROM transacao WHERE id_conta_origem = c.id_conta);

-- 4.4 Contas de clientes abaixo do limite do cheque especial (deve retornar 0 linhas)
SELECT c.id_conta, c.saldo, cc.limite_cheque_especial
FROM conta c
LEFT JOIN conta_corrente cc ON cc.id_conta = c.id_conta
WHERE c.interna = 0 AND c.saldo < -COALESCE(cc.limite_cheque_especial, 0);

-- 4.5 Despesas dos clientes por categoria (subcategorias somam na categoria pai)
SELECT COALESCE(p.nome, c.nome) AS categoria, COUNT(*) AS qtd, SUM(t.valor) AS total
FROM transacao t
INNER JOIN categoria c ON c.id_categoria = t.id_categoria
LEFT JOIN categoria p ON p.id_categoria = c.id_pai
INNER JOIN conta o ON o.id_conta = t.id_conta_origem
WHERE c.tipo = 'DESPESA' AND o.interna = 0
GROUP BY COALESCE(p.nome, c.nome)
ORDER BY total DESC;

-- 4.6 Orçamento x realizado do mês
SELECT cl.nome_razao, c.nome AS categoria, o.valor_limite,
       COALESCE(SUM(t.valor), 0) AS realizado,
       o.valor_limite - COALESCE(SUM(t.valor), 0) AS saldo_orcamento
FROM orcamento o
INNER JOIN cliente cl ON cl.id_cliente = o.id_cliente
INNER JOIN categoria c ON c.id_categoria = o.id_categoria
LEFT JOIN categoria sub ON sub.id_categoria = c.id_categoria OR sub.id_pai = c.id_categoria
LEFT JOIN titularidade ti ON ti.id_cliente = o.id_cliente AND ti.papel = 'TITULAR'
LEFT JOIN transacao t ON t.id_categoria = sub.id_categoria
     AND t.id_conta_origem = ti.id_conta
     AND t.dt_hora >= o.competencia
     AND t.dt_hora < DATE_ADD(o.competencia, INTERVAL 1 MONTH)
GROUP BY o.id_cliente, o.id_categoria, o.competencia, cl.nome_razao, c.nome, o.valor_limite;

-- 4.7 Total da fatura e % do limite do cartão
SELECT ca.final_numero, ca.bandeira, f.competencia, SUM(cc.valor) AS total_fatura,
       ROUND(SUM(cc.valor) / ca.limite_credito * 100, 2) AS pct_limite
FROM fatura_cartao f
INNER JOIN cartao ca ON ca.id_cartao = f.id_cartao
INNER JOIN compra_cartao cc ON cc.id_fatura = f.id_fatura
GROUP BY f.id_fatura, ca.final_numero, ca.bandeira, f.competencia, ca.limite_credito;

-- 4.8 Parcelas vencidas e não pagas
SELECT e.id_emprestimo, cl.nome_razao, p.nr_parcela, p.valor_parcela, p.dt_vencimento,
       DATEDIFF(CURDATE(), p.dt_vencimento) AS dias_atraso
FROM parcela_emprestimo p
INNER JOIN emprestimo e ON e.id_emprestimo = p.id_emprestimo
INNER JOIN titularidade ti ON ti.id_conta = e.id_conta AND ti.papel = 'TITULAR'
INNER JOIN cliente cl ON cl.id_cliente = ti.id_cliente
WHERE p.status = 'ABERTA' AND p.dt_vencimento < CURDATE()
ORDER BY dias_atraso DESC;

-- 4.9 Investimentos por nível de risco
SELECT pi.risco, COUNT(*) AS aplicacoes, SUM(a.valor_aplicado) AS total
FROM aplicacao a
INNER JOIN produto_investimento pi ON pi.id_produto = a.id_produto
WHERE a.status = 'ATIVA'
GROUP BY pi.risco;

-- 4.10 Clientes PF com renda e quantidade de contas
SELECT c.nome_razao, pf.renda_mensal, COUNT(t.id_conta) AS contas
FROM cliente c
INNER JOIN cliente_pf pf ON pf.id_cliente = c.id_cliente
LEFT JOIN titularidade t ON t.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nome_razao, pf.renda_mensal;

-- 5. UPDATEs

-- 5.1 Marca as parcelas vencidas como atrasadas e aplica multa de 2%
UPDATE parcela_emprestimo
SET status = 'ATRASADA', valor_multa = ROUND(valor_parcela * 0.02, 2)
WHERE status = 'ABERTA' AND dt_vencimento < CURDATE();

-- 5.2 Empréstimos com parcela atrasada ficam inadimplentes
UPDATE emprestimo
SET status = 'INADIMPLENTE'
WHERE id_emprestimo > 0
  AND id_emprestimo IN (SELECT id_emprestimo FROM parcela_emprestimo WHERE status = 'ATRASADA');

-- 5.3 Pagamento da parcela 1 do empréstimo 1 (transação + baixa da parcela)
INSERT INTO transacao (id_conta_origem, id_conta_destino, id_categoria, tipo, descricao, valor, chave_idempotencia)
SELECT 4, 1, 9, 'PAGAMENTO', 'Parcela 1 do empréstimo 1', valor_parcela + valor_multa, 'parc-emp1-001'
FROM parcela_emprestimo
WHERE id_emprestimo = 1 AND nr_parcela = 1;

UPDATE parcela_emprestimo
SET status = 'PAGA', dt_pagamento = CURDATE()
WHERE id_emprestimo = 1 AND nr_parcela = 1;

-- 5.4 Estorno do café da manhã da Ana (transação inversa apontando para a original)
INSERT INTO transacao (id_conta_origem, id_conta_destino, id_transacao_estornada, tipo, descricao, valor, chave_idempotencia)
SELECT id_conta_destino, id_conta_origem, id_transacao, 'ESTORNO', 'Estorno do café da manhã', valor, 'est-pag-ana-001'
FROM transacao
WHERE chave_idempotencia = 'pag-ana-001';

-- 5.5 Recalcula os saldos a partir das transações
UPDATE conta
SET saldo = (SELECT COALESCE(SUM(valor), 0) FROM transacao WHERE id_conta_destino = conta.id_conta)
          - (SELECT COALESCE(SUM(valor), 0) FROM transacao WHERE id_conta_origem = conta.id_conta)
WHERE id_conta > 0;

-- 5.6 Bloqueio da conta da Carla
UPDATE conta SET status = 'BLOQUEADA' WHERE id_conta = 5;

-- 5.7 Novo limite do cheque especial da Ana
UPDATE conta_corrente SET limite_cheque_especial = 1500.00 WHERE id_conta = 2;

-- 5.8 Fecha as faturas abertas
UPDATE fatura_cartao SET status = 'FECHADA' WHERE id_fatura > 0 AND status = 'ABERTA';

-- 5.9 Reajuste de 0,5 ponto na rentabilidade dos títulos do Tesouro
UPDATE produto_investimento SET rentab_anual = rentab_anual + 0.5 WHERE id_produto > 0 AND tipo = 'TESOURO';

-- 5.10 Devem falhar; descomente para testar
-- INSERT INTO transacao (id_conta_origem, id_conta_destino, tipo, valor, chave_idempotencia) VALUES (2, 4, 'PIX', 10, 'pix-ana-001');   -- chave repetida (UNIQUE)
-- INSERT INTO transacao (id_conta_origem, id_conta_destino, tipo, valor, chave_idempotencia) VALUES (2, 4, 'PIX', -10, 'teste-neg');    -- valor negativo (CHECK)
-- INSERT INTO transacao (id_conta_origem, id_conta_destino, tipo, valor, chave_idempotencia) VALUES (2, 2, 'PIX', 10, 'teste-mesma');  -- origem = destino (CHECK)
-- INSERT INTO cliente (tipo, nome_razao, documento, email) VALUES ('PF', 'Teste', '123', 'teste@email.com');                             -- CPF inválido (CHECK)

-- 6. Revisão do conteúdo da disciplina
-- Cada consulta traz a expressão de álgebra relacional equivalente em comentário.

-- 6.1 DDL (tabela auxiliar, não afeta o modelo)
CREATE TABLE demo_meta (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(50) NOT NULL
);
INSERT INTO demo_meta (descricao) VALUES ('primeiro'), ('segundo');

ALTER TABLE demo_meta ADD observacao VARCHAR(100);
ALTER TABLE demo_meta MODIFY COLUMN observacao VARCHAR(200);
ALTER TABLE demo_meta DROP COLUMN observacao;
RENAME TABLE demo_meta TO demo_metadados;
TRUNCATE TABLE demo_metadados;
DROP TABLE demo_metadados;

-- 6.2 Seleção e projeção

-- σ tipo='PJ' ∧ status='ATIVO' (cliente)
SELECT * FROM cliente WHERE tipo = 'PJ' AND status = 'ATIVO';

-- σ status='BLOQUEADA' ∨ status='ENCERRADA' (conta)
SELECT id_conta, numero, tipo, status FROM conta
WHERE status = 'BLOQUEADA' OR status = 'ENCERRADA';

-- σ ¬interna (conta)
SELECT id_conta, numero, saldo FROM conta WHERE NOT interna;

-- π tipo (transacao), sem duplicatas
SELECT DISTINCT tipo FROM transacao;

-- IS NULL: contas sem gerente
SELECT id_conta, numero FROM conta WHERE id_gerente IS NULL;

-- IS NOT NULL: parcelas que já foram pagas
SELECT id_emprestimo, nr_parcela, dt_pagamento
FROM parcela_emprestimo WHERE dt_pagamento IS NOT NULL;

-- LIKE: nome começa com 'A' ou contém 'Lima'
SELECT nome_razao, email FROM cliente
WHERE nome_razao LIKE 'A%' OR nome_razao LIKE '%Lima%';

-- IN: transações do tipo PIX ou TRANSFERENCIA
SELECT id_transacao, tipo, valor FROM transacao
WHERE tipo IN ('PIX', 'TRANSFERENCIA');

-- BETWEEN: transações com valor entre 100 e 1500
SELECT id_transacao, tipo, valor FROM transacao
WHERE valor BETWEEN 100 AND 1500
ORDER BY valor;

-- ORDER BY + LIMIT: as 3 maiores transações
SELECT id_transacao, tipo, valor, descricao FROM transacao
ORDER BY valor DESC
LIMIT 3;

-- 6.3 Agregação

-- γ MIN, MAX, AVG, COUNT, SUM (transacao)
SELECT MIN(valor) AS menor, MAX(valor) AS maior, ROUND(AVG(valor), 2) AS media,
       COUNT(*) AS qtd, SUM(valor) AS total
FROM transacao
WHERE tipo IN ('PIX', 'PAGAMENTO', 'TRANSFERENCIA');

-- σ qtd>=2 (tipo γ COUNT(*)→qtd, SUM(valor)→total (transacao)), com GROUP BY e HAVING
SELECT tipo, COUNT(*) AS qtd, SUM(valor) AS total
FROM transacao
GROUP BY tipo
HAVING COUNT(*) >= 2
ORDER BY total DESC;

-- 6.4 União, interseção e diferença

-- π cidade (agencia) ∪ π end_cidade (cliente)
SELECT cidade FROM agencia
UNION
SELECT end_cidade FROM cliente;

-- ∩ clientes com cartão e com empréstimo
-- π id_cliente (titular⋈cartao) ∩ π id_cliente (titular⋈emprestimo)
SELECT DISTINCT cl.id_cliente, cl.nome_razao
FROM cliente cl
INNER JOIN titularidade ti ON ti.id_cliente = cl.id_cliente
INNER JOIN cartao ca ON ca.id_conta = ti.id_conta
WHERE cl.id_cliente IN (SELECT ti2.id_cliente
                        FROM titularidade ti2
                        INNER JOIN emprestimo e ON e.id_conta = ti2.id_conta);

-- − clientes com cartão e sem empréstimo
-- π id_cliente (titular⋈cartao) − π id_cliente (titular⋈emprestimo)
SELECT DISTINCT cl.id_cliente, cl.nome_razao
FROM cliente cl
INNER JOIN titularidade ti ON ti.id_cliente = cl.id_cliente
INNER JOIN cartao ca ON ca.id_conta = ti.id_conta
WHERE cl.id_cliente NOT IN (SELECT ti2.id_cliente
                            FROM titularidade ti2
                            INNER JOIN emprestimo e ON e.id_conta = ti2.id_conta);

-- 6.5 Produto cartesiano e junções

-- × agencia × produto_investimento (CROSS JOIN)
SELECT a.nome AS agencia, p.nome AS produto
FROM agencia a
CROSS JOIN produto_investimento p
ORDER BY a.nome, p.nome;

-- ρ + ⋈ (auto-junção): subcategoria e sua categoria pai
-- π f.nome, p.nome (ρf(categoria) ⋈ f.id_pai = p.id_categoria ρp(categoria))
SELECT f.nome AS subcategoria, p.nome AS categoria_pai
FROM categoria f
INNER JOIN categoria p ON f.id_pai = p.id_categoria;

-- ⋈= junção à direita: funcionários e as contas que gerenciam
SELECT f.nome AS funcionario, f.cargo, c.id_conta
FROM conta c
RIGHT JOIN funcionario f ON f.id_func = c.id_gerente
ORDER BY f.nome;

-- =⋈ junção à esquerda: contas sem cartão
SELECT c.id_conta, c.numero, c.tipo
FROM conta c
LEFT JOIN cartao ca ON ca.id_conta = c.id_conta
WHERE ca.id_cartao IS NULL AND c.interna = 0;

-- =⋈= junção externa completa (LEFT JOIN ∪ RIGHT JOIN, pois o MySQL não tem FULL JOIN)
SELECT f.nome AS funcionario, c.id_conta
FROM funcionario f LEFT JOIN conta c ON c.id_gerente = f.id_func
UNION
SELECT f.nome AS funcionario, c.id_conta
FROM funcionario f RIGHT JOIN conta c ON c.id_gerente = f.id_func;

-- 6.6 Divisão: clientes titulares de todos os tipos de conta
-- π id_cliente,tipo (titularidade ⋈ conta) ÷ π tipo (conta)
SELECT cl.id_cliente, cl.nome_razao
FROM cliente cl
INNER JOIN titularidade ti ON ti.id_cliente = cl.id_cliente AND ti.papel = 'TITULAR'
INNER JOIN conta c ON c.id_conta = ti.id_conta AND c.interna = 0
GROUP BY cl.id_cliente, cl.nome_razao
HAVING COUNT(DISTINCT c.tipo) = (SELECT COUNT(DISTINCT tipo) FROM conta WHERE interna = 0);

-- 6.7 DELETE e ações referenciais

-- DELETE: remove o orçamento de moradia do Bruno
DELETE FROM orcamento WHERE id_cliente = 3 AND id_categoria = 3;

-- ON UPDATE CASCADE: muda a PK de 'Lazer' e propaga para as tabelas filhas
UPDATE categoria SET id_categoria = 50 WHERE id_categoria = 5;
SELECT id_cliente, id_categoria, valor_limite FROM orcamento WHERE id_categoria = 50;
UPDATE categoria SET id_categoria = 5 WHERE id_categoria = 50;

-- ON DELETE SET NULL (comentado para não alterar os dados)
-- DELETE FROM categoria WHERE id_categoria = 9;

-- ON DELETE RESTRICT: devem falhar; descomente para testar
-- DELETE FROM cliente WHERE id_cliente = 2;
-- DELETE FROM conta WHERE id_conta = 2;