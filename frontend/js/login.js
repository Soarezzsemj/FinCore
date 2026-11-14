// pagina de login (index.html)

// ja logado nessa aba? vai direto pro painel
if (sessao) location.href = "painel.html";

// veio do aviso de sessao vencida
if (new URLSearchParams(location.search).has("expirou")) {
  mostrarErroLogin("Sessão expirada. Faça login de novo.");
}

function mostrarErroLogin(mensagem) {
  const caixa = document.getElementById("erro-login");
  caixa.textContent = mensagem;
  caixa.classList.remove("d-none");
}

async function entrar(evento) {
  evento.preventDefault();
  document.getElementById("erro-login").classList.add("d-none");

  try {
    const dados = await chamarApi("/api/login", {
      method: "POST",
      body: JSON.stringify({
        login: document.getElementById("campo-login").value,
        senha: document.getElementById("campo-senha").value
      })
    });
    guardarSessao(dados);
    location.href = "painel.html";
  } catch (erro) {
    mostrarErroLogin(erro.message);
  }
}

document.getElementById("form-login").addEventListener("submit", entrar);
