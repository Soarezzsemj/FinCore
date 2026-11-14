using FinCoreApi.Data;
using Microsoft.OpenApi;
using MySqlConnector;
using Scalar.AspNetCore;

// pasta raiz do projeto (onde fica o docker-compose.yaml), de la vem o .env e o frontend
var pastaRaiz = ArquivoEnv.AcharPastaRaiz();
ArquivoEnv.Carregar(Path.Combine(pastaRaiz, ".env"));

var builder = WebApplication.CreateBuilder(new WebApplicationOptions
{
    Args = args,
    WebRootPath = Path.Combine(pastaRaiz, "frontend")   // a api tambem entrega o site
});

// dados de conexao lidos das variaveis de ambiente (ou do .env)
var usuarioBanco = ArquivoEnv.Ler("DB_USER", "app_fincore");
if (usuarioBanco == "root")
    throw new Exception("A API não pode conectar como root. Use o usuário app_fincore.");

var conexaoBanco = new MySqlConnectionStringBuilder
{
    Server   = ArquivoEnv.Ler("DB_HOST", "localhost"),
    Port     = uint.Parse(ArquivoEnv.Ler("DB_PORT", "3307")),
    Database = ArquivoEnv.Ler("DB_NAME", "fincore"),
    UserID   = usuarioBanco,
    Password = ArquivoEnv.Ler("DB_PASSWORD", "")
}.ConnectionString;

// banco e sessoes sao unicos pra api toda; os controllers recebem eles no construtor
builder.Services.AddSingleton(new Banco(conexaoBanco));
builder.Services.AddSingleton<Sessoes>();
builder.Services.AddControllers();

// documento openapi (/openapi/v1.json) com o login por token (bearer) descrito
builder.Services.AddOpenApi(opcoes =>
{
    opcoes.AddDocumentTransformer((documento, contexto, cancelamento) =>
    {
        documento.Info.Title = "FinCore API";
        documento.Info.Description =
            "Como autenticar: 1) chame POST /api/login com {\"login\": \"admin\", \"senha\": \"fincore123\"}; " +
            "2) copie o campo token da resposta; 3) clique em Authentication (Bearer) e cole o token. " +
            "As outras rotas passam a enviar o cabeçalho Authorization: Bearer <token>.";
        documento.Components ??= new OpenApiComponents();
        documento.Components.SecuritySchemes = new Dictionary<string, IOpenApiSecurityScheme>
        {
            ["Bearer"] = new OpenApiSecurityScheme
            {
                Type = SecuritySchemeType.Http,
                Scheme = "bearer",
                Description = "Token devolvido por POST /api/login"
            }
        };
        documento.Security = [new OpenApiSecurityRequirement { [new OpenApiSecuritySchemeReference("Bearer", documento)] = [] }];
        return Task.CompletedTask;
    });
});

var app = builder.Build();

// qualquer erro nao tratado vira um json simples (o site mostra a mensagem)
app.Use(async (contexto, proximo) =>
{
    try
    {
        await proximo();
    }
    catch (MySqlException erro)
    {
        contexto.Response.StatusCode = 503;
        await contexto.Response.WriteAsJsonAsync(new { erro = "Banco de dados indisponível: " + erro.Message });
    }
    catch (Exception erro)
    {
        contexto.Response.StatusCode = 500;
        await contexto.Response.WriteAsJsonAsync(new { erro = "Erro interno: " + erro.Message });
    }
});

app.UseDefaultFiles();   // http://localhost:3000 abre o frontend/index.html
app.UseStaticFiles();

app.MapOpenApi();                                   // /openapi/v1.json
app.MapScalarApiReference(opcoes => opcoes          // /scalar
    .WithTitle("FinCore API")
    .AddPreferredSecuritySchemes("Bearer"));

app.MapControllers();   // rotas que ficam na pasta Controllers

app.Run("http://localhost:3000");
