-- Executar depois do 01_schema.sql.
USE fincore;

INSERT INTO agencia (codigo, nome, cidade, uf) VALUES
('0001', 'Agência Digital Brasília', 'Brasília', 'DF'),
('0002', 'Agência São Paulo Paulista', 'São Paulo', 'SP');

INSERT INTO funcionario (id_agencia, nome, cargo) VALUES
(1, 'Marina Duarte', 'GERENTE'),
(1, 'Ricardo Faria', 'ASSESSOR_INVEST'),
(2, 'Júlia Campos', 'GERENTE'),
(1, 'Otávio Reis', 'ATENDENTE');

INSERT INTO cliente (id_cliente, tipo, nome_razao, documento, email, end_rua, end_numero, end_bairro, end_cidade, end_uf, end_cep) VALUES
(1, 'PJ', 'FinCore Banco Digital S.A.', '00000000000191', 'contato@fincore.com', 'SBS Quadra 2', '1', 'Asa Sul', 'Brasília', 'DF', '70070000'),
(2, 'PF', 'Ana Souza', '11111111111', 'ana@email.com', 'Rua das Flores', '120', 'Asa Norte', 'Brasília', 'DF', '70700000'),
(3, 'PF', 'Bruno Lima', '22222222222', 'bruno@email.com', 'Av. Central', '45', 'Taguatinga', 'Brasília', 'DF', '72010000'),
(4, 'PF', 'Carla Mendes', '33333333333', 'carla@email.com', 'Quadra 5', '10', 'Guará', 'Brasília', 'DF', '71010000'),
(5, 'PJ', 'Padaria Pão Quente ME', '12345678000195', 'padaria@email.com', 'CLN 208', '15', 'Asa Norte', 'Brasília', 'DF', '70853000');

INSERT INTO cliente_pf (id_cliente, dt_nasc, renda_mensal) VALUES
(2, '1990-04-12', 7500.00),
(3, '1988-09-30', 5200.00),
(4, '1995-01-22', 4100.00);

INSERT INTO cliente_pj (id_cliente, nome_fantasia, porte, dt_abertura) VALUES
(1, 'FinCore', 'GRANDE', '2020-01-01'),
(5, 'Pão Quente', 'ME', '2015-06-01');

INSERT INTO telefone_cliente (id_cliente, telefone, tipo) VALUES
(2, '61999990001', 'CELULAR'),
(2, '6133330001', 'RESIDENCIAL'),
(3, '61999990002', 'CELULAR'),
(4, '61999990003', 'CELULAR'),
(5, '6134440005', 'COMERCIAL');

-- a conta 1 é a conta interna do banco (caixa)
INSERT INTO conta (id_conta, id_agencia, id_gerente, numero, digito, tipo, interna) VALUES
(1, 1, NULL, 1, '0', 'CORRENTE', 1),
(2, 1, 1, 10001, '1', 'CORRENTE', 0),
(3, 1, 1, 10002, '2', 'POUPANCA', 0),
(4, 1, 1, 10003, '3', 'CORRENTE', 0),
(5, 1, 1, 10004, '4', 'CORRENTE', 0),
(6, 1, 1, 10005, '5', 'CORRENTE', 0);

INSERT INTO conta_corrente (id_conta, limite_cheque_especial) VALUES
(1, 0), (2, 1000), (4, 500), (5, 0), (6, 2000);

INSERT INTO conta_poupanca (id_conta, dia_aniversario) VALUES (3, 10);

-- Bruno é cotitular da conta corrente da Ana
INSERT INTO titularidade (id_conta, id_cliente, papel) VALUES
(1, 1, 'TITULAR'),
(2, 2, 'TITULAR'),
(3, 2, 'TITULAR'),
(4, 3, 'TITULAR'),
(5, 4, 'TITULAR'),
(6, 5, 'TITULAR'),
(2, 3, 'COTITULAR');

INSERT INTO chave_pix (chave, tipo, id_conta) VALUES
('11111111111', 'CPF', 2),
('bruno@email.com', 'EMAIL', 4),
('12345678000195', 'CNPJ', 6);

INSERT INTO categoria (id_categoria, id_pai, nome, tipo) VALUES
(1, NULL, 'Salário', 'RECEITA'),
(2, NULL, 'Alimentação', 'DESPESA'),
(3, NULL, 'Moradia', 'DESPESA'),
(4, NULL, 'Transporte', 'DESPESA'),
(5, NULL, 'Lazer', 'DESPESA'),
(6, NULL, 'Investimentos', 'DESPESA'),
(7, 2, 'Supermercado', 'DESPESA'),
(8, 2, 'Restaurante/Padaria', 'DESPESA'),
(9, NULL, 'Financiamentos', 'DESPESA');

