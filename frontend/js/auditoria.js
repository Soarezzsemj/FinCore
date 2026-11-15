// pagina da auditoria (auditoria.html): le os eventos gravados no mongodb (so ADMIN)

// eventos de erro ficam em destaque (linha vermelha clara)
function ehEventoDeErro(tipo) {
  return tipo.endsWith("_ERRO") || tipo.endsWith("_FALHA") || tipo.endsWith("_NEGADA");
}

// detalhes viram texto do tipo "conta_origem: 2 · valor: 50"
function detalhesEmTexto(detalhes) {
  return Object.entries(detalhes || {}).map(([nome, valor]) => nome + ": " + valor).join(" · ");
}

// monta a tabela com textContent (nunca innerHTML com dados)
function preencherAuditoria(eventos) {
  const corpo = document.getElementById("tabela-auditoria");
  corpo.textContent = "";

  for (const evento of eventos) {
    const tr = document.createElement("tr");
    if (ehEventoDeErro(evento.tipo)) tr.className = "table-danger";

    const celulas = [emDataHora(evento.data), evento.tipo, evento.usuario, detalhesEmTexto(evento.detalhes)];
    for (const texto of celulas) {
      const td = document.createElement("td");
      td.textContent = texto;
      tr.appendChild(td);
    }
    corpo.appendChild(tr);
  }
}

async function carregarAuditoria() {
  mostrarEstado("estado-auditoria", "carregando", "Carregando...");
  try {
    const eventos = await chamarApi("/api/auditoria?quantidade=50");
    preencherAuditoria(eventos);
    mostrarEstado("estado-auditoria", eventos.length ? null : "carregando", "Nenhum evento registrado.");
  } catch (erro) {
    document.getElementById("tabela-auditoria").textContent = "";
    mostrarEstado("estado-auditoria", "erro", erro.message);
  }
}

if (exigirLogin("ADMIN")) {
  montarMenu();
  document.getElementById("botao-atualizar").addEventListener("click", carregarAuditoria);
  carregarAuditoria();
}
