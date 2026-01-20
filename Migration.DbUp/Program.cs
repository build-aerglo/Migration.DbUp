using System.Reflection;
using DbUp;

namespace Migration.DbUp;

internal abstract class Program
{
    static int Main(string[] args) 
    {
        var connectionString = args.FirstOrDefault()
                               ?? "Host=ep-long-unit-afcwfcyj-pooler.c-2.us-west-2.aws.neon.tech;Database=clereview;Username=neondb_owner;Password=npg_7CZd9OgaYmWj;SSL Mode=Require;Trust Server Certificate=True;Include Error Detail=true";

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