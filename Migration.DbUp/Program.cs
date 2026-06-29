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
        // local user-secret or env var (ConnectionStrings__PostgresConnection) → shared Neon
        // default. Lets a developer target a local Postgres without editing this tracked file.
        var connectionString =
            args.FirstOrDefault()
            ?? config.GetConnectionString("PostgresConnection")
            ?? "Host=ep-long-unit-afcwfcyj-pooler.c-2.us-west-2.aws.neon.tech;Database=neondb;Username=neondb_owner;Password=REMOVED;SSL Mode=Require";

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