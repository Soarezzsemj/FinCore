// pagina do painel (painel.html): saldos (view), clientes (tabela) e contas (view)

function carregarSaldos() {
  return carregarTabela("/api/saldos", "estado-saldos", "tabela-saldos", [
    { campo: "nome_razao" }, { campo: "tipo" },
    { campo: "qtd_contas", tipo: "numero" }, { campo: "saldo_total", tipo: "moeda" }
  ]);
}

function carregarClientes() {
  return carregarTabela("/api/clientes", "estado-clientes", "tabela-clientes", [
    { campo: "id_cliente" }, { campo: "nome_razao" }, { campo: "tipo" }, { campo: "documento" },
    { campo: "email" }, { campo: "end_cidade" }, { campo: "status" }
  ]);
}

function carregarContas() {
  return carregarTabela("/api/contas", "estado-contas", "tabela-contas", colunasContas);
}

// recarrega so as secoes que o grupo logado pode ver
function atualizarPainel() {
  if (podeVer("ADMIN GERENTE ATENDENTE")) {
    carregarSaldos();
    carregarClientes();
  }
  carregarContas();
}

if (exigirLogin()) {
  montarMenu();
  document.getElementById("botao-atualizar").addEventListener("click", atualizarPainel);
  atualizarPainel();
}