-- origem = conta debitada, destino = conta creditada
INSERT INTO transacao (id_conta_origem, id_conta_destino, id_categoria, tipo, descricao, valor, chave_idempotencia) VALUES
(1, 2, 1, 'DEPOSITO',      'Salário Ana',               5000.00,  'dep-ana-001'),
(1, 4, 1, 'DEPOSITO',      'Salário Bruno',             3000.00,  'dep-bru-001'),
(1, 5, 1, 'DEPOSITO',      'Depósito Carla',            800.00,   'dep-car-001'),
(1, 6, 1, 'DEPOSITO',      'Vendas do dia',             2500.00,  'dep-pad-001'),
(2, 6, 8, 'PAGAMENTO',     'Café da manhã',             45.90,    'pag-ana-001'),
(2, 4, NULL, 'PIX',        'Racha da conta',            300.00,   'pix-ana-001'),
(2, 3, NULL, 'TRANSFERENCIA', 'Reserva poupança',       1000.00,  'trf-ana-001'),
(4, 5, 3, 'PAGAMENTO',     'Aluguel',                   1200.00,  'pag-bru-001'),
(5, 6, 7, 'PAGAMENTO',     'Compras do mês',            120.00,   'pag-car-001'),
(6, 1, NULL, 'SAQUE',      'Saque no caixa',            500.00,   'saq-pad-001'),
(1, 4, 9, 'DEPOSITO',      'Crédito do empréstimo 1',   10000.00, 'emp-bru-001'),
(2, 1, 6, 'PAGAMENTO',     'Aplicação em CDB',          2000.00,  'apl-ana-001'),
(6, 1, 6, 'PAGAMENTO',     'Aplicação em fundo',        1000.00,  'apl-pad-001');

-- saldo de cada conta = créditos recebidos - débitos realizados
UPDATE conta
SET saldo = (SELECT COALESCE(SUM(valor), 0) FROM transacao WHERE id_conta_destino = conta.id_conta)
          - (SELECT COALESCE(SUM(valor), 0) FROM transacao WHERE id_conta_origem = conta.id_conta)
WHERE id_conta > 0;

INSERT INTO cartao (id_conta, final_numero, bandeira, limite_credito, dia_vencimento) VALUES
(2, '4321', 'VISA', 6000.00, 10),
(4, '8765', 'MASTERCARD', 3500.00, 15);

INSERT INTO fatura_cartao (id_cartao, competencia, dt_vencimento) VALUES
(1, DATE_FORMAT(CURDATE(), '%Y-%m-01'), DATE_ADD(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 9 DAY)),
(2, DATE_FORMAT(CURDATE(), '%Y-%m-01'), DATE_ADD(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 14 DAY));

INSERT INTO compra_cartao (id_fatura, id_categoria, estabelecimento, valor, dt_compra) VALUES
(1, 7, 'Supermercado Bom Preço', 389.40, NOW()),
(1, 5, 'Cinemax', 64.00, NOW()),
(1, 4, 'Posto Shell', 210.00, NOW()),
(2, 8, 'Restaurante Sabor', 132.50, NOW());

-- empréstimo do Bruno: 12 parcelas de 934,02 (Tabela Price, 1,8% a.m.), 1ª vencida há 40 dias
INSERT INTO emprestimo (id_conta, valor_principal, taxa_mensal, qtd_parcelas, dt_contratacao, dt_primeiro_vencimento) VALUES
(4, 10000.00, 1.8000, 12, DATE_SUB(CURDATE(), INTERVAL 70 DAY), DATE_SUB(CURDATE(), INTERVAL 40 DAY));

INSERT INTO parcela_emprestimo (id_emprestimo, nr_parcela, valor_parcela, dt_vencimento) VALUES
(1, 1, 934.02, DATE_SUB(CURDATE(), INTERVAL 40 DAY)),
(1, 2, 934.02, DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 40 DAY), INTERVAL 1 MONTH)),
(1, 3, 934.02, DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 40 DAY), INTERVAL 2 MONTH)),
(1, 4, 934.02, DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 40 DAY), INTERVAL 3 MONTH)),
(1, 5, 934.02, DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 40 DAY), INTERVAL 4 MONTH)),
(1, 6, 934.02, DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 40 DAY), INTERVAL 5 MONTH)),
(1, 7, 934.02, DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 40 DAY), INTERVAL 6 MONTH)),
(1, 8, 934.02, DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 40 DAY), INTERVAL 7 MONTH)),
(1, 9, 934.02, DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 40 DAY), INTERVAL 8 MONTH)),
(1, 10, 934.02, DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 40 DAY), INTERVAL 9 MONTH)),
(1, 11, 934.02, DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 40 DAY), INTERVAL 10 MONTH)),
(1, 12, 934.02, DATE_ADD(DATE_SUB(CURDATE(), INTERVAL 40 DAY), INTERVAL 11 MONTH));

INSERT INTO produto_investimento (nome, tipo, risco, rentab_anual, liquidez_dias, valor_minimo) VALUES
('CDB Liquidez Diária 100% CDI', 'CDB', 'BAIXO', 10.500, 0, 100.00),
('Tesouro Selic 2029', 'TESOURO', 'BAIXO', 10.750, 1, 30.00),
('Fundo Multimercado Alpha', 'FUNDO', 'MEDIO', 13.200, 30, 1000.00),
('Carteira de Ações Dividendos', 'ACOES', 'ALTO', 16.000, 2, 500.00);

INSERT INTO aplicacao (id_conta, id_produto, id_assessor, valor_aplicado) VALUES
(2, 1, 2, 2000.00),
(6, 3, 2, 1000.00);

INSERT INTO orcamento (id_cliente, id_categoria, competencia, valor_limite) VALUES
(2, 2, DATE_FORMAT(CURDATE(), '%Y-%m-01'), 800.00),
(2, 5, DATE_FORMAT(CURDATE(), '%Y-%m-01'), 300.00),
(3, 3, DATE_FORMAT(CURDATE(), '%Y-%m-01'), 1500.00);