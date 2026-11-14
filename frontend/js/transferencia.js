// pagina da transferencia (transferencia.html): chama a procedure sp_transferir
// mostra o saldo antes e depois pra ver se houve commit ou rollback

let ultimaTransferencia = null;

function carregarContas() {
  return carregarTabela("/api/contas", "estado-contas", "tabela-contas", colunasContas);
}

function novaChave() {
  document.getElementById("campo-chave").value = "web-" + Date.now();
}

function mostrarResultado(tipo, mensagem) {
  const area = document.getElementById("resultado-transferencia");
  area.textContent = "";
  const caixa = document.createElement("div");
  caixa.className = "alert mb-0 " + (tipo === "sucesso" ? "alert-success" : "alert-danger");
  caixa.textContent = mensagem;
  area.appendChild(caixa);
}

// mostra lado a lado o saldo das duas contas antes e depois da tentativa
function mostrarComparacao(contasAntes, contasDepois, idsContas) {
  const corpo = document.getElementById("corpo-comparacao");
  corpo.textContent = "";
  for (const id of idsContas) {
    const antes = contasAntes.find(c => c.id_conta === id);
    const depois = contasDepois.find(c => c.id_conta === id);
    const tr = document.createElement("tr");
    const celulas = [
      String(id),
      antes ? antes.titular : "(conta de outro cliente)",
      antes ? emReais(antes.saldo) : "—",
      depois ? emReais(depois.saldo) : "—"
    ];
    celulas.forEach((texto, i) => {
      const td = document.createElement("td");
      if (i >= 2) td.className = "valor";
      td.textContent = texto;
      tr.appendChild(td);
    });
    corpo.appendChild(tr);
  }
  document.getElementById("tabela-comparacao").classList.remove("d-none");
}

async function transferir(pedido) {
  mostrarResultado("sucesso", "Enviando...");
  const contasAntes = await chamarApi("/api/contas").catch(() => []);

  try {
    const resposta = await chamarApi("/api/transferencias", { method: "POST", body: JSON.stringify(pedido) });
    mostrarResultado("sucesso", resposta.mensagem + ": transação nº " + resposta.resultado.id_transacao +
      ". Novo saldo da origem: " + emReais(resposta.resultado.saldo_origem) + ".");
    ultimaTransferencia = pedido;
    novaChave();   // a proxima transferencia usa outra chave
  } catch (erro) {
    mostrarResultado("erro", erro.message);
  }

  const contasDepois = await chamarApi("/api/contas").catch(() => []);
  mostrarComparacao(contasAntes, contasDepois, [pedido.idContaOrigem, pedido.idContaDestino]);

  // link pro extrato da conta de origem, pra mostrar a transacao la
  const link = document.getElementById("link-extrato");
  link.href = "extrato.html?conta=" + pedido.idContaOrigem;
  link.classList.remove("d-none");

  carregarContas();
}

function lerFormulario() {
  return {
    idContaOrigem: Number(document.getElementById("campo-origem").value),
    idContaDestino: Number(document.getElementById("campo-destino").value),
    valor: Number(document.getElementById("campo-valor").value),
    chave: document.getElementById("campo-chave").value
  };
}

function preencherExemplo(origem, destino, valor) {
  document.getElementById("campo-origem").value = origem;
  document.getElementById("campo-destino").value = destino;
  document.getElementById("campo-valor").value = valor;
  novaChave();
  transferir(lerFormulario());
}

// cliente: ja deixa a primeira conta dele como origem
async function sugerirOrigem() {
  if (sessao.grupo !== "CLIENTE") return;
  const contas = await chamarApi("/api/contas").catch(() => []);
  if (contas.length) document.getElementById("campo-origem").value = contas[0].id_conta;
}

if (exigirLogin("ADMIN GERENTE CLIENTE")) {
  montarMenu();
  novaChave();
  sugerirOrigem();
  carregarContas();

  document.getElementById("form-transferencia").addEventListener("submit", evento => {
    evento.preventDefault();
    transferir(lerFormulario());
  });

  // exemplos pra apresentacao: conta 2 (ana) -> conta 4 (bruno)
  document.getElementById("exemplo-commit").addEventListener("click", () => preencherExemplo(2, 4, 50));
  document.getElementById("exemplo-rollback").addEventListener("click", () => preencherExemplo(2, 4, 1000000));
  document.getElementById("exemplo-repetir").addEventListener("click", () => {
    if (!ultimaTransferencia) {
      mostrarResultado("erro", "Faça uma transferência que dê certo primeiro.");
      return;
    }
    transferir(ultimaTransferencia);   // mesma chave: a procedure recusa
  });
}
