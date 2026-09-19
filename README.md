# FinCore — Banco de Dados para Banco Digital e Gestão Financeira

Trabalho da disciplina **Laboratório de Banco de Dados (GPE17N40158)**.
**Tema:** Finanças · **SGBD:** MySQL 8.0+

## Equipe

| Nome | Responsabilidade principal |
|------|----------------------------|
| _KAUAN PIERRE TEIXEIRA DE LIMA_ | _Modelagem conceitual_ |
| _HEITOR XAVIER CARVALHO_ | _Modelagem lógica e física_ |
| _CAUAN CARVALHO DOS SANTOS_ | _Scripts SQL (DDL e regras)_ |
| _CARLOS EDUARDO SOARES SOUZA SANTOS_ | _Dados, consultas e documentação_ |
| _DANIEL GAMA MACHADO_ | _Diagramas e documento em PDF_ |

Professor(a): _JEFFERSON SALOMAO RODRIGUES_ · Instituição: _Universidade Católica de Brasília_ · Semestre: _2026/2_

## Sobre o projeto

O FinCore modela um banco digital: clientes (pessoa física e jurídica), contas correntes e
poupança, movimentações, cartão de crédito com faturas, empréstimos parcelados, investimentos
e orçamento pessoal. O núcleo é um **livro-razão (ledger) de partida dobrada**: toda transação
gera um débito e um crédito de mesmo valor, e o saldo pode ser conferido pela soma dos lançamentos.

- **Contexto e justificativa:** _(resumo; o texto completo está no PDF em `docs/`)_
- **Escopo:** cadastro de clientes e contas, movimentações, cartões, empréstimos, investimentos e orçamento.
- **Fora do escopo:** emissão fiscal, integração com o Banco Central e antifraude.

## Estrutura do repositório

```
fincore-banco-de-dados/
├── README.md
├── sql/
│   ├── 01_schema.sql       # banco, tabelas, triggers, procedures, views
│   ├── 02_dados.sql        # população (inserts e movimentações)
│   └── 03_consultas.sql    # SELECTs, UPDATEs e revisão do conteúdo (seção 6)
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

No MySQL Workbench, abra e execute os três arquivos na ordem (raio ⚡). Execute o
`02` e o `03` na mesma sessão, pois uma consulta usa uma variável de sessão.

## Modelagem

Diagramas em `docs/diagramas/`:

- `der-conceitual.png`
- `modelo-logico.png`
- `modelo-fisico.png`

| Requisito do trabalho | Onde aparece |
|---|---|
| Entidade fraca | `parcela_emprestimo` (PK composta com `emprestimo`) |
| Entidades associativas | `titularidade`, `lancamento`, `aplicacao` |
| Generalização/especialização | `cliente` → `cliente_pf`/`cliente_pj`; `conta` → `conta_corrente`/`conta_poupanca` |
| Relacionamentos ternários | `aplicacao` (conta, produto, assessor) e `orcamento` (cliente, categoria, competência) |
| Relacionamento recursivo | `categoria` (pai/filha) e `transacao` (estorno) |
| Atributo composto | endereço em `cliente` |
| Atributo multivalorado | `telefone_cliente` |

## Regras de negócio implementadas no banco

| Código | Regra |
|---|---|
| RN01 | Toda transação tem débito e crédito de mesmo valor (partida dobrada) |
| RN02 | Lançamentos são imutáveis; correção por estorno |
| RN03 | Saldo não ultrapassa o limite do cheque especial |
| RN04 | Somente contas ativas movimentam valores |
| RN05 | Transações idempotentes (`chave_idempotencia`) |
| RN07 | CPF com 11 dígitos para PF e CNPJ com 14 para PJ |
| RN08 | Parcelas do empréstimo geradas pela Tabela Price |
| RN09 | Mudança de status da conta gera auditoria |
| RN10 | Saldo da conta é igual à soma dos lançamentos |

## Escalabilidade

Chaves `BIGINT`, ledger append-only, saldo desnormalizado com lock otimista, índices compostos,
locks em ordem crescente (evita deadlock) e estratégia de particionamento por data
(descrita ao final do `01_schema.sql`).

## Alinhamento com o conteúdo da disciplina

A seção 6 do `03_consultas.sql` reúne um exemplo de cada tópico visto em aula, com a expressão de
álgebra relacional equivalente em comentário:

| Tópico | Onde |
|---|---|
| DDL: `ALTER TABLE` (ADD, MODIFY, DROP COLUMN), `RENAME`, `TRUNCATE`, `DROP TABLE` | 6.1 (tabela auxiliar `demo_meta`) |
| Seleção, projeção, `AND`/`OR`/`NOT`, `IS NULL`, `LIKE`, `IN`, `BETWEEN`, `ORDER BY`, `LIMIT` | 6.2 |
| `MIN`, `MAX`, `AVG`, `COUNT`, `SUM`, `GROUP BY`, `HAVING` | 6.3 |
| União, interseção e diferença | 6.4 |
| Produto cartesiano (`CROSS JOIN`), auto-junção, `INNER`/`LEFT`/`RIGHT JOIN`, junção externa completa | 6.5 |
| Divisão (÷) | 6.6 |
| `DELETE` e ações referenciais (`ON UPDATE CASCADE`, `ON DELETE SET NULL`/`RESTRICT`) | 6.7 |

Todas as chaves estrangeiras declaram `ON UPDATE` e `ON DELETE` de forma explícita:
`CASCADE` nas tabelas dependentes (especializações, telefones e parcelas), `SET NULL` em
relacionamentos opcionais (gerente, categoria) e `RESTRICT` nos demais, o que impede apagar dados
financeiros referenciados.

## Como validar

Execute no `03_consultas.sql`:

- **4.3** e **4.4** devem retornar **0 linhas** (consistência do ledger).
- Descomente as instruções finais da seção 5 para comprovar que `UPDATE`/`DELETE` em `lancamento` são bloqueados.
- Descomente as instruções finais da seção 6.7 para comprovar o `ON DELETE RESTRICT`.
