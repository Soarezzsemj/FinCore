-- FinCore: banco digital e gestão financeira (MySQL 8.0+)
-- Laboratório de Banco de Dados - GPE17N40158

DROP DATABASE IF EXISTS fincore;
CREATE DATABASE fincore CHARACTER SET utf8mb4;
USE fincore;

CREATE TABLE agencia (
    id_agencia INT AUTO_INCREMENT PRIMARY KEY,
    codigo     CHAR(4)     NOT NULL UNIQUE,
    nome       VARCHAR(80) NOT NULL,
    cidade     VARCHAR(60) NOT NULL,
    uf         CHAR(2)     NOT NULL
);

CREATE TABLE funcionario (
    id_func    INT AUTO_INCREMENT PRIMARY KEY,
    id_agencia INT         NOT NULL,
    nome       VARCHAR(100) NOT NULL,
    cargo      VARCHAR(20)  NOT NULL,
    CONSTRAINT ck_func_cargo CHECK (cargo IN ('GERENTE', 'ASSESSOR_INVEST', 'ATENDENTE')),
    CONSTRAINT fk_func_agencia FOREIGN KEY (id_agencia) REFERENCES agencia(id_agencia)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- supertipo de cliente (PF ou PJ); o endereço é um atributo composto (colunas end_*)
CREATE TABLE cliente (
    id_cliente  BIGINT AUTO_INCREMENT PRIMARY KEY,
    tipo        CHAR(2)      NOT NULL,
    nome_razao  VARCHAR(120) NOT NULL,
    documento   VARCHAR(14)  NOT NULL UNIQUE,
    email       VARCHAR(100) NOT NULL UNIQUE,
    status      VARCHAR(10)  NOT NULL DEFAULT 'ATIVO',
    dt_cadastro DATE         NOT NULL DEFAULT (CURRENT_DATE),
    end_rua     VARCHAR(100),
    end_numero  VARCHAR(10),
    end_bairro  VARCHAR(60),
    end_cidade  VARCHAR(60),
    end_uf      CHAR(2),
    end_cep     CHAR(8),
    CONSTRAINT ck_cliente_tipo   CHECK (tipo IN ('PF', 'PJ')),
    CONSTRAINT ck_cliente_status CHECK (status IN ('ATIVO', 'INATIVO', 'BLOQUEADO')),
    CONSTRAINT ck_cliente_doc CHECK (
        (tipo = 'PF' AND CHAR_LENGTH(documento) = 11) OR
        (tipo = 'PJ' AND CHAR_LENGTH(documento) = 14))
);

CREATE TABLE cliente_pf (
    id_cliente   BIGINT PRIMARY KEY,
    dt_nasc      DATE NOT NULL,
    renda_mensal DECIMAL(12,2),
    CONSTRAINT ck_pf_renda CHECK (renda_mensal >= 0),
    CONSTRAINT fk_pf_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE cliente_pj (
    id_cliente    BIGINT PRIMARY KEY,
    nome_fantasia VARCHAR(100),
    porte         VARCHAR(10) NOT NULL,
    dt_abertura   DATE NOT NULL,
    CONSTRAINT ck_pj_porte CHECK (porte IN ('MEI', 'ME', 'EPP', 'MEDIA', 'GRANDE')),
    CONSTRAINT fk_pj_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- atributo multivalorado
CREATE TABLE telefone_cliente (
    id_cliente BIGINT      NOT NULL,
    telefone   VARCHAR(15) NOT NULL,
    tipo       VARCHAR(12) NOT NULL DEFAULT 'CELULAR',
    PRIMARY KEY (id_cliente, telefone),
    CONSTRAINT ck_tel_tipo CHECK (tipo IN ('CELULAR', 'RESIDENCIAL', 'COMERCIAL')),
    CONSTRAINT fk_tel_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- supertipo de conta (corrente ou poupança); interna = conta contábil do banco (caixa)
CREATE TABLE conta (
    id_conta    BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_agencia  INT           NOT NULL,
    id_gerente  INT,
    numero      INT           NOT NULL,
    digito      CHAR(1)       NOT NULL,
    tipo        VARCHAR(10)   NOT NULL,
    interna     TINYINT       NOT NULL DEFAULT 0,
    saldo       DECIMAL(18,2) NOT NULL DEFAULT 0,
    status      VARCHAR(10)   NOT NULL DEFAULT 'ATIVA',
    dt_abertura DATE          NOT NULL DEFAULT (CURRENT_DATE),
    UNIQUE (id_agencia, numero),
    CONSTRAINT ck_conta_tipo    CHECK (tipo IN ('CORRENTE', 'POUPANCA')),
    CONSTRAINT ck_conta_interna CHECK (interna IN (0, 1)),
    CONSTRAINT ck_conta_status  CHECK (status IN ('ATIVA', 'BLOQUEADA', 'ENCERRADA')),
    CONSTRAINT fk_conta_agencia FOREIGN KEY (id_agencia) REFERENCES agencia(id_agencia)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_conta_gerente FOREIGN KEY (id_gerente) REFERENCES funcionario(id_func)
        ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE conta_corrente (
    id_conta               BIGINT PRIMARY KEY,
    limite_cheque_especial DECIMAL(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT ck_cc_limite CHECK (limite_cheque_especial >= 0),
    CONSTRAINT fk_cc_conta FOREIGN KEY (id_conta) REFERENCES conta(id_conta)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE conta_poupanca (
    id_conta        BIGINT  PRIMARY KEY,
    dia_aniversario TINYINT NOT NULL,
    CONSTRAINT ck_cp_dia CHECK (dia_aniversario BETWEEN 1 AND 28),
    CONSTRAINT fk_cp_conta FOREIGN KEY (id_conta) REFERENCES conta(id_conta)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- Cliente x Conta (M:N), com o papel do cliente na conta
CREATE TABLE titularidade (
    id_conta   BIGINT      NOT NULL,
    id_cliente BIGINT      NOT NULL,
    papel      VARCHAR(12) NOT NULL DEFAULT 'TITULAR',
    dt_inicio  DATE        NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (id_conta, id_cliente),
    CONSTRAINT ck_tit_papel CHECK (papel IN ('TITULAR', 'COTITULAR', 'PROCURADOR')),
    CONSTRAINT fk_tit_conta FOREIGN KEY (id_conta) REFERENCES conta(id_conta)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_tit_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE chave_pix (
    chave      VARCHAR(77) PRIMARY KEY,
    tipo       VARCHAR(10) NOT NULL,
    id_conta   BIGINT      NOT NULL,
    dt_criacao DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_pix_tipo CHECK (tipo IN ('CPF', 'CNPJ', 'EMAIL', 'TELEFONE', 'ALEATORIA')),
    CONSTRAINT fk_pix_conta FOREIGN KEY (id_conta) REFERENCES conta(id_conta)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- categoria pai/filha (relacionamento recursivo)
CREATE TABLE categoria (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    id_pai       INT,
    nome         VARCHAR(60) NOT NULL,
    tipo         VARCHAR(10) NOT NULL,
    UNIQUE (id_pai, nome),
    CONSTRAINT ck_cat_tipo CHECK (tipo IN ('RECEITA', 'DESPESA')),
    CONSTRAINT fk_cat_pai FOREIGN KEY (id_pai) REFERENCES categoria(id_categoria)
        ON UPDATE CASCADE ON DELETE SET NULL
);

-- Conta x Conta (recursivo, com atributos): cada transação tem uma conta de origem (débito)
-- e uma de destino (crédito) para o mesmo valor. O estorno aponta para a transação original.
CREATE TABLE transacao (
    id_transacao           BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_conta_origem        BIGINT        NOT NULL,
    id_conta_destino       BIGINT        NOT NULL,
    id_categoria           INT,
    id_transacao_estornada BIGINT,
    tipo                   VARCHAR(15)   NOT NULL,
    descricao              VARCHAR(200),
    valor                  DECIMAL(18,2) NOT NULL,
    dt_hora                DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    chave_idempotencia     VARCHAR(64)   NOT NULL UNIQUE,
    CONSTRAINT ck_trans_tipo  CHECK (tipo IN ('DEPOSITO', 'SAQUE', 'TRANSFERENCIA', 'PIX', 'PAGAMENTO', 'TARIFA', 'ESTORNO')),
    CONSTRAINT ck_trans_valor CHECK (valor > 0),
    CONSTRAINT ck_trans_contas CHECK (id_conta_origem <> id_conta_destino),
    CONSTRAINT fk_trans_origem  FOREIGN KEY (id_conta_origem)  REFERENCES conta(id_conta)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_trans_destino FOREIGN KEY (id_conta_destino) REFERENCES conta(id_conta)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_trans_cat FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_trans_estorno FOREIGN KEY (id_transacao_estornada) REFERENCES transacao(id_transacao)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE cartao (
    id_cartao      BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_conta       BIGINT        NOT NULL,
    final_numero   CHAR(4)       NOT NULL,
    bandeira       VARCHAR(10)   NOT NULL,
    limite_credito DECIMAL(12,2) NOT NULL,
    dia_vencimento TINYINT       NOT NULL,
    status         VARCHAR(10)   NOT NULL DEFAULT 'ATIVO',
    CONSTRAINT ck_cartao_bandeira CHECK (bandeira IN ('VISA', 'MASTERCARD', 'ELO')),
    CONSTRAINT ck_cartao_limite   CHECK (limite_credito >= 0),
    CONSTRAINT ck_cartao_dia      CHECK (dia_vencimento BETWEEN 1 AND 28),
    CONSTRAINT ck_cartao_status   CHECK (status IN ('ATIVO', 'BLOQUEADO', 'CANCELADO')),
    CONSTRAINT fk_cartao_conta FOREIGN KEY (id_conta) REFERENCES conta(id_conta)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE fatura_cartao (
    id_fatura     BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_cartao     BIGINT      NOT NULL,
    competencia   DATE        NOT NULL,
    dt_vencimento DATE        NOT NULL,
    status        VARCHAR(10) NOT NULL DEFAULT 'ABERTA',
    UNIQUE (id_cartao, competencia),
    CONSTRAINT ck_fatura_status CHECK (status IN ('ABERTA', 'FECHADA', 'PAGA', 'ATRASADA')),
    CONSTRAINT fk_fatura_cartao FOREIGN KEY (id_cartao) REFERENCES cartao(id_cartao)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE compra_cartao (
    id_compra       BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_fatura       BIGINT       NOT NULL,
    id_categoria    INT,
    estabelecimento VARCHAR(100) NOT NULL,
    valor           DECIMAL(12,2) NOT NULL,
    dt_compra       DATETIME     NOT NULL,
    CONSTRAINT ck_compra_valor CHECK (valor > 0),
    CONSTRAINT fk_compra_fatura FOREIGN KEY (id_fatura) REFERENCES fatura_cartao(id_fatura)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_compra_cat FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria)
        ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE emprestimo (
    id_emprestimo          BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_conta               BIGINT        NOT NULL,
    valor_principal        DECIMAL(14,2) NOT NULL,
    taxa_mensal            DECIMAL(7,4)  NOT NULL,
    qtd_parcelas           SMALLINT      NOT NULL,
    dt_contratacao         DATE          NOT NULL DEFAULT (CURRENT_DATE),
    dt_primeiro_vencimento DATE          NOT NULL,
    status                 VARCHAR(12)   NOT NULL DEFAULT 'ATIVO',
    CONSTRAINT ck_emp_valor  CHECK (valor_principal > 0),
    CONSTRAINT ck_emp_taxa   CHECK (taxa_mensal > 0),
    CONSTRAINT ck_emp_qtd    CHECK (qtd_parcelas BETWEEN 1 AND 120),
    CONSTRAINT ck_emp_status CHECK (status IN ('ATIVO', 'QUITADO', 'INADIMPLENTE')),
    CONSTRAINT fk_emp_conta FOREIGN KEY (id_conta) REFERENCES conta(id_conta)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- entidade fraca: a parcela só existe dentro de um empréstimo (PK composta)
CREATE TABLE parcela_emprestimo (
    id_emprestimo BIGINT        NOT NULL,
    nr_parcela    SMALLINT      NOT NULL,
    valor_parcela DECIMAL(12,2) NOT NULL,
    valor_multa   DECIMAL(12,2) NOT NULL DEFAULT 0,
    dt_vencimento DATE          NOT NULL,
    dt_pagamento  DATE,
    status        VARCHAR(10)   NOT NULL DEFAULT 'ABERTA',
    PRIMARY KEY (id_emprestimo, nr_parcela),
    CONSTRAINT ck_parc_valor  CHECK (valor_parcela > 0),
    CONSTRAINT ck_parc_status CHECK (status IN ('ABERTA', 'PAGA', 'ATRASADA')),
    CONSTRAINT fk_parc_emp FOREIGN KEY (id_emprestimo) REFERENCES emprestimo(id_emprestimo)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE produto_investimento (
    id_produto    INT AUTO_INCREMENT PRIMARY KEY,
    nome          VARCHAR(80)   NOT NULL UNIQUE,
    tipo          VARCHAR(10)   NOT NULL,
    risco         VARCHAR(5)    NOT NULL,
    rentab_anual  DECIMAL(6,3)  NOT NULL,
    liquidez_dias SMALLINT      NOT NULL DEFAULT 0,
    valor_minimo  DECIMAL(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT ck_prod_tipo  CHECK (tipo IN ('CDB', 'LCI', 'TESOURO', 'ACOES', 'FUNDO')),
    CONSTRAINT ck_prod_risco CHECK (risco IN ('BAIXO', 'MEDIO', 'ALTO'))
);

-- ternário: conta, produto de investimento e assessor
CREATE TABLE aplicacao (
    id_aplicacao   BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_conta       BIGINT        NOT NULL,
    id_produto     INT           NOT NULL,
    id_assessor    INT           NOT NULL,
    valor_aplicado DECIMAL(14,2) NOT NULL,
    dt_aplicacao   DATE          NOT NULL DEFAULT (CURRENT_DATE),
    dt_resgate     DATE,
    status         VARCHAR(10)   NOT NULL DEFAULT 'ATIVA',
    CONSTRAINT ck_apl_valor  CHECK (valor_aplicado > 0),
    CONSTRAINT ck_apl_status CHECK (status IN ('ATIVA', 'RESGATADA')),
    CONSTRAINT fk_apl_conta FOREIGN KEY (id_conta) REFERENCES conta(id_conta)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_apl_produto FOREIGN KEY (id_produto) REFERENCES produto_investimento(id_produto)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_apl_assessor FOREIGN KEY (id_assessor) REFERENCES funcionario(id_func)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ternário: cliente, categoria e mês
CREATE TABLE orcamento (
    id_cliente   BIGINT        NOT NULL,
    id_categoria INT           NOT NULL,
    competencia  DATE          NOT NULL,
    valor_limite DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (id_cliente, id_categoria, competencia),
    CONSTRAINT ck_orc_valor CHECK (valor_limite > 0),
    CONSTRAINT fk_orc_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_orc_cat FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- índices para extrato, cobrança e relatórios
CREATE INDEX idx_trans_origem  ON transacao (id_conta_origem, dt_hora);
CREATE INDEX idx_trans_destino ON transacao (id_conta_destino, dt_hora);
CREATE INDEX idx_trans_cat     ON transacao (id_categoria, dt_hora);
CREATE INDEX idx_parc_cobranca ON parcela_emprestimo (status, dt_vencimento);
CREATE INDEX idx_titular_cli   ON titularidade (id_cliente);
CREATE INDEX idx_compra_fatura ON compra_cartao (id_fatura);