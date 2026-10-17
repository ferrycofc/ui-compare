namespace Nova;

public readonly record struct SysIcon(string Dll, int Index);

// 图标全部取自 Windows 自带的 DLL（和 Win32 版用的是同一批）
public static class SysIcons
{
    public static readonly SysIcon General = new("shell32.dll", 21);    // 控制面板
    public static readonly SysIcon Display = new("imageres.dll", 104);  // 显示器
    public static readonly SysIcon Audio = new("ddores.dll", 1);        // 扬声器
    public static readonly SysIcon Network = new("shell32.dll", 13);    // 地球
    public static readonly SysIcon Keys = new("ddores.dll", 30);        // 键盘
    public static readonly SysIcon List = new("shell32.dll", 70);       // 文档
    public static readonly SysIcon Folder = new("shell32.dll", 4);      // 文件夹
    public static readonly SysIcon User = new("shell32.dll", 160);      // 用户
    public static readonly SysIcon Settings = new("shell32.dll", 314);  // 齿轮

    // Icon.ExtractIcon 是 .NET 8 新加的，可以直接要指定像素大小的图标
    public static Icon? Load(SysIcon s, int size)
    {
        try { return Icon.ExtractIcon(Path.Combine(Environment.SystemDirectory, s.Dll), s.Index, size); }
        catch { return null; }
    }

    public static Bitmap? LoadBitmap(SysIcon s, int size)
    {
        using var icon = Load(s, size);
        return icon?.ToBitmap();
    }
}
