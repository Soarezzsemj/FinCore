using FinCoreApi.Data;
using FinCoreApi.Models;
using Microsoft.AspNetCore.Mvc;
using MySqlConnector;

namespace FinCoreApi.Controllers
{
    [Route("api/transferencias")]
    public class TransferenciasController : BaseController
    {
        public TransferenciasController(Banco banco, Sessoes sessoes) : base(banco, sessoes) { }

        [HttpPost]
        [EndpointSummary("Transfere entre contas chamando a procedure sp_transferir (ADMIN, GERENTE, CLIENTE)")]
        public async Task<IActionResult> Transferir([FromBody] TransferenciaDto dto)
        {
            var negado = VerificarAcesso("ADMIN", "GERENTE", "CLIENTE");
            if (negado != null) return negado;

            var usuario = UsuarioAtual()!;
            if (usuario.Grupo == "CLIENTE" && !await ClienteEhTitular(usuario, dto.IdContaOrigem))
                return Erro(403, "Você só pode transferir de uma conta sua");

            // chave de idempotencia: a mesma chave nunca gera duas transferencias
            var chave = string.IsNullOrWhiteSpace(dto.Chave) ? Guid.NewGuid().ToString() : dto.Chave;

            try
            {
                // toda a regra (validacao, commit e rollback) fica na procedure sp_transferir
                var resultado = await _banco.Consultar("CALL sp_transferir(@origem, @destino, @valor, @chave)",
                    new MySqlParameter("@origem", dto.IdContaOrigem),
                    new MySqlParameter("@destino", dto.IdContaDestino),
                    new MySqlParameter("@valor", dto.Valor),
                    new MySqlParameter("@chave", chave));

                return Ok(new { mensagem = "Transferência realizada (COMMIT)", chave, resultado = resultado[0] });
            }
            catch (MySqlException erro) when (erro.Number == 1644)
            {
                // 1644 = erro lancado pela procedure com signal (saldo insuficiente, conta que nao existe,
                // chave repetida...), a procedure ja fez o rollback
                return Erro(400, erro.Message + ". Nada foi alterado (ROLLBACK).");
            }
            catch (MySqlException erro) when (erro.Number == 1062)
            {
                // 1062 = chave unique repetida (duas requisicoes iguais ao mesmo tempo)
                return Erro(409, "Chave repetida: esta transferência já foi feita. Nada foi alterado (ROLLBACK).");
            }
        }
    }
}
