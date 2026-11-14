using MySqlConnector;

namespace FinCoreApi.Data
{
    // conexao com o mysql: guarda a string de conexao (usuario app_fincore) e roda os sql
    public class Banco
    {
        private readonly string _conexao;

        public Banco(string conexao)
        {
            _conexao = conexao;
        }

        // roda um sql com parametros (@nome) e devolve as linhas como lista de "coluna -> valor"
        // os parametros evitam sql injection: o valor nunca e colado dentro do texto do sql
        public async Task<List<Dictionary<string, object?>>> Consultar(string sql, params MySqlParameter[] parametros)
        {
            await using var conexao = new MySqlConnection(_conexao);
            await conexao.OpenAsync();

            await using var comando = new MySqlCommand(sql, conexao);
            comando.Parameters.AddRange(parametros);

            await using var leitor = await comando.ExecuteReaderAsync();
            var linhas = new List<Dictionary<string, object?>>();
            while (await leitor.ReadAsync())
            {
                var linha = new Dictionary<string, object?>();
                for (int i = 0; i < leitor.FieldCount; i++)
                    linha[leitor.GetName(i)] = leitor.IsDBNull(i) ? null : leitor.GetValue(i);
                linhas.Add(linha);
            }
            return linhas;
        }
    }
}
