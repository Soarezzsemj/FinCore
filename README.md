# FinCore — Banco de Dados para Banco Digital e Gestão Financeira

Trabalho da disciplina **Laboratório de Banco de Dados (GPE17N40158)**.
**Tema:** Finanças · **SGBD:** MySQL 8.0+ · **NoSQL (opcional):** MongoDB 7 (log de auditoria) · **Aplicação:** C# (ASP.NET Core, .NET 10) + HTML/Bootstrap

## Equipe

| Integrantes do grupo | 
|------|
| _CARLOS EDUARDO SOARES SOUZA SANTOS_ | 
| _DANIEL GAMA MACHADO_ | 
| _CAUAN CARVALHO DOS SANTOS_ | 
| _HEITOR XAVIER CARVALHO_ | 
| _KAUAN PIERRE TEIXEIRA DE LIMA_ | 


Professor(a): _JEFFERSON SALOMAO RODRIGUES_ · Instituição: _Universidade Católica de Brasília_ · Semestre: _2026/2_

## Sobre o projeto

O FinCore modela um banco digital: clientes (pessoa física e jurídica), contas correntes e
poupança, movimentações, cartão de crédito com faturas, empréstimos parcelados, investimentos
e orçamento pessoal.

O núcleo é a tabela `transacao`, que registra a **conta de origem (débito)**, a **conta de destino
(crédito)** e um único valor. Assim, todo débito tem um crédito de mesmo valor (partida dobrada) e o
saldo de qualquer conta pode ser conferido pela soma das transações.

Sobre o banco existe uma aplicação web: uma API em C# que conecta no MySQL com um usuário de
privilégios mínimos (`app_fincore`, nunca o root) e um site em HTML + Bootstrap com login por grupo,
consultas e transferência com controle transacional.

