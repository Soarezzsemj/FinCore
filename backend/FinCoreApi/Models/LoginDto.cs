namespace FinCoreApi.Models
{
    // dados que chegam no post /api/login
    public class LoginDto
    {
        public string? Login { get; set; }
        public string? Senha { get; set; }
    }
}
