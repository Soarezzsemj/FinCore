using FinCoreApi.Data;
using Microsoft.AspNetCore.Mvc;

namespace FinCoreApi.Controllers
{
    [Route("api/auditoria")]
    public class AuditoriaController : BaseController
    {
        private readonly Auditoria _auditoria;

        public AuditoriaController(Banco banco, Sessoes sessoes, Auditoria auditoria) : base(banco, sessoes)
        {
            _auditoria = auditoria;
        }

        // le da colecao eventos do mongodb (nao do mysql)
        [HttpGet]
        [EndpointSummary("Últimos eventos de auditoria, lidos do MongoDB, coleção eventos (só ADMIN)")]
        public async Task<IActionResult> Eventos(int quantidade = 20)
        {
            var negado = VerificarAcesso("ADMIN");
            if (negado != null) return negado;

            quantidade = Math.Clamp(quantidade, 1, 100);   // no maximo 100 por vez
            try
            {
                return Ok(await _auditoria.UltimosEventos(quantidade));
            }
            catch (Exception)
            {
                return Erro(503, "MongoDB indisponível: não foi possível ler a auditoria");
            }
        }
    }
}
