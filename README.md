# FinCore — Banco de Dados para Banco Digital e Gestão Financeira

Trabalho da disciplina **Laboratório de Banco de Dados (GPE17N40158)**.
**Tema:** Finanças · **SGBD:** MySQL 8.0+

## Equipe

| Nome | Responsabilidade principal |
|------|----------------------------|
| _KAUAN PIERRE TEIXEIRA DE LIMA_ | _Modelagem conceitual_ |
| _HEITOR XAVIER CARVALHO_ | _Modelagem lógica e física_ | 
| _CARLOS EDUARDO SOARES SOUZA SANTOS_ | _Scripts SQL (DDL e regras)_ |
| _CAUAN CARVALHO DOS SANTOS_ | _Dados, consultas e documentação_ |
| _DANIEL GAMA MACHADO_ | _Diagramas e documento em PDF_ |

Professor(a): _JEFFERSON SALOMAO RODRIGUES_ · Instituição: _Universidade Católica de Brasília_ · Semestre: _2026/2_

## Sobre o projeto

O FinCore modela um banco digital: clientes (pessoa física e jurídica), contas correntes e
poupança, movimentações, cartão de crédito com faturas, empréstimos parcelados, investimentos
e orçamento pessoal.

O núcleo é a tabela `transacao`, que registra a **conta de origem (débito)**, a **conta de destino
(crédito)** e um único valor. Assim, todo débito tem um crédito de mesmo valor (partida dobrada) e o
saldo de qualquer conta pode ser conferido pela soma das transações.

- **Contexto e justificativa:** _(resumo; o texto completo está no PDF em `docs/`)_
- **Escopo:** cadastro de clientes e contas, movimentações, cartões, empréstimos, investimentos e orçamento.
- **Fora do escopo:** emissão fiscal, integração com o Banco Central e antifraude.

## Estrutura do repositório

```
fincore-banco-de-dados/
├── README.md
├── sql/
│   ├── 01_schema.sql       # DDL: banco, tabelas, restrições e índices
│   ├── 02_dados.sql        # INSERTs (população do banco)
│   └── 03_consultas.sql    # SELECTs, UPDATEs e revisão do conteúdo da disciplina
└── docs/
    ├── documento-final.pdf # documento de entrega
    └── diagramas/          # DER conceitual, modelo lógico e modelo físico (PNG)
```

## Como executar

Pré-requisito: MySQL 8.0 ou superior (Workbench ou cliente `mysql`).

```bash
mysql -u root -p < sql/01_schema.sql
mysql -u root -p < sql/02_dados.sql
mysql -u root -p < sql/03_consultas.sql
```

No MySQL Workbench, abra e execute os três arquivos na ordem. O `01_schema.sql` recria o banco
`fincore` do zero. Como o `03_consultas.sql` altera dados (seção 5 e seção 6.7), para executá-lo
de novo rode antes o `01` e o `02`.

Os scripts foram executados e conferidos no MySQL 8.0.

## Modelagem

Diagramas em `docs/diagramas/`:

- `der-conceitual.png`
- `modelo-logico.png`
- `modelo-fisico.png`

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
| RN04 | Uma transação não é registrada duas vezes | `chave_idempotencia` com `UNIQUE` |
| RN05 | PF tem CPF (11 dígitos) e PJ tem CNPJ (14), únicos | `CHECK` + `UNIQUE` |
| RN06 | Status, tipos e bandeiras seguem valores fixos | `CHECK ... IN (...)` |
| RN07 | Contas e clientes com movimentação não podem ser apagados; a correção é feita por estorno | `FOREIGN KEY ... ON DELETE RESTRICT` e `id_transacao_estornada` |

**Verificadas por consultas** (`03_consultas.sql`):

| Código | Regra | Consulta |
|---|---|---|
| RN08 | O saldo da conta é igual aos créditos menos os débitos | 4.3 (deve retornar 0 linhas) |
| RN09 | Conta de cliente não fica abaixo do limite do cheque especial | 4.4 (deve retornar 0 linhas) |
| RN10 | Parcela vencida vira atrasada, com multa de 2%, e o empréstimo fica inadimplente | UPDATEs 5.1 e 5.2 |

## Escalabilidade

- Chaves `BIGINT` nas tabelas de maior volume (`conta`, `transacao`, cartão e empréstimo).
- Transação com origem e destino na mesma linha, sem tabela extra de lançamentos, o que reduz
  escrita e junções.
- Saldo guardado na conta (leitura direta) e recalculável a partir das transações (UPDATE 5.5).
- Índices compostos para extrato (`conta`, `dt_hora`), relatórios por categoria e cobrança de parcelas.
- Integridade referencial com `RESTRICT` para proteger o histórico financeiro.
- Em produção, `transacao` poderia ser particionada por data. O InnoDB não aceita chave
  estrangeira em tabelas particionadas, por isso o modelo entregue não usa partição.

## Alinhamento com o conteúdo da disciplina

Os scripts usam apenas o que foi visto nos slides de DDL, DML e álgebra relacional.

| Tópico | Onde |
|---|---|
| `CREATE DATABASE`, `CREATE TABLE`, `PRIMARY KEY`, `FOREIGN KEY` com `CONSTRAINT`, `NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT`, `AUTO_INCREMENT` | `01_schema.sql` |
| Ações referenciais `ON UPDATE` e `ON DELETE` (`CASCADE`, `SET NULL`, `RESTRICT`) | `01_schema.sql` |
| `INSERT`, incluindo `INSERT ... SELECT` | `02_dados.sql` e UPDATEs 5.3 e 5.4 |
| `ALTER TABLE` (ADD, MODIFY, DROP COLUMN), `RENAME`, `TRUNCATE`, `DROP TABLE` | 6.1 (tabela auxiliar `demo_meta`) |
| Seleção, projeção, `AND`/`OR`/`NOT`, `IS NULL`, `LIKE`, `IN`, `BETWEEN`, `ORDER BY`, `LIMIT` | 6.2 |
| `MIN`, `MAX`, `AVG`, `COUNT`, `SUM`, `GROUP BY`, `HAVING` | 4.2, 4.5 e 6.3 |
| União, interseção e diferença | 4.1 e 6.4 |
| Produto cartesiano (`CROSS JOIN`), auto-junção, `INNER`/`LEFT`/`RIGHT JOIN`, junção externa completa | 6.5 |
| Divisão (÷) | 6.6 |
| `UPDATE` e `DELETE` | seção 5 e 6.7 |

As consultas da seção 6 trazem, em comentário, a expressão de álgebra relacional equivalente.

## Como validar

Execute o `03_consultas.sql` e confira:

- **4.3** e **4.4** devem retornar **0 linhas**.
- Na seção 5.10, descomente os `INSERT` para comprovar que o banco rejeita chave repetida,
  valor negativo, origem igual ao destino e CPF inválido.
- Na seção 6.7, descomente os `DELETE` para comprovar o `ON DELETE RESTRICT`.
