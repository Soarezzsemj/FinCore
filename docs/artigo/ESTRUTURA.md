# Artigo FinCore — esqueleto

> Esqueleto do artigo. As seções abaixo seguem a estrutura comum de artigo acadêmico e os
> itens pedidos na entrega (aplicação, estrutura do banco, TCL, índices, views, stored objects e
> controle de acesso). **Confiram com o enunciado** e ajustem os títulos se ele pedir outra ordem.
> As justificativas técnicas já estão escritas (vêm dos comentários dos scripts em `sql/`);
> o que está entre `[colchetes]` falta escrever.

---

## Resumo

[100 a 250 palavras: problema (gestão financeira de um banco digital), solução (banco MySQL
com regras no próprio SGBD e aplicação web com acesso controlado), principais recursos
(transação com partida dobrada, procedures com COMMIT/ROLLBACK, views, índices, usuários com
privilégio mínimo) e resultado.]

**Palavras-chave:** banco de dados relacional; MySQL; controle transacional; controle de acesso; banco digital.

## 1. Introdução

[Contexto do tema Finanças, motivação, objetivo geral e objetivos específicos, organização do texto.]

## 2. Fundamentação teórica

[Modelo relacional, propriedades ACID, normalização, DCL/TCL, views, índices B-Tree,
stored procedures e triggers, princípio do menor privilégio.]

## 3. Metodologia

