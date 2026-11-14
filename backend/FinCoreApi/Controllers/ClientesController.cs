using FinCoreApi.Data;
using Microsoft.AspNetCore.Mvc;

namespace FinCoreApi.Controllers
{
    [Route("api")]
    public class ClientesController : BaseController
    {
        public ClientesController(Banco banco, Sessoes sessoes) : base(banco, sessoes) { }

        // le da tabela cliente
        [HttpGet("clientes")]
        [EndpointSummary("Lista de clientes, lida da TABELA cliente (ADMIN, GERENTE, ATENDENTE)")]
        public async Task<IActionResult> Clientes()
        {
            var negado = VerificarAcesso("ADMIN", "GERENTE", "ATENDENTE");
            if (negado != null) return negado;

            return Ok(await _banco.Consultar(
                @"SELECT id_cliente, tipo, nome_razao, documento, email, status, end_cidade, end_uf
                  FROM cliente ORDER BY nome_razao"));
        }

        // le da view vw_saldo_cliente
        [HttpGet("saldos")]
        [EndpointSummary("Saldo por cliente, lido da VIEW vw_saldo_cliente (ADMIN, GERENTE, ATENDENTE)")]
        public async Task<IActionResult> Saldos()
        {
            var negado = VerificarAcesso("ADMIN", "GERENTE", "ATENDENTE");
            if (negado != null) return negado;

            return Ok(await _banco.Consultar("SELECT * FROM vw_saldo_cliente ORDER BY nome_razao"));
        }
    }
}
