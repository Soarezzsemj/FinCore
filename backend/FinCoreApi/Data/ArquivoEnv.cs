namespace FinCoreApi.Data
{
    // le o arquivo .env da raiz do projeto, onde ficam os dados de conexao com o banco
    public static class ArquivoEnv
    {
        // sobe as pastas a partir do programa ate achar o docker-compose.yaml (raiz do projeto)
        public static string AcharPastaRaiz()
        {
            var pasta = new DirectoryInfo(AppContext.BaseDirectory);
            while (pasta != null && !File.Exists(Path.Combine(pasta.FullName, "docker-compose.yaml")))
                pasta = pasta.Parent;
            return pasta?.FullName ?? Directory.GetCurrentDirectory();
        }

        // le as linhas nome=valor e copia pras variaveis de ambiente
        // variavel que ja existe no sistema tem prioridade sobre o .env
        public static void Carregar(string caminho)
        {
            if (!File.Exists(caminho)) return;
            foreach (var linha in File.ReadAllLines(caminho))
            {
                var texto = linha.Trim();
                if (texto == "" || texto.StartsWith('#') || !texto.Contains('=')) continue;

                var partes = texto.Split('=', 2);
                var nome = partes[0].Trim();
                if (Environment.GetEnvironmentVariable(nome) == null)
                    Environment.SetEnvironmentVariable(nome, partes[1].Trim());
            }
        }

        // le uma variavel de ambiente, ou devolve o valor padrao se ela nao existir
        public static string Ler(string nome, string valorPadrao)
        {
            return Environment.GetEnvironmentVariable(nome) ?? valorPadrao;
        }
    }
}
