// sessao do login e chamadas pra api
// as urls sao relativas ("/api/..."), porque a propria api entrega o site em http://localhost:3000
// a sessao fica no sessionStorage: vale pra todas as paginas da aba e some quando fecha a aba

let sessao = lerSessaoGuardada();   // { token, login, grupo, idCliente } ou null

function guardarSessao(dados) {
  sessao = dados;
  try { sessionStorage.setItem("fincore-sessao", JSON.stringify(dados)); } catch (e) { /* sem storage: fica so na memoria */ }
}

function lerSessaoGuardada() {
  try { return JSON.parse(sessionStorage.getItem("fincore-sessao")); } catch (e) { return null; }
}

function apagarSessao() {
  sessao = null;
  try { sessionStorage.removeItem("fincore-sessao"); } catch (e) { /* nada a fazer */ }
}

// chama a api mandando o token; se der erro, joga uma excecao com a mensagem que a api mandou
async function chamarApi(caminho, opcoes = {}) {
  const cabecalhos = { "Content-Type": "application/json" };
  if (sessao) cabecalhos["Authorization"] = "Bearer " + sessao.token;

  // aberto com dois cliques (file://)? as urls "/api/..." so funcionam pela propria api
  if (location.protocol === "file:") {
    throw new Error("Abra o site pelo endereço http://localhost:3000 (com a API rodando), e não pelo arquivo index.html.");
  }

  let resposta;
  try {
    resposta = await fetch(caminho, { ...opcoes, headers: cabecalhos });
  } catch (e) {
    throw new Error("Não foi possível falar com a API. Ela está rodando? (cd backend/FinCoreApi e dotnet run)");
  }

  const dados = await resposta.json().catch(() => ({}));

  // token vencido (ex: a api reiniciou): volta pro login
  if (resposta.status === 401 && sessao) {
    apagarSessao();
    location.href = "index.html?expirou=1";
    throw new Error("Sessão expirada. Faça login de novo.");
  }
  if (!resposta.ok) throw new Error(dados.erro || "Erro " + resposta.status);
  return dados;
}
