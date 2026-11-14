# Evidências: a aplicação não usa root

Comandos para provar, na frente do professor, que a API conecta com um usuário de privilégios
mínimos. Rode com o banco (`docker compose up -d`) e a API (`dotnet run`) no ar.

## 1. Com qual usuário a API está conectada

A rota pública `/api/saude` executa `SELECT CURRENT_USER()` **pela conexão da própria API**:

```bash
curl http://localhost:3000/api/saude
```

Resultado esperado:

```json
{"status":"ok","banco":{"usuario_banco":"app_fincore@%","banco":"fincore","hora_banco":"..."}}
```

Também dá para chamar pelo Scalar (http://localhost:3000/scalar → `GET /api/saude` → *Test Request*).

## 2. A configuração não tem root

```bash
grep DB_USER .env            # DB_USER=app_fincore
```

O `Program.cs` se recusa a iniciar se `DB_USER` for `root`:

```csharp
if (usuarioBanco == "root")
    throw new Exception("A API não pode conectar como root. Use o usuário app_fincore.");
```

## 3. O que o app_fincore pode fazer (SHOW GRANTS)

No Workbench (como root) ou pelo terminal:

```bash
docker exec -it fincore-mysql mysql -uroot -p -e "SHOW GRANTS FOR 'app_fincore'@'%';"
```

```sql
SHOW GRANTS FOR 'app_fincore'@'%';
SHOW GRANTS FOR 'analista_fincore'@'%';
SHOW GRANTS FOR 'dba_fincore'@'%';
```

O esperado para o `app_fincore`: `USAGE ON *.*` (nenhum privilégio global), `SELECT` em tabelas
e views específicas, `INSERT`/`UPDATE` só em `usuarios` e nos dados do cliente, e
`EXECUTE ON PROCEDURE fincore.sp_transferir`. Nenhum `DELETE`, `DROP`, `CREATE` ou `ALL PRIVILEGES`.

## 4. Testes que precisam FALHAR com o app_fincore

Conecte como o usuário da API (a senha é a `DB_PASSWORD` do `.env`):

```bash
docker exec -it fincore-mysql mysql -uapp_fincore -p fincore
```

```sql
SELECT CURRENT_USER();                        -- app_fincore@%

DROP TABLE transacao;                         -- ERROR 1142: DROP command denied
DELETE FROM usuarios WHERE id_usuario = 5;    -- ERROR 1142: DELETE command denied
UPDATE conta SET saldo = 1000000 WHERE id_conta = 2;   -- ERROR 1142: UPDATE command denied
INSERT INTO transacao (id_transacao, id_conta_origem, id_conta_destino, tipo, valor, chave_idempotencia)
VALUES (999, 2, 4, 'PIX', 1, 'x');            -- ERROR 1142: INSERT command denied
SELECT * FROM funcionario;                    -- ERROR 1142: SELECT command denied
CALL sp_pagar_parcela(1, 3);                  -- ERROR 1370: execute command denied
SELECT user FROM mysql.user;                  -- ERROR 1142: SELECT command denied
```

E o que precisa **funcionar**:

```sql
SELECT * FROM vw_saldo_cliente;               -- lê a view
CALL sp_transferir(2, 4, 10.00, 'evidencia-001');   -- movimenta só pela procedure
```

## 5. Senhas fora do Git

```bash
git check-ignore -v .env      # .gitignore:2:.env   .env
git ls-files | grep -i env    # só aparece .env.example
```

No `04_usuarios_acesso.sql` as senhas são marcas (`__SENHA_APP__`...), trocadas pelas do `.env`
na hora de rodar (`04_usuarios_acesso.sh`).

## 6. Senhas dos usuários da aplicação em hash

```sql
SELECT login, senha_hash, salt FROM usuarios;   -- nenhuma senha em texto puro
```
