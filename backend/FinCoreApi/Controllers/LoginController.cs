using System.Security.Cryptography;
using System.Text;
using FinCoreApi.Data;
using FinCoreApi.Models;
using Microsoft.AspNetCore.Mvc;
using MySqlConnector;

namespace FinCoreApi.Controllers
{
    [Route("api")]
    public class LoginController : BaseController
    {
        public LoginController(Banco banco, Sessoes sessoes) : base(banco, sessoes) { }

        [HttpPost("login")]
        [EndpointSummary("Faz login e devolve o token (rota pública)")]
        public async Task<IActionResult> Login([FromBody] LoginDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.Login) || string.IsNullOrWhiteSpace(dto.Senha))
                return Erro(400, "Informe login e senha");

            var linhas = await _banco.Consultar(
                @"SELECT u.id_usuario, u.login, u.senha_hash, u.salt, u.status, u.id_cliente, g.nome AS grupo
                  FROM usuarios u
                  INNER JOIN grupos_usuarios g ON g.id_grupo = u.id_grupo
                  WHERE u.login = @login",
                new MySqlParameter("@login", dto.Login));

            // a senha nunca fica guardada, compara o hash de (salt + senha digitada) com o hash do banco
            // mesma mensagem pra login que nao existe e senha errada (nao entrega quais logins existem)
            if (linhas.Count == 0 || (string)linhas[0]["senha_hash"]! != GerarHash((string)linhas[0]["salt"]!, dto.Senha))
                return Erro(401, "Login ou senha inválidos");

            var dados = linhas[0];
            if ((string)dados["status"]! != "ATIVO")
                return Erro(403, "Usuário bloqueado ou inativo");

            var usuario = new UsuarioLogado
            {
                IdUsuario = Convert.ToInt32(dados["id_usuario"]),
                Login = (string)dados["login"]!,
                Grupo = (string)dados["grupo"]!,
                IdCliente = dados["id_cliente"] == null ? null : Convert.ToInt64(dados["id_cliente"])
            };

            var token = _sessoes.Criar(usuario);
            return Ok(new { token, usuario.Login, usuario.Grupo, usuario.IdCliente });
        }

        [HttpPost("logout")]
        [EndpointSummary("Encerra a sessão do token enviado")]
        public IActionResult Logout()
        {
            _sessoes.Remover(Request);
            return Ok(new { mensagem = "Sessão encerrada" });
        }

        // hash da senha: sha-256 de (salt + senha) em hexadecimal minusculo
        // e a mesma conta do sha2(concat(salt, senha), 256) usado no 04_usuarios_acesso.sql
        private static string GerarHash(string salt, string senha)
        {
            var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(salt + senha));
            return Convert.ToHexString(bytes).ToLower();
        }
    }
}
