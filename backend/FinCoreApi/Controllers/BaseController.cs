using FinCoreApi.Data;
using FinCoreApi.Models;
using Microsoft.AspNetCore.Mvc;
using MySqlConnector;

namespace FinCoreApi.Controllers
{
    // base dos controllers: guarda o banco e as sessoes e tem as funcoes que todos usam
    [ApiController]
    public abstract class BaseController : ControllerBase
    {
        protected readonly Banco _banco;
        protected readonly Sessoes _sessoes;

        protected BaseController(Banco banco, Sessoes sessoes)
        {
            _banco = banco;
            _sessoes = sessoes;
        }

        // usuario logado nessa requisicao (ou null)
        protected UsuarioLogado? UsuarioAtual()
        {
            return _sessoes.Buscar(Request);
        }

        // confere login e grupo: devolve 401 (nao logado), 403 (grupo sem permissao) ou null (pode seguir)
        protected IActionResult? VerificarAcesso(params string[] gruposPermitidos)
        {
            var usuario = UsuarioAtual();
            if (usuario == null)
                return Erro(401, "Faça login para usar esta rota");
            if (!gruposPermitidos.Contains(usuario.Grupo))
                return Erro(403, "O grupo " + usuario.Grupo + " não tem acesso a esta rota");
            return null;
        }

        // o cliente logado e titular (ou cotitular) dessa conta?
        protected async Task<bool> ClienteEhTitular(UsuarioLogado usuario, long idConta)
        {
            var linhas = await _banco.Consultar(
                "SELECT 1 FROM titularidade WHERE id_conta = @conta AND id_cliente = @cliente",
                new MySqlParameter("@conta", idConta),
                new MySqlParameter("@cliente", usuario.IdCliente));
            return linhas.Count > 0;
        }

        // resposta de erro padrao: { "erro": "mensagem" }
        protected IActionResult Erro(int status, string mensagem)
        {
            return StatusCode(status, new { erro = mensagem });
        }
    }
}
