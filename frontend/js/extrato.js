// pagina do extrato (extrato.html): le da view vw_extrato_conta
// a conta pode vir no endereco: extrato.html?conta=2

function carregarExtrato() {
  const idConta = document.getElementById("campo-conta-extrato").value;
  if (!idConta) return;
  return carregarTabela("/api/contas/" + idConta + "/extrato", "estado-extrato", "tabela-extrato", [
    { campo: "dt_hora", tipo: "data" }, { campo: "id_transacao" }, { campo: "tipo" },
    { campo: "descricao" }, { campo: "natureza" }, { campo: "valor", tipo: "moeda" }
  ]);
}

// escolhe a conta que abre primeiro: a do endereco, a primeira do cliente ou a 2 (ana)
async function escolherContaInicial() {
  const contaDoEndereco = new URLSearchParams(location.search).get("conta");
  if (contaDoEndereco) return contaDoEndereco;

  if (sessao.grupo === "CLIENTE") {
    const contas = await chamarApi("/api/contas").catch(() => []);
    return contas.length ? contas[0].id_conta : "";
  }
  return 2;
}

async function iniciarExtrato() {
  document.getElementById("campo-conta-extrato").value = await escolherContaInicial();
  carregarExtrato();
}

if (exigirLogin()) {
  montarMenu();
  document.getElementById("form-extrato").addEventListener("submit", evento => {
    evento.preventDefault();
    carregarExtrato();
  });
  iniciarExtrato();
}
