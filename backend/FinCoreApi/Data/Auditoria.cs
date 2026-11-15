using MongoDB.Bson;
using MongoDB.Driver;

namespace FinCoreApi.Data
{
    // log de auditoria no mongodb (nosql): login e tentativas de transferencia
    // por que mongodb e nao uma tabela no mysql:
    // - o log so recebe insercao, cresce sem parar e cada evento tem campos diferentes
    //   (no mysql viraria uma tabela cheia de colunas nulas)
    // - nao pesa no banco transacional
    // - principal: quando a sp_transferir faz ROLLBACK, tudo que foi gravado no mysql na mesma
    //   transacao some; o mongodb guarda a evidencia da tentativa que foi desfeita
    // o dinheiro (saldos e transacoes) continua so no mysql, que tem ACID, chave estrangeira e ROLLBACK
    public class Auditoria
    {
        private readonly IMongoCollection<BsonDocument> _eventos;

        public Auditoria(string url)
        {
            // tempo curto: se o mongo estiver fora do ar, a api desiste em 2 segundos em vez de travar
            var config = MongoClientSettings.FromConnectionString(url);
            config.ServerSelectionTimeout = TimeSpan.FromSeconds(2);
            config.ConnectTimeout = TimeSpan.FromSeconds(2);

            _eventos = new MongoClient(config).GetDatabase("fincore_auditoria").GetCollection<BsonDocument>("eventos");

            // indice em data (decrescente): a tela sempre pede "os ultimos eventos",
            // assim o mongo nao precisa ler e ordenar a colecao inteira
            try
            {
                _eventos.Indexes.CreateOne(new CreateIndexModel<BsonDocument>(Builders<BsonDocument>.IndexKeys.Descending("data")));
            }
            catch (Exception)
            {
                // mongo fora do ar na hora de subir a api: segue sem o indice
            }
        }

        // grava um evento; se o mongo falhar, ignora (a auditoria nunca derruba a operacao)
        // nunca passar senha, hash, salt ou token nos detalhes
        public async Task Registrar(string tipo, string usuario, BsonDocument detalhes)
        {
            try
            {
                await _eventos.InsertOneAsync(new BsonDocument
                {
                    { "tipo", tipo },
                    { "usuario", usuario },
                    { "data", DateTime.UtcNow },
                    { "detalhes", detalhes }
                });
            }
            catch (Exception)
            {
                // mongo fora do ar: o evento se perde, mas o login ou a transferencia continuam
            }
        }

        // ultimos eventos, do mais novo pro mais antigo, ja em formato simples pra virar json
        public async Task<List<Dictionary<string, object?>>> UltimosEventos(int quantidade)
        {
            var documentos = await _eventos.Find(new BsonDocument())
                .Sort(Builders<BsonDocument>.Sort.Descending("data"))
                .Limit(quantidade)
                .ToListAsync();

            var lista = new List<Dictionary<string, object?>>();
            foreach (var documento in documentos)
            {
                lista.Add(new Dictionary<string, object?>
                {
                    ["id"] = documento["_id"].ToString(),                                  // objectid vira texto
                    ["data"] = documento["data"].ToUniversalTime().ToString("o"),          // data vira texto (utc)
                    ["tipo"] = documento["tipo"].AsString,
                    ["usuario"] = documento["usuario"].AsString,
                    ["detalhes"] = ConverterDetalhes(documento["detalhes"].AsBsonDocument)
                });
            }
            return lista;
        }

        // detalhes: numero continua numero, o resto vira texto
        private static Dictionary<string, object?> ConverterDetalhes(BsonDocument detalhes)
        {
            var resultado = new Dictionary<string, object?>();
            foreach (var campo in detalhes)
            {
                if (campo.Value.IsBsonNull) resultado[campo.Name] = null;
                else if (campo.Value.IsNumeric) resultado[campo.Name] = campo.Value.ToDecimal();
                else resultado[campo.Name] = campo.Value.ToString();
            }
            return resultado;
        }
    }
}
