// formatacao e montagem das tabelas
// as tabelas sao montadas com textContent (nunca innerHTML com dados), pra nao injetar html

const formatoReal = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });

function emReais(valor) {
  return formatoReal.format(Number(valor));
}

function emDataHora(texto) {
  return new Date(texto).toLocaleString("pt-BR");
}

// estado de cada tabela: carregando / erro / vazio (sem tipo = limpa)
function mostrarEstado(idElemento, tipo, mensagem) {
  const elemento = document.getElementById(idElemento);
  elemento.textContent = "";
  if (!tipo) return;

  const caixa = document.createElement("div");
  caixa.className = tipo === "erro" ? "alert alert-danger mb-0" : "text-muted";
  caixa.textContent = mensagem;
  elemento.appendChild(caixa);
}

// monta as linhas de uma tabela
// "colunas" diz, pra cada coluna, qual campo mostrar e se e moeda, numero, data ou texto
function preencherTabela(idCorpo, linhas, colunas) {
  const corpo = document.getElementById(idCorpo);
  corpo.textContent = "";

  for (const linha of linhas) {
    const tr = document.createElement("tr");
    for (const coluna of colunas) {
      const td = document.createElement("td");
      let valor = linha[coluna.campo];

      if (coluna.tipo === "moeda") {
        td.className = "valor " + (Number(valor) < 0 ? "valor-negativo" : "");
        valor = emReais(valor);
      } else if (coluna.tipo === "numero") {
        td.className = "valor";
      } else if (coluna.tipo === "data") {
        valor = emDataHora(valor);
      }

      td.textContent = valor ?? "—";
      tr.appendChild(td);
    }
    corpo.appendChild(tr);
  }
}

// busca os dados de uma rota e coloca na tabela, cuidando do "carregando" e do erro
async function carregarTabela(rota, idEstado, idCorpo, colunas) {
  mostrarEstado(idEstado, "carregando", "Carregando...");
  try {
    const linhas = await chamarApi(rota);
    preencherTabela(idCorpo, linhas, colunas);
    mostrarEstado(idEstado, linhas.length ? null : "carregando", "Nenhum registro encontrado.");
  } catch (erro) {
    document.getElementById(idCorpo).textContent = "";
    mostrarEstado(idEstado, "erro", erro.message);
  }
}

// colunas da tabela de contas (usada no painel e na transferencia)
const colunasContas = [
  { campo: "id_conta" }, { campo: "numero_conta" }, { campo: "tipo" }, { campo: "titular" },
  { campo: "status" }, { campo: "saldo", tipo: "moeda" }, { campo: "saldo_disponivel", tipo: "moeda" }
];
