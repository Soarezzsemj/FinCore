using System.Collections.Concurrent;
using System.Security.Cryptography;
using FinCoreApi.Models;

namespace FinCoreApi.Data
{
    // sessoes abertas: token -> usuario logado (ficam na memoria, somem se a api reiniciar)
    public class Sessoes
    {
        private readonly ConcurrentDictionary<string, UsuarioLogado> _abertas = new();

        // cria um token aleatorio (impossivel de adivinhar) pro usuario que fez login
        public string Criar(UsuarioLogado usuario)
        {
            var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
            _abertas[token] = usuario;
            return token;
        }

        public void Remover(HttpRequest requisicao)
        {
            _abertas.TryRemove(LerToken(requisicao), out _);
        }

        // devolve o usuario dono do token, ou null se nao estiver logado
        public UsuarioLogado? Buscar(HttpRequest requisicao)
        {
            return _abertas.TryGetValue(LerToken(requisicao), out var usuario) ? usuario : null;
        }

        // le o token do cabecalho "authorization: bearer <token>"
        private static string LerToken(HttpRequest requisicao)
        {
            var cabecalho = requisicao.Headers.Authorization.ToString();
            return cabecalho.StartsWith("Bearer ") ? cabecalho.Substring(7).Trim() : "";
        }
    }
}
