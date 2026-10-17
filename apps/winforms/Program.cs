namespace Nova;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        // 出错时把异常写到 exe 旁边的 crash.txt，方便在自动截图记录里排查
        Application.ThreadException += (_, e) => WriteCrash(e.Exception);
        try
        {
            ApplicationConfiguration.Initialize();
            Application.Run(new MainForm());
        }
        catch (Exception ex)
        {
            WriteCrash(ex);
            throw;
        }
    }

    private static void WriteCrash(Exception ex)
    {
        try { File.AppendAllText(Path.Combine(AppContext.BaseDirectory, "crash.txt"), ex + Environment.NewLine); }
        catch { }
    }
}
