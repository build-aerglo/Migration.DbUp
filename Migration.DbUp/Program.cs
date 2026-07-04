using System.Reflection;
using DbUp;
using Microsoft.Extensions.Configuration;

namespace Migration.DbUp;

internal abstract class Program
{
    static int Main(string[] args) 
    {
        var config = new ConfigurationBuilder()
            .AddUserSecrets(typeof(Program).Assembly, optional: true)
            .AddEnvironmentVariables()
            .Build();

        // Resolution order: explicit CLI arg → ConnectionStrings:PostgresConnection from a
        // local user-secret or the ConnectionStrings__PostgresConnection environment variable.
        // No connection string is hardcoded here — provide one of the above (CI passes it from a
        // GitHub Actions secret; locally use `dotnet user-secrets` or the env var).
        var connectionString =
            args.FirstOrDefault()
            ?? config.GetConnectionString("PostgresConnection")
            ?? throw new InvalidOperationException(
                "No PostgreSQL connection string provided. Pass it as the first CLI argument, or set " +
                "ConnectionStrings:PostgresConnection via `dotnet user-secrets` or the " +
                "ConnectionStrings__PostgresConnection environment variable.");

        var upgrader = DeployChanges.To
            .PostgresqlDatabase(connectionString)
            .WithScriptsEmbeddedInAssembly(Assembly.GetExecutingAssembly())
            .LogToConsole()
            .Build();

        var result = upgrader.PerformUpgrade();

        if (!result.Successful)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine(result.Error);
            Console.ResetColor();
            return -1;
        }

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("✅ Database upgraded successfully!");
        Console.ResetColor();
        return 0;
    }
}