Como recurso opcional, a API grava um **log de auditoria no MongoDB** (NoSQL): logins, falhas de
login e cada tentativa de transferência, inclusive as que a `sp_transferir` desfaz com `ROLLBACK`.
O dinheiro (contas, saldos e transações) continua **só no MySQL**. Veja a seção
[NoSQL: log de auditoria no MongoDB](#nosql-log-de-auditoria-no-mongodb).

- **Contexto e justificativa:** sistemas financeiros exigem que o dinheiro não se perca nem se duplique, que o histórico não seja apagado e que cada pessoa veja só o que lhe cabe. Por isso as regras ficam no próprio banco (restrições, triggers e procedures), e não na aplicação. O texto completo está no artigo em `docs/`.
- **Escopo:** cadastro de clientes e contas, movimentações, cartões, empréstimos, investimentos e orçamento.
- **Fora do escopo:** emissão fiscal, integração com o Banco Central e antifraude.

## Estrutura do repositório

```
FinCore/
├── README.md
├── docker-compose.yaml          # sobe o MySQL 8 (porta 3307, roda os scripts na 1ª vez) e o MongoDB 7 (porta 27017)
├── .env.example                 # modelo do .env (senhas ficam só no .env, fora do Git)
├── sql/
│   ├── 01_schema.sql            # DDL: banco, tabelas, restrições e índices
│   ├── 02_dados.sql             # INSERTs (população do banco)
│   ├── 03_consultas.sql         # SELECTs, UPDATEs e revisão do conteúdo (não roda no Docker)
│   ├── 04_usuarios_acesso.sql   # tabelas usuarios/grupos_usuarios e usuários do MySQL (GRANT)
│   ├── 04_usuarios_acesso.sh    # no Docker, coloca as senhas do .env e roda o 04
│   ├── 05_funcoes_id.sql        # tabela sequencia e fn_gerar_id (geração própria de IDs)
│   ├── 06_views.sql             # views e índices novos
│   ├── 06b_demo_indices.sql     # demonstração: EXPLAIN antes e depois de um índice
│   ├── 07_triggers_procedures.sql  # triggers, fn_saldo_disponivel, sp_transferir, sp_pagar_parcela
│   └── 07b_demo_transacoes.sql  # demonstração: COMMIT e ROLLBACK
├── backend/
│   └── FinCoreApi/              # API em C# com OpenAPI + Scalar
│       ├── Program.cs           # configuracao: .env, conexao, openapi/scalar, site
│       ├── Controllers/         # rotas (Saude, Login, Clientes, Contas, Transferencias, Auditoria)
│       ├── Data/                # Banco.cs (conexao com o MySQL), Auditoria.cs (MongoDB), Sessoes.cs, ArquivoEnv.cs
│       └── Models/              # LoginDto, TransferenciaDto, UsuarioLogado
├── frontend/
│   ├── index.html               # login
│   ├── painel.html              # saldos (view), clientes (tabela) e contas (view)
│   ├── transferencia.html       # transferencia com demonstracao de COMMIT/ROLLBACK
│   ├── extrato.html             # extrato de uma conta (view)
│   ├── auditoria.html           # log de auditoria lido do MongoDB (só ADMIN)
│   ├── css/style.css
│   ├── lib/bootstrap.min.css    # bootstrap 5.3.3 local (funciona sem internet)
│   └── js/                      # JavaScript puro: api.js (sessao + chamadas), tabelas.js, menu.js
│                                #   e um arquivo por pagina (login.js, painel.js, transferencia.js, extrato.js, auditoria.js)
└── docs/
    ├── FinCore_Entrega_Final_v4.pdf  # artigo (documento técnico) da entrega
    └── diagramas/               # DER, modelo lógico e modelo físico
```

## Como rodar do zero

Pré-requisitos: **Docker** (com Docker Compose) e **.NET SDK 10** (o projeto usa `net10.0`) (`dotnet --version`).

1. **Configuração.** Copie o modelo e troque as senhas (use só letras, números e `@ # ! _ - .`):

   ```bash
   cp .env.example .env
   ```

   O `.env` guarda as senhas e **não vai para o Git** (está no `.gitignore`).

2. **Bancos.** Suba o MySQL e o MongoDB:

   ```bash
   docker compose up -d
   ```

   Sobem dois containers: `fincore-mysql` (dados do banco) e `fincore-mongo` (log de auditoria).
   Confira com `docker ps`.

   Na primeira vez o container roda sozinho, em ordem: `01`, `02`, `04` (via `.sh`), `05`, `06` e `07`.
   Leva uns 30 segundos. Para acompanhar: `docker logs -f fincore-mysql` (espere a linha
   `ready for connections ... port: 3306`).

3. **API e site.** Em outro terminal:

   ```bash
   cd backend/FinCoreApi
   dotnet run
   ```

   A API lê o `.env` da raiz do projeto, conecta no MySQL como `app_fincore` e no MongoDB pelo
   `MONGO_URL` (padrão `mongodb://localhost:27017`). Se o MongoDB estiver fora do ar, a API funciona
   normalmente: só os eventos de auditoria deixam de ser gravados.

4. **Abra no navegador:**

   | O quê | Endereço |
   |---|---|
   | Site (login e painel) | http://localhost:3000 |
   | Documentação interativa (Scalar) | http://localhost:3000/scalar |
   | Documento OpenAPI (JSON) | http://localhost:3000/openapi/v1.json |
   | Teste rápido de conexão | http://localhost:3000/api/saude |

Comandos úteis:

- `docker compose down`: para os bancos e mantém os dados.
- `docker compose down -v` e depois `docker compose up -d`: **apaga** o MySQL e o MongoDB e roda
  todos os scripts de novo (use para voltar aos dados originais antes da apresentação).

| Serviço | Porta no seu PC |
|---|---|
| MySQL (container `fincore-mysql`) | `3307` (no container é a 3306) |
| MongoDB (container `fincore-mongo`) | `27017` |
| API + site | `3000` |

### Rodando os scripts à mão (Workbench)

Conecte em `localhost:3307` como root e execute os arquivos **na ordem numérica**: `01`, `02`,
`03` (opcional), `04`, `05`, `06`, `07`. O `01` recria o banco `fincore` do zero. Antes de rodar o
`04`, troque as marcas `__SENHA_APP__`, `__SENHA_ANALISTA__` e `__SENHA_DBA__` pelas senhas do `.env`.
Os scripts `06b` e `07b` são demonstrações; no `07b` rode um comando por vez (Ctrl+Enter), porque
alguns erros são de propósito.

## Usuários e permissões

### Usuários do MySQL (`04_usuarios_acesso.sql`, senhas no `.env`)

| Usuário | Para quê | Privilégios |
|---|---|---|
| `app_fincore` | a API | `SELECT` nas tabelas e views que as telas usam; `INSERT`/`UPDATE` só em `usuarios` e `cliente`, `INSERT` em `cliente_pf` e `cliente_pj`; `EXECUTE` só na `sp_transferir`. Sem `DELETE`, sem DDL, sem alterar saldo ou gravar transação direto |
| `analista_fincore` | relatórios | só `SELECT` nas tabelas do domínio financeiro e nas views (sem `usuarios`, `grupos_usuarios` e `sequencia`) |
| `dba_fincore` | manutenção | tudo, mas só no banco `fincore` (não cria usuários nem repassa permissões) |
| `root` | montar o banco | usado só pelo Docker/administrador; **a aplicação recusa iniciar se `DB_USER=root`** |

**Como provar** (a Seção 9.3 do artigo traz o mesmo roteiro):

- Abra http://localhost:3000/api/saude: mostra `app_fincore@%`, nunca `root`.
- Conecte como `app_fincore` (`docker exec -it fincore-mysql mysql -uapp_fincore -p`) e rode
  `SHOW GRANTS FOR CURRENT_USER();`: aparece `USAGE ON *.*`, `SELECT` em tabelas e views específicas e
  `EXECUTE` só em `sp_transferir`.
- Ainda como `app_fincore`, `DROP TABLE`, `DELETE`, `UPDATE conta ...` e `INSERT INTO transacao ...`
  são recusados (erro 1142).
- Com `DB_USER=root` no `.env`, a API se recusa a iniciar.

### Usuários da aplicação (tabela `usuarios`)

Todos com a senha de teste **`fincore123`** (guardada só como hash SHA-256 com salt):

| Login | Grupo | O que vê no site |
|---|---|---|
| `admin` | ADMIN | saldos, clientes, contas, transferência, extrato e auditoria (MongoDB) |
| `gerente` | GERENTE | saldos, clientes, contas, transferência, extrato |
| `atendente` | ATENDENTE | saldos, clientes, contas e extrato (não transfere) |
| `ana` | CLIENTE (cliente 2) | só as próprias contas, extrato e transferência a partir delas |
| `bruno` | CLIENTE (cliente 3) | idem (é cotitular da conta 2 da Ana) |

### Rotas da API

| Rota | Quem pode | Origem dos dados |
|---|---|---|
| `GET /api/saude` | todos (pública) | `SELECT CURRENT_USER()` |
| `POST /api/login` | todos (pública) | tabela `usuarios` + `grupos_usuarios` |
| `POST /api/logout` | logado | — |
| `GET /api/saldos` | ADMIN, GERENTE, ATENDENTE | view `vw_saldo_cliente` |
| `GET /api/clientes` | ADMIN, GERENTE, ATENDENTE | tabela `cliente` |
| `GET /api/contas` | todos os grupos (CLIENTE só as suas) | view `vw_contas_cliente` |
| `GET /api/contas/{id}/extrato` | todos os grupos (CLIENTE só as suas) | view `vw_extrato_conta` |
| `POST /api/transferencias` | ADMIN, GERENTE, CLIENTE | procedure `sp_transferir` |
| `GET /api/auditoria?quantidade=20` | só ADMIN | **MongoDB**, coleção `eventos` (padrão 20, máximo 100) |

Sem token, as rotas protegidas devolvem **401**; com um grupo sem permissão, **403**.
**Autenticar no Scalar:** rode `POST /api/login`, copie o `token` da resposta, clique em
*Authentication* (Bearer) e cole o token; as outras rotas passam a enviá-lo.

## Mapa: requisito do trabalho → onde está no projeto

| Requisito | Onde está |
|---|---|
| Modelagem (DER, lógico, físico) | `docs/diagramas/`, `docs/FinCore_Entrega_Final_v4.pdf` |
| Estrutura do banco (DDL, restrições) | `sql/01_schema.sql` |
| População do banco | `sql/02_dados.sql` |
| Consultas e conteúdo da disciplina (DML, álgebra relacional) | `sql/03_consultas.sql` |
| Tabelas `usuarios` e `grupos_usuarios` | `sql/04_usuarios_acesso.sql` (parte A) |
| Controle de acesso: usuários do MySQL com `GRANT` mínimo | `sql/04_usuarios_acesso.sql` (parte B) + `GRANT`/`REVOKE` no `06` e `07` |
| Geração própria de IDs | `sql/05_funcoes_id.sql` (`sequencia`, `fn_gerar_id`) |
| Views | `sql/06_views.sql` (`vw_saldo_cliente`, `vw_contas_cliente`, `vw_extrato_conta`, `vw_fatura_cartao`) |
| Índices (com justificativa) e impacto no `EXPLAIN` | `sql/01_schema.sql`, `sql/06_views.sql`, `sql/06b_demo_indices.sql` |
| Triggers | `sql/07_triggers_procedures.sql` (`trg_transacao_valida`, `trg_transacao_saldo`) |
| Functions e procedures (stored objects) | `sql/05_funcoes_id.sql`, `sql/07_triggers_procedures.sql` (`fn_saldo_disponivel`, `sp_transferir`, `sp_pagar_parcela`) |
| TCL: `START TRANSACTION`, `COMMIT`, `ROLLBACK` | `sp_transferir` e `sp_pagar_parcela`; demonstração em `sql/07b_demo_transacoes.sql` e no site |
| Aplicação conectada ao banco | `backend/FinCoreApi/` (`Data/Banco.cs` faz a conexão, `Controllers/` as rotas) + `frontend/` |
| Aplicação sem root | `.env` (`DB_USER=app_fincore`), `/api/saude` e a seção "Como provar" acima |
| Login com senha em hash e autorização por grupo | `Controllers/LoginController.cs` e `VerificarAcesso` em `Controllers/BaseController.cs`; links e seções com `data-grupos` nas páginas + `frontend/js/menu.js` |
| Documentação da API | OpenAPI + Scalar em `/scalar` |
| NoSQL (opcional) | MongoDB: `Data/Auditoria.cs`, `Controllers/AuditoriaController.cs`, `frontend/auditoria.html` |
| Documento técnico (artigo acadêmico) | `docs/FinCore_Entrega_Final_v4.pdf` |

## Modelagem

Diagramas em `docs/diagramas/`:

- `DER.jpeg`
- `Modelo Logico.jpeg`
- `Modelo Fisico.jpeg`

| Requisito do trabalho | Onde aparece |
|---|---|
| Entidades fortes | `cliente`, `conta`, `agencia`, `funcionario`, `cartao`, `emprestimo`, `produto_investimento` |
| Entidade fraca | `parcela_emprestimo` (PK composta com `emprestimo`) |
| Entidades associativas | `titularidade` (cliente × conta), `transacao` (conta × conta), `aplicacao` |
| Generalização/especialização | `cliente` → `cliente_pf`/`cliente_pj`; `conta` → `conta_corrente`/`conta_poupanca` |
| Relacionamento 1:1 | `conta` – `conta_corrente` ou `conta_poupanca` (especialização) |
| Relacionamento 1:N | `agencia` – `conta`, `conta` – `cartao`, `cartao` – `fatura_cartao` |
| Relacionamento M:N com atributo | `cliente` – `conta` (`titularidade`, atributo `papel`) |
| Relacionamentos ternários | `aplicacao` (conta, produto, assessor) e `orcamento` (cliente, categoria, competência) |
| Relacionamentos recursivos | `categoria` (pai/filha), `transacao` (estorno) e conta × conta (origem/destino) |
| Atributo composto | endereço em `cliente` (`end_rua`, `end_numero`, ...) |
| Atributo multivalorado | `telefone_cliente` |

## Regras de negócio

**Garantidas pelo esquema** (restrições do próprio banco):

| Código | Regra | Como |
|---|---|---|
| RN01 | Todo débito tem um crédito de mesmo valor | `transacao` guarda origem, destino e um único valor |
| RN02 | Origem e destino da transação são contas diferentes | `CHECK` |
| RN03 | Valores monetários são sempre positivos | `CHECK (valor > 0)` |
| RN04 | Uma transação não é registrada duas vezes | `chave_idempotencia` com `UNIQUE` (e conferida na `sp_transferir`) |
| RN05 | PF tem CPF (11 dígitos) e PJ tem CNPJ (14), únicos | `CHECK` + `UNIQUE` |
| RN06 | Status, tipos e bandeiras seguem valores fixos | `CHECK ... IN (...)` |
| RN07 | Contas e clientes com movimentação não podem ser apagados; a correção é feita por estorno | `FOREIGN KEY ... ON DELETE RESTRICT` e `id_transacao_estornada` |

**Garantidas por triggers e procedures** (`07_triggers_procedures.sql`):

| Código | Regra | Como |
|---|---|---|
| RN08 | O saldo da conta é igual aos créditos menos os débitos | trigger `trg_transacao_saldo` atualiza o saldo a cada transação |
| RN09 | Conta de cliente não fica abaixo do limite do cheque especial | `sp_transferir` confere `fn_saldo_disponivel` e faz `ROLLBACK` |
| RN10 | Conta bloqueada ou encerrada não movimenta dinheiro | trigger `trg_transacao_valida` |
| RN11 | Pagar parcela = baixa da parcela + débito, juntos ou nada | `sp_pagar_parcela` com transação |

**Verificadas por consultas** (`03_consultas.sql`): 4.3 (RN08) e 4.4 (RN09) devem retornar 0 linhas;
UPDATEs 5.1 e 5.2 marcam parcelas vencidas como atrasadas, com multa de 2%, e o empréstimo como inadimplente.

## Escalabilidade

- Chaves `BIGINT` nas tabelas de maior volume (`conta`, `transacao`, cartão e empréstimo).
- IDs dos dados críticos gerados pela `fn_gerar_id` com trava de linha (seguro com acessos simultâneos).
- Transação com origem e destino na mesma linha, sem tabela extra de lançamentos, o que reduz
  escrita e junções.
- Saldo guardado na conta (leitura direta), mantido pelo trigger e recalculável a partir das transações (UPDATE 5.5).
- Índices compostos para extrato (`conta`, `dt_hora`), relatórios por categoria e por data e cobrança.
- Integridade referencial com `RESTRICT` para proteger o histórico financeiro.
- Em produção, `transacao` poderia ser particionada por data. O InnoDB não aceita chave
  estrangeira em tabelas particionadas, por isso o modelo entregue não usa partição.

## NoSQL: log de auditoria no MongoDB

O dinheiro (contas, saldos, transações) **fica no MySQL**: precisa de transação ACID, chave
estrangeira e `ROLLBACK`. O MongoDB (banco de documentos) foi adotado só para o **log de auditoria**.

**Que dados guarda.** Banco `fincore_auditoria`, coleção `eventos`. Cada documento tem
`{ tipo, usuario, data (UTC), detalhes }`, e os `detalhes` mudam conforme o tipo:

| Tipo | Quando | Detalhes |
|---|---|---|
| `LOGIN_OK` | login aceito | grupo |
| `LOGIN_FALHA` | senha errada, login inexistente ou usuário bloqueado | motivo (o usuário é o login digitado) |
| `TRANSFERENCIA_OK` | `sp_transferir` fez `COMMIT` | contas, valor, chave, id da transação |
| `TRANSFERENCIA_ERRO` | `sp_transferir` fez `ROLLBACK` (400) ou chave repetida (409) | contas, valor, chave e a mensagem do erro |
| `TRANSFERENCIA_NEGADA` | grupo sem permissão ou conta de outro cliente (403) | contas, valor, chave e motivo |

Nenhum evento guarda senha, hash, salt ou token.

**Por que foi adotado (e não uma tabela no MySQL):**

- **Guarda o que o `ROLLBACK` apaga.** Quando a `sp_transferir` falha, tudo o que foi gravado no
  MySQL na mesma transação é desfeito; um log no MySQL dentro da transação sumiria junto. O
  MongoDB guarda a evidência da tentativa: a transferência com saldo insuficiente **não** está em
  `transacao`, mas está em `eventos`.
- **Formato variável.** Cada tipo de evento tem campos diferentes; numa tabela seriam muitas
  colunas quase sempre nulas.
- **Só inserção, volume que cresce sem parar.** O log não pesa no banco transacional e tem um
  índice em `data` (decrescente) para a consulta "últimos eventos".
- **Nunca derruba a operação.** A gravação tem `try/catch` e espera no máximo 2 segundos; com o
  MongoDB parado, login e transferência continuam funcionando.

Outros usos possíveis (não implementados): sessões de login num banco chave-valor como o
**Redis**, com expiração automática, e cache do extrato e dos saldos.

## Alinhamento com o conteúdo da disciplina

| Tópico | Onde |
|---|---|
| `CREATE DATABASE`, `CREATE TABLE`, `PRIMARY KEY`, `FOREIGN KEY` com `CONSTRAINT`, `NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT`, `AUTO_INCREMENT` (tabelas de apoio) | `01_schema.sql` |
| Ações referenciais `ON UPDATE` e `ON DELETE` (`CASCADE`, `SET NULL`, `RESTRICT`) | `01_schema.sql` |
| `INSERT`, incluindo `INSERT ... SELECT` | `02_dados.sql` e UPDATEs 5.3 e 5.4 |
| `ALTER TABLE` (ADD, MODIFY, DROP COLUMN), `RENAME`, `TRUNCATE`, `DROP TABLE` | 6.1 (tabela auxiliar `demo_meta`) |
| Seleção, projeção, `AND`/`OR`/`NOT`, `IS NULL`, `LIKE`, `IN`, `BETWEEN`, `ORDER BY`, `LIMIT` | 6.2 |
| `MIN`, `MAX`, `AVG`, `COUNT`, `SUM`, `GROUP BY`, `HAVING` | 4.2, 4.5 e 6.3 |
| União, interseção e diferença | 4.1 e 6.4 |
| Produto cartesiano (`CROSS JOIN`), auto-junção, `INNER`/`LEFT`/`RIGHT JOIN`, junção externa completa | 6.5 |
| Divisão (÷) | 6.6 |
| `UPDATE` e `DELETE` | seção 5 e 6.7 |
| `CREATE USER`, `GRANT`, `REVOKE`, `SHOW GRANTS` (DCL) | `04`, `06` e `07` |
| `CREATE VIEW`, `CREATE INDEX`, `EXPLAIN` | `06_views.sql`, `06b_demo_indices.sql` |
| `CREATE FUNCTION`, `CREATE PROCEDURE`, `CREATE TRIGGER`, `SIGNAL`, `DECLARE EXIT HANDLER` | `05` e `07` |
| `START TRANSACTION`, `COMMIT`, `ROLLBACK` (TCL) | `07_triggers_procedures.sql`, `07b_demo_transacoes.sql` |

As consultas da seção 6 trazem, em comentário, a expressão de álgebra relacional equivalente.

## Como validar

- `docker compose down -v && docker compose up -d`: sobe sem erro (`docker logs fincore-mysql`).
- http://localhost:3000/api/saude mostra `"usuario_banco": "app_fincore@%"`.
- Sem login, http://localhost:3000/api/clientes devolve 401.
- Logado como `admin`, a tela **Auditoria** mostra os eventos do MongoDB (falhas em vermelho);
  `gerente` e `ana` recebem 403 em `/api/auditoria`.
- No site, logado como `gerente`: **Exemplo que dá certo** muda os saldos; **Exemplo que falha**
  mostra "Saldo insuficiente... ROLLBACK" e os saldos antes/depois iguais.
- `sql/06b_demo_indices.sql`: o `EXPLAIN` passa de `type: ALL` para `type: ref`.
- `sql/03_consultas.sql`: 4.3 e 4.4 retornam 0 linhas; descomente os `INSERT` da 5.10 e os
  `DELETE` da 6.7 para ver o banco recusar dados inválidos.