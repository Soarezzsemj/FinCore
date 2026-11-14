-- Executar depois do 01 e do 02, como root.
-- as senhas dos usuarios do MySQL nao ficam no Git: no lugar delas tem as marcas __SENHA_APP__,
-- __SENHA_ANALISTA__ e __SENHA_DBA__ (no Docker o 04_usuarios_acesso.sh troca pelas do .env;
-- rodando à mão no Workbench, troca as tres marcas antes de executar)
USE fincore;
-- acentos: o cliente envia o texto em UTF-8 (sem isso o mysql do container usa latin1 e estraga ã, é etc.)
SET NAMES utf8mb4;

-- 1. tabelas de login da aplicação

-- 1.1 grupos_usuarios: perfil de quem entra no sistema (ADMIN cuida de tudo, GERENTE e ATENDENTE
-- atendem os clientes, CLIENTE só vê as próprias contas). define o que cada um pode fazer na aplicação
CREATE TABLE grupos_usuarios (
    id_grupo  INT AUTO_INCREMENT PRIMARY KEY,
    nome      VARCHAR(20)  NOT NULL UNIQUE,
    descricao VARCHAR(150) NOT NULL
);

-- 1.2 usuarios: quem faz login. login único, senha guardada só como hash, grupo obrigatório e,
-- se for cliente do banco, o vínculo com a tabela cliente
-- hash = SHA2(CONCAT(salt, senha), 256); o salt é aleatório por usuário, então senhas iguais geram hashes diferentes
CREATE TABLE usuarios (
    id_usuario  INT          PRIMARY KEY,   -- ID gerado por fn_gerar_id (05_funcoes_id.sql)
    login       VARCHAR(40)  NOT NULL UNIQUE,
    senha_hash  CHAR(64)     NOT NULL,
    salt        CHAR(32)     NOT NULL,
    id_grupo    INT          NOT NULL,
    id_cliente  BIGINT       NULL,          -- opcional: só para usuários do grupo CLIENTE
    status      VARCHAR(10)  NOT NULL DEFAULT 'ATIVO',
    dt_criacao  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_usuarios_status CHECK (status IN ('ATIVO', 'BLOQUEADO', 'INATIVO')),
    CONSTRAINT fk_usuarios_grupo FOREIGN KEY (id_grupo) REFERENCES grupos_usuarios(id_grupo)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_usuarios_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

INSERT INTO grupos_usuarios (id_grupo, nome, descricao) VALUES
(1, 'ADMIN',     'Administra o sistema e os usuários'),
(2, 'GERENTE',   'Gerente de agência: consulta e movimenta contas dos clientes'),
(3, 'ATENDENTE', 'Atendimento: consulta clientes e contas'),
(4, 'CLIENTE',   'Cliente do banco: vê apenas as próprias contas');

-- 1.3 usuarios de demonstracao (dados ficticios), todos com a senha de teste 'fincore123'
INSERT INTO usuarios (id_usuario, login, salt, senha_hash, id_grupo, id_cliente) VALUES
(1, 'admin',     'a3f1c9e2b7d4085f6e1a2c3b4d5e6f70', SHA2(CONCAT('a3f1c9e2b7d4085f6e1a2c3b4d5e6f70', 'fincore123'), 256), 1, NULL),
(2, 'gerente',   '5b8e2d1f0c9a7e6d4b3a2f1e0d9c8b7a', SHA2(CONCAT('5b8e2d1f0c9a7e6d4b3a2f1e0d9c8b7a', 'fincore123'), 256), 2, NULL),
(3, 'atendente', 'c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9', SHA2(CONCAT('c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9', 'fincore123'), 256), 3, NULL),
(4, 'ana',       '9e8d7c6b5a4f3e2d1c0b9a8f7e6d5c4b', SHA2(CONCAT('9e8d7c6b5a4f3e2d1c0b9a8f7e6d5c4b', 'fincore123'), 256), 4, 2),
(5, 'bruno',     '1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d', SHA2(CONCAT('1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d', 'fincore123'), 256), 4, 3);

-- 2. usuarios do MySQL (menor privilégio)
-- cada um recebe só o que precisa, se a senha de um vazar o estrago fica limitado
-- '%' = conecta de qualquer endereço (a API roda fora do container); o DROP deixa rodar de novo sem erro

DROP USER IF EXISTS 'app_fincore'@'%';
DROP USER IF EXISTS 'analista_fincore'@'%';
DROP USER IF EXISTS 'dba_fincore'@'%';

-- 2.1 app_fincore: usuário que a API usa (a aplicação nunca usa o root)
-- permissão tabela por tabela, só nas que as telas usam: sem DELETE (o histórico não se apaga, RN07),
-- sem DDL e sem acesso a funcionario, cartões, empréstimos e investimentos
-- (o 06 dá SELECT nas views e o 07 tira o INSERT/UPDATE direto em transacao e conta)
CREATE USER 'app_fincore'@'%' IDENTIFIED BY '__SENHA_APP__';

-- login: ler grupos; criar usuário, trocar senha e bloquear (sem apagar)
GRANT SELECT                 ON fincore.grupos_usuarios TO 'app_fincore'@'%';
GRANT SELECT, INSERT, UPDATE ON fincore.usuarios        TO 'app_fincore'@'%';
-- clientes: consultar, cadastrar e atualizar dados
GRANT SELECT, INSERT, UPDATE ON fincore.cliente         TO 'app_fincore'@'%';
GRANT SELECT, INSERT         ON fincore.cliente_pf      TO 'app_fincore'@'%';
GRANT SELECT, INSERT         ON fincore.cliente_pj      TO 'app_fincore'@'%';
-- contas: consultar e atualizar saldo/status
GRANT SELECT                 ON fincore.agencia         TO 'app_fincore'@'%';
GRANT SELECT, UPDATE         ON fincore.conta           TO 'app_fincore'@'%';
GRANT SELECT                 ON fincore.conta_corrente  TO 'app_fincore'@'%';
GRANT SELECT                 ON fincore.conta_poupanca  TO 'app_fincore'@'%';
GRANT SELECT                 ON fincore.titularidade    TO 'app_fincore'@'%';
-- movimentações: ler o extrato e registrar novas transações
GRANT SELECT                 ON fincore.categoria       TO 'app_fincore'@'%';
GRANT SELECT, INSERT         ON fincore.transacao       TO 'app_fincore'@'%';

-- 2.2 analista_fincore: relatórios e consultas (Workbench, planilhas)
-- quem só analisa dados nao pode alterar nada, então é só SELECT e só no banco fincore
CREATE USER 'analista_fincore'@'%' IDENTIFIED BY '__SENHA_ANALISTA__';
GRANT SELECT ON fincore.* TO 'analista_fincore'@'%';

-- 2.3 dba_fincore: administra o banco fincore (tabelas, índices, views, triggers, procedures, backup)
-- a manutenção do dia a dia nao deve ser feita com root: tem tudo, mas SÓ no fincore
-- (não mexe em outros bancos, não cria usuários e não repassa permissão, sem GRANT OPTION)
CREATE USER 'dba_fincore'@'%' IDENTIFIED BY '__SENHA_DBA__';
GRANT ALL PRIVILEGES ON fincore.* TO 'dba_fincore'@'%';

-- 3. verificação: mostra o que cada usuário pode fazer
SHOW GRANTS FOR 'app_fincore'@'%';
SHOW GRANTS FOR 'analista_fincore'@'%';
SHOW GRANTS FOR 'dba_fincore'@'%';
