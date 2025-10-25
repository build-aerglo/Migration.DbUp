using System.Reflection;
using DbUp;

namespace Migration.DbUp;

internal abstract class Program
{
    static int Main(string[] args)
    {
        var connectionString = args.FirstOrDefault()
                               ?? "Host=localhost;Database=testdb;Username=dily;Password=password1";

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