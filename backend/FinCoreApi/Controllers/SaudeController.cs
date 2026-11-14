using FinCoreApi.Data;
using Microsoft.AspNetCore.Mvc;

namespace FinCoreApi.Controllers
{
    [Route("api/saude")]
    public class SaudeController : BaseController
    {
        public SaudeController(Banco banco, Sessoes sessoes) : base(banco, sessoes) { }

        // rota publica: current_user() mostra com qual usuario do mysql a api ta conectada
        [HttpGet]
        [EndpointSummary("Confirma que a API conecta no banco (rota pública)")]
        public async Task<IActionResult> Saude()
        {
            var linhas = await _banco.Consultar("SELECT CURRENT_USER() AS usuario_banco, DATABASE() AS banco, NOW() AS hora_banco");
            return Ok(new { status = "ok", banco = linhas[0] });
        }
    }
}
