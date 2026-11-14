set -e

sed -e "s|__SENHA_APP__|${DB_PASSWORD}|g" \
    -e "s|__SENHA_ANALISTA__|${DB_ANALISTA_PASSWORD}|g" \
    -e "s|__SENHA_DBA__|${DB_DBA_PASSWORD}|g" \
    /fincore-sql/04_usuarios_acesso.sql \
  | mysql -uroot -p"${MYSQL_ROOT_PASSWORD}"