[Etapas: levantamento de requisitos, modelagem conceitual, lógica e física, implementação dos
scripts, aplicação, testes. Ferramentas: MySQL 8 (Docker), MySQL Workbench, C# .NET, Bootstrap, Git.]

## 4. Modelagem do banco

[Descrever o DER (`docs/diagramas/DER.jpeg`), o modelo lógico e o físico.]

- Núcleo: `transacao` com conta de origem (débito), conta de destino (crédito) e um único valor:
  todo débito tem um crédito igual (partida dobrada).
- Especialização: `cliente` → `cliente_pf` / `cliente_pj`; `conta` → `conta_corrente` / `conta_poupanca`.
- Entidade fraca: `parcela_emprestimo` (PK composta com `emprestimo`).
- Ternários: `aplicacao` (conta, produto, assessor) e `orcamento` (cliente, categoria, competência).
- Recursivos: `categoria` (pai/filha) e `transacao` (estorno aponta para a original).

## 5. Implementação

### 5.1 Estrutura e regras de integridade

[Tabelas, `CHECK`, `UNIQUE`, `FOREIGN KEY` com `RESTRICT` (RN01 a RN07 do README).]

### 5.2 Geração própria de IDs (`05_funcoes_id.sql`)

| Objeto | Para que serve | Por que existe |
|---|---|---|
| Tabela `sequencia` | Guarda o último ID usado de cada tabela crítica | Numeração visível, auditável e corrigível, em vez do contador interno do AUTO_INCREMENT |
| `fn_gerar_id(tabela)` | Devolve o próximo ID | O `UPDATE ... LAST_INSERT_ID(ultimo_valor + 1)` trava a linha até o fim da transação: dois acessos simultâneos nunca recebem o mesmo ID. A procedure conhece o ID antes do INSERT, e um ROLLBACK desfaz também o incremento (sem "buracos") |
| AUTO_INCREMENT mantido em `agencia`, `funcionario`, `categoria`, `produto_investimento`, `grupos_usuarios` | IDs das tabelas de apoio | Poucas linhas, quase não mudam e não guardam dinheiro: a solução padrão do MySQL basta e é mais simples |

### 5.3 Índices

| Índice | Consulta que acelera | Justificativa |
|---|---|---|
| `idx_trans_origem (id_conta_origem, dt_hora)` | Débitos de uma conta em ordem de data | Extrato: filtra pela conta e já devolve ordenado, sem *filesort* |
| `idx_trans_destino (id_conta_destino, dt_hora)` | Créditos de uma conta em ordem de data | Mesmo motivo, lado do crédito |
| `idx_trans_cat (id_categoria, dt_hora)` | Gastos por categoria num período | Relatórios de orçamento |
| `idx_parc_cobranca (status, dt_vencimento)` | Parcelas abertas já vencidas | Rotina de cobrança (UPDATE 5.1) |
| `idx_titular_cli (id_cliente)` | Contas de um cliente | A PK `(id_conta, id_cliente)` não serve para buscar só por cliente |
| `idx_compra_fatura (id_fatura)` | Compras de uma fatura | Soma da `vw_fatura_cartao` |
| `idx_cliente_nome (nome_razao)` | Busca de cliente pelo nome | Atendimento; sem ele o `EXPLAIN` mostra `type: ALL` |
| `idx_trans_data (dt_hora)` | Transações de um dia/mês | Os índices de extrato começam pela conta e não servem para filtrar só por data |
| `idx_fatura_cobranca (status, dt_vencimento)` | Faturas fechadas vencidas | Cobrança do cartão |

**Evidência (`06b_demo_indices.sql`):** sem `idx_cliente_nome`, `EXPLAIN SELECT ... WHERE nome_razao = 'Bruno Lima'`
mostra `type: ALL, key: NULL`; com o índice, `type: ref, key: idx_cliente_nome, rows: 1`.
[Colar o print dos dois EXPLAIN.]

### 5.4 Views (`06_views.sql`)

| View | Para que serve | Por que existe |
|---|---|---|
| `vw_saldo_cliente` | Saldo total por cliente (contas em que é TITULAR, sem a conta interna) | Tela de posição dos clientes (`GET /api/saldos`) |
| `vw_contas_cliente` | Conta com agência, titular, saldo, limite e saldo disponível | Lista de contas e formulário de transferência |
| `vw_extrato_conta` | Uma linha por lançamento (D negativo na origem, C positivo no destino) | A tela de extrato só filtra por conta |
| `vw_fatura_cartao` | Fatura com total das compras e % do limite | O cliente vê a fatura sem a aplicação somar compra por compra |

Benefício comum: a API faz só `SELECT * FROM vw_...`, sem repetir JOINs no C#; e a view roda
com os privilégios de quem a criou, então a API lê a view sem ter acesso a todas as tabelas dela
(ex.: `cartao`).

### 5.5 Triggers, functions e procedures (`07_triggers_procedures.sql`)

| Objeto | Para que serve | Por que existe |
|---|---|---|
| `trg_transacao_valida` (BEFORE INSERT em `transacao`) | Só deixa movimentar contas com status ATIVA | Conta bloqueada/encerrada não envia nem recebe dinheiro, venha a transação de onde vier (RN10) |
| `trg_transacao_saldo` (AFTER INSERT em `transacao`) | Debita a origem e credita o destino | O saldo nunca fica diferente da soma das transações (RN08), sem depender de quem insere |
| `fn_saldo_disponivel(conta)` | Saldo + limite do cheque especial | Quanto a conta ainda pode gastar; negativo = passou do limite (RN09) |
| `sp_transferir(origem, destino, valor, chave)` | Transferência entre contas | Vários passos (ID, transação, dois saldos) que precisam acontecer juntos; a chave evita duplicidade. Única forma de a API movimentar dinheiro |
| `sp_pagar_parcela(emprestimo, parcela)` | Paga uma parcela com o saldo da conta | Baixa da parcela e débito precisam andar juntos; se o débito falha, a baixa é desfeita (RN11) |

### 5.6 Controle transacional (TCL)

As procedures usam `START TRANSACTION`, `COMMIT` e `DECLARE EXIT HANDLER FOR SQLEXCEPTION`
com `ROLLBACK` + `RESIGNAL`. Na `sp_transferir` a transação é gravada **antes** da conferência
do saldo; se o saldo passou do limite, o `SIGNAL` cai no handler e o `ROLLBACK` desfaz o INSERT,
os dois saldos e o ID gerado.

**Evidência (`07b_demo_transacoes.sql` e site):** transferência de R$ 100 → saldos mudam (COMMIT);
transferência de R$ 1.000.000 → "Saldo insuficiente", saldos e `sequencia` iguais (ROLLBACK).
[Colar prints.]

### 5.7 Controle de acesso

**Tabelas da aplicação (`04_usuarios_acesso.sql`, parte A):**

| Objeto | Para que serve | Por que existe |
|---|---|---|
| `grupos_usuarios` | Perfis ADMIN, GERENTE, ATENDENTE, CLIENTE | Define o que cada pessoa pode fazer na aplicação |
| `usuarios` | Login único, hash da senha (SHA-256 com salt), grupo, vínculo opcional com `cliente`, status | A senha nunca é guardada em texto; o salt faz senhas iguais gerarem hashes diferentes |

**Usuários do MySQL (parte B, com `GRANT`/`REVOKE` complementares no `06` e `07`):**

| Usuário | Privilégios | Justificativa |
|---|---|---|
| `app_fincore` | `SELECT` nas tabelas e views das telas; `INSERT`/`UPDATE` em `usuarios` e cliente; `EXECUTE` só na `sp_transferir` | A aplicação nunca usa root. Sem `DELETE` (histórico financeiro não se apaga, RN07), sem DDL, sem alterar saldo ou gravar transação direto: dinheiro só se move pela procedure |
| `analista_fincore` | `SELECT` em `fincore.*` | Quem só analisa dados não pode alterar nada |
| `dba_fincore` | `ALL PRIVILEGES` só em `fincore.*`, sem `GRANT OPTION` | Manutenção sem root: não mexe em outros bancos, não cria usuários, não repassa permissões |

Senhas dos usuários do MySQL ficam no `.env` (fora do Git). Evidências em `docs/evidencias.md`.

## 6. Aplicação

[Arquitetura: navegador → API C# (Minimal API, MySqlConnector, sem ORM) → MySQL como `app_fincore`.
Login por token, autorização por grupo (401/403), consultas sempre com parâmetros (`@param`)
contra SQL Injection. Documentação OpenAPI + Scalar. Prints das telas por grupo.]

## 7. Resultados e discussão

[O que foi testado (scripts do zero, rotas, COMMIT/ROLLBACK, EXPLAIN, permissões), limitações
(sessões na memória da API, hash SHA-256 simples em vez de bcrypt/Argon2) e melhorias.]

### 7.1 Onde um NoSQL poderia entrar

Contas, saldos e transações ficam no MySQL (exigem ACID e chaves estrangeiras). Um NoSQL
caberia em partes auxiliares: sessões de login num chave-valor (Redis) com expiração automática;
log de auditoria/eventos num banco de documentos (MongoDB), com muito volume e formato variável;
cache de extrato e saldos.

## 8. Considerações finais

[Retomar os objetivos, o que foi alcançado e trabalhos futuros.]

## Referências

[Documentação do MySQL 8.0 (CREATE USER/GRANT, Stored Objects, EXPLAIN, InnoDB Locking),
documentação do ASP.NET Core e do Scalar, livros da disciplina — no formato ABNT.]
