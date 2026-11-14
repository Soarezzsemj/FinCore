namespace FinCoreApi.Models
{
    // dados que chegam no post /api/transferencias
    public class TransferenciaDto
    {
        public long IdContaOrigem { get; set; }
        public long IdContaDestino { get; set; }
        public decimal Valor { get; set; }

        // chave de idempotencia: se nao vier, a api gera uma
        public string? Chave { get; set; }
    }
}
