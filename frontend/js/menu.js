// barra do topo das paginas internas: usuario logado, links por grupo e botao sair

// o grupo logado ta na lista? (lista = texto tipo "ADMIN GERENTE")
function podeVer(listaDeGrupos) {
  return sessao && listaDeGrupos.split(" ").includes(sessao.grupo);
}

// sem login volta pro login; grupo sem permissao volta pro painel
// (isso e so visual: quem garante a regra e a api, que devolve 401/403)
function exigirLogin(gruposDaPagina) {
  if (!sessao) {
    location.href = "index.html";
    return false;
  }
  if (gruposDaPagina && !podeVer(gruposDaPagina)) {
    location.href = "painel.html";
    return false;
  }
  return true;
}

// mostra ou esconde tudo que tem data-grupos (links do menu e secoes da pagina)
function aplicarGrupos() {
  for (const elemento of document.querySelectorAll("[data-grupos]")) {
    elemento.classList.toggle("d-none", !podeVer(elemento.dataset.grupos));
  }
}

function sair() {
  if (sessao) chamarApi("/api/logout", { method: "POST" }).catch(() => {});
  apagarSessao();
  location.href = "index.html";
}

function montarMenu() {
  document.getElementById("usuario-logado").textContent = sessao.login;
  document.getElementById("grupo-logado").textContent = sessao.grupo;
  document.getElementById("botao-sair").addEventListener("click", sair);
  aplicarGrupos();
}
