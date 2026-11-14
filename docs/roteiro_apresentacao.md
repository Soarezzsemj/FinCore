# Roteiro da apresentação (5 minutos)

## Antes de começar (não conta no tempo)

1. `docker compose down -v` e `docker compose up -d`: banco limpo, com os dados originais.
2. `cd backend/FinCoreApi` e `dotnet run`.
3. Deixar abertas três abas: o site (http://localhost:3000), o Scalar
   (http://localhost:3000/scalar) e o MySQL Workbench conectado em `localhost:3307`, com os
   arquivos `06b_demo_indices.sql` e `07b_demo_transacoes.sql` abertos.
4. Não precisa de internet: o Bootstrap já vem no projeto (`frontend/lib/bootstrap.min.css`).

Cada bloco diz **quem fala**, **o que mostrar** e **o que dizer**. O texto entre aspas é uma
sugestão para ler em voz alta.

---

## 1. Aplicação (0:00 – 1:10)

**Mostrar:** o site. Entrar como `gerente` / `fincore123`.

> "O FinCore é um banco digital. Esta é a aplicação: uma API em C# e um site em HTML com
> Bootstrap. Logado como gerente, eu vejo o saldo por cliente, que vem de uma **view**, e a lista
> de clientes, que vem direto da **tabela** `cliente`. Cada tabela diz na tela de onde vêm os dados."

**Mostrar:** clicar em *Sair* e entrar como `ana`.

> "Agora como a cliente Ana: ela só vê as próprias contas. As senhas ficam no banco apenas como
> hash, e cada grupo (ADMIN, GERENTE, ATENDENTE, CLIENTE) só acessa as rotas permitidas. Sem login,
> a API responde 401."

## 2. Estrutura do banco (1:10 – 1:50)

**Mostrar:** o DER (`docs/diagramas/DER.jpeg`).

> "O centro do modelo é a tabela `transacao`: cada linha tem a conta de origem, a de destino e um
> único valor, então todo débito tem um crédito igual. Temos especialização de cliente em PF e PJ,
> entidade fraca na parcela do empréstimo e relacionamentos ternários. Os IDs dos dados críticos
> não usam AUTO_INCREMENT: vêm da função `fn_gerar_id`, que trava a linha da sequência e
> nunca gera dois IDs iguais."

## 3. TCL: COMMIT e ROLLBACK (1:50 – 3:00)

**Mostrar:** voltar ao site como `gerente` e clicar em *Transferência* no menu.

> "A transferência chama a procedure `sp_transferir`, que usa START TRANSACTION, COMMIT e ROLLBACK."

**Clicar:** *Exemplo que dá certo (COMMIT)*.

> "Ana mandou 50 reais para o Bruno. A tabela mostra o saldo antes e depois: os dois mudaram, e a
> transação já aparece no extrato. Foi um COMMIT."

**Clicar:** *Exemplo que falha (ROLLBACK)*.

> "Agora 1 milhão. A procedure grava a transação, o trigger debita a conta, e aí ela confere o saldo:
> passou do limite do cheque especial. O erro dispara o ROLLBACK, que desfaz tudo. Os saldos antes e
> depois estão iguais: nada ficou gravado."

**Clicar:** *Repetir a última (mesma chave)*.

> "E se o mesmo pedido chegar duas vezes? A chave de idempotência impede a transferência duplicada."

## 4. Índices (3:00 – 3:40)

**Mostrar:** Workbench, `06b_demo_indices.sql`. Rodar o arquivo inteiro.

> "Aqui apagamos o índice do nome do cliente e pedimos o EXPLAIN: type ALL, o MySQL lê a tabela
> inteira. Criamos o índice e repetimos: type ref, ele vai direto na linha pelo `idx_cliente_nome`.
> Cada índice do projeto tem um comentário no script dizendo qual consulta ele acelera."

## 5. Views e stored objects (3:40 – 4:20)

**Mostrar:** no Workbench, `SELECT * FROM vw_extrato_conta WHERE id_conta = 2;` e depois o
arquivo `07_triggers_procedures.sql` rolando pela tela.

> "Temos quatro views: saldo por cliente, contas, extrato e fatura do cartão. A API só faz
> SELECT nelas, sem repetir os JOINs no C#. Nos stored objects: o trigger que atualiza o saldo
> a cada transação, o trigger que bloqueia conta inativa, a função de saldo disponível e as
> procedures de transferência e de pagamento de parcela."

## 6. Controle de acesso (4:20 – 5:00)

**Mostrar:** no Scalar, `GET /api/saude` → *Test Request*. Depois, no Workbench:
`SHOW GRANTS FOR 'app_fincore'@'%';`

> "A aplicação nunca usa root. A rota de saúde mostra o usuário conectado: `app_fincore`.
> O SHOW GRANTS mostra que ele só lê as tabelas e views das telas e só pode executar a
> `sp_transferir`: não apaga nada, não altera saldo direto e não mexe na estrutura. Temos ainda
> o `analista_fincore`, só leitura, e o `dba_fincore`, que administra apenas o banco fincore.
> Obrigado!"

---

## Se algo der errado

| Problema | Saída rápida |
|---|---|
| Site sem estilo | Conferir se `frontend/lib/bootstrap.min.css` existe e recarregar com Ctrl+F5 |
| "Banco de dados indisponível" | `docker compose up -d` e esperar ~30 s |
| "Sessão expirada" | A API reiniciou: entrar de novo |
| Saldos muito diferentes do ensaio | `docker compose down -v && docker compose up -d` |
