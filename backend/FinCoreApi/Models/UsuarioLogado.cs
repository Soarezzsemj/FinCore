namespace FinCoreApi.Models
{
    // usuario que fez login, guardado na sessao junto com o token
    public class UsuarioLogado
    {
        public int IdUsuario { get; set; }
        public string Login { get; set; } = string.Empty;
        public string Grupo { get; set; } = string.Empty;   // ADMIN, GERENTE, ATENDENTE ou CLIENTE

        // so tem valor pros usuarios do grupo CLIENTE
        public long? IdCliente { get; set; }
    }
}
