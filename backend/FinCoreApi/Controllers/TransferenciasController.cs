using FinCoreApi.Data;
using FinCoreApi.Models;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Bson;
using MySqlConnector;

namespace FinCoreApi.Controllers
{
    [Route("api/transferencias")]
    public class TransferenciasController : BaseController
    {
        private readonly Auditoria _auditoria;

        public TransferenciasController(Banco banco, Sessoes sessoes, Auditoria auditoria) : base(banco, sessoes)
        {
            _auditoria = auditoria;
        }

        [HttpPost]
        [EndpointSummary("Transfere entre contas chamando a procedure sp_transferir (ADMIN, GERENTE, CLIENTE)")]
        public async Task<IActionResult> Transferir([FromBody] TransferenciaDto dto)
        {
            // chave de idempotencia: a mesma chave nunca gera duas transferencias
            var chave = string.IsNullOrWhiteSpace(dto.Chave) ? Guid.NewGuid().ToString() : dto.Chave;

            var negado = VerificarAcesso("ADMIN", "GERENTE", "CLIENTE");
            if (negado != null)
            {
                // logado mas sem permissao (403): fica no log quem tentou
                var quem = UsuarioAtual();
                if (quem != null)
                    await _auditoria.Registrar("TRANSFERENCIA_NEGADA", quem.Login,
                        Detalhes(dto, chave).Add("motivo", "o grupo " + quem.Grupo + " não pode transferir"));
                return negado;
            }

            var usuario = UsuarioAtual()!;
            if (usuario.Grupo == "CLIENTE" && !await ClienteEhTitular(usuario, dto.IdContaOrigem))
            {
                await _auditoria.Registrar("TRANSFERENCIA_NEGADA", usuario.Login,
                    Detalhes(dto, chave).Add("motivo", "conta de origem não é do cliente"));
                return Erro(403, "Você só pode transferir de uma conta sua");
            }

            try
            {
                // toda a regra (validacao, commit e rollback) fica na procedure sp_transferir
                var resultado = await _banco.Consultar("CALL sp_transferir(@origem, @destino, @valor, @chave)",
                    new MySqlParameter("@origem", dto.IdContaOrigem),
                    new MySqlParameter("@destino", dto.IdContaDestino),
                    new MySqlParameter("@valor", dto.Valor),
                    new MySqlParameter("@chave", chave));

                await _auditoria.Registrar("TRANSFERENCIA_OK", usuario.Login,
                    Detalhes(dto, chave).Add("id_transacao", Convert.ToInt64(resultado[0]["id_transacao"])));

                return Ok(new { mensagem = "Transferência realizada (COMMIT)", chave, resultado = resultado[0] });
            }
            catch (MySqlException erro) when (erro.Number == 1644)
            {
                // 1644 = erro lancado pela procedure com signal (saldo insuficiente, conta que nao existe,
                // chave repetida...), a procedure ja fez o rollback
                // o rollback apaga tudo do mysql, mas a tentativa fica guardada no mongodb
                await _auditoria.Registrar("TRANSFERENCIA_ERRO", usuario.Login, Detalhes(dto, chave).Add("erro", erro.Message));
                return Erro(400, erro.Message + ". Nada foi alterado (ROLLBACK).");
            }
            catch (MySqlException erro) when (erro.Number == 1062)
            {
                // 1062 = chave unique repetida (duas requisicoes iguais ao mesmo tempo)
                await _auditoria.Registrar("TRANSFERENCIA_ERRO", usuario.Login, Detalhes(dto, chave).Add("erro", erro.Message));
                return Erro(409, "Chave repetida: esta transferência já foi feita. Nada foi alterado (ROLLBACK).");
            }
        }

        // dados da transferencia que vao pro log de auditoria
        private static BsonDocument Detalhes(TransferenciaDto dto, string chave)
        {
            return new BsonDocument
            {
                { "conta_origem", dto.IdContaOrigem },
                { "conta_destino", dto.IdContaDestino },
                { "valor", dto.Valor },
                { "chave", chave }
            };
        }
    }
}
