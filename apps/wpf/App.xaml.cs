using System.Windows;

namespace Nova;

public partial class App : Application
{
    public App()
    {
        // 出错时把异常写到 exe 旁边的 crash.txt，方便在自动截图记录里排查
        DispatcherUnhandledException += (_, e) => WriteCrash(e.Exception);
        AppDomain.CurrentDomain.UnhandledException += (_, e) => WriteCrash(e.ExceptionObject as Exception);
    }

    private static void WriteCrash(Exception? ex)
    {
        try
        {
            System.IO.File.AppendAllText(
                System.IO.Path.Combine(AppContext.BaseDirectory, "crash.txt"), ex + Environment.NewLine);
        }
        catch { }
    }
}
