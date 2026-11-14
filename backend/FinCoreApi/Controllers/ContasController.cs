using FinCoreApi.Data;
using Microsoft.AspNetCore.Mvc;
using MySqlConnector;

namespace FinCoreApi.Controllers
{
    [Route("api/contas")]
    public class ContasController : BaseController
    {
        public ContasController(Banco banco, Sessoes sessoes) : base(banco, sessoes) { }

        // le da view vw_contas_cliente
        [HttpGet]
        [EndpointSummary("Contas com saldo disponível, da VIEW vw_contas_cliente (cliente vê só as suas)")]
        public async Task<IActionResult> Contas()
        {
            var negado = VerificarAcesso("ADMIN", "GERENTE", "ATENDENTE", "CLIENTE");
            if (negado != null) return negado;

            var usuario = UsuarioAtual()!;
            if (usuario.Grupo == "CLIENTE")   // cliente so ve as contas em que e titular ou cotitular
                return Ok(await _banco.Consultar(
                    @"SELECT * FROM vw_contas_cliente
                      WHERE id_conta IN (SELECT id_conta FROM titularidade WHERE id_cliente = @cliente)
                      ORDER BY id_conta",
                    new MySqlParameter("@cliente", usuario.IdCliente)));

            return Ok(await _banco.Consultar("SELECT * FROM vw_contas_cliente ORDER BY id_conta"));
        }

        // le da view vw_extrato_conta
        [HttpGet("{idConta}/extrato")]
        [EndpointSummary("Extrato de uma conta, da VIEW vw_extrato_conta")]
        public async Task<IActionResult> Extrato(long idConta)
        {
            var negado = VerificarAcesso("ADMIN", "GERENTE", "ATENDENTE", "CLIENTE");
            if (negado != null) return negado;

            var usuario = UsuarioAtual()!;
            if (usuario.Grupo == "CLIENTE" && !await ClienteEhTitular(usuario, idConta))
                return Erro(403, "Você só pode ver o extrato das suas contas");

            return Ok(await _banco.Consultar(
                "SELECT * FROM vw_extrato_conta WHERE id_conta = @conta ORDER BY dt_hora DESC, id_transacao DESC",
                new MySqlParameter("@conta", idConta)));
        }
    }
}
