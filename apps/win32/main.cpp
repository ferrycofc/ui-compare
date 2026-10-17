// Nova 设置面板 —— 纯 Win32 API（C++，只用系统自带的 user32 / comctl32 / gdi32）
//
// 同一份代码编译两次：
//   win32.exe          现代样式（comctl32 v6 视觉样式，Win11 外观）
//   win32_classic.exe  经典主题（不加载视觉样式，系统画经典窗口边框）
// 经典版加 /win2000 参数时，会把系统颜色设成 Windows 2000 的经典配色。

#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#define _WIN32_WINNT 0x0A00
#define NOMINMAX
#include <windows.h>
#include <commctrl.h>
#include <shellapi.h>
#include <shlobj.h>
#include <uxtheme.h>
#include <dwmapi.h>
#include <cwchar>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "uxtheme.lib")
#pragma comment(lib, "dwmapi.lib")

#ifdef NOVA_CLASSIC
static const bool kClassic = true;
static const wchar_t* kTitle = L"Nova 设置 — Win32 API（经典主题）";
#else
static const bool kClassic = false;
static const wchar_t* kTitle = L"Nova 设置 — Win32 API";
#pragma comment(linker, "\"/manifestdependency:type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")
#endif

// 所有技术统一的窗口外框尺寸
static const int kWinW = 920;
static const int kWinH = 660;

struct ToggleRow { const wchar_t* text; bool gear; bool on; };

static const ToggleRow kGeneral[] = {
    {L"开机自启", true, true},   {L"最小化到托盘", true, true}, {L"自动更新", true, false},
    {L"硬件加速", true, true},   {L"垂直同步", true, false},   {L"显示帧率", true, false},
    {L"低延迟模式", true, false}, {L"夜间模式", false, true},  {L"后台静音", false, false},
    {L"发送使用统计", false, false},
};
static const ToggleRow kPerf[] = {
    {L"帧率限制", true, true}, {L"动态分辨率", true, false}, {L"预加载资源", true, false},
    {L"多线程渲染", true, true}, {L"省电模式", true, false},
};
static const ToggleRow kDisplay[] = {{L"自动亮度", false, false}, {L"HDR", false, true}};

static HINSTANCE g_inst;
static HFONT g_font;
static HICON g_gear;
static HWND g_page;
static HWND g_tbBright, g_tbContrast, g_valBright, g_valContrast;

static HICON StockIcon(SHSTOCKICONID id, int px) {
    SHSTOCKICONINFO sii = {sizeof(sii)};
    HICON icon = nullptr;
    if (SUCCEEDED(SHGetStockIconInfo(id, SHGSI_ICONLOCATION, &sii)))
        SHDefExtractIconW(sii.szPath, sii.iIcon, 0, &icon, nullptr, MAKELONG(px, px));
    if (!icon) {
        sii = {sizeof(sii)};
        if (SUCCEEDED(SHGetStockIconInfo(id, SHGSI_ICON | (px <= 16 ? SHGSI_SMALLICON : SHGSI_LARGEICON), &sii)))
            icon = sii.hIcon;
    }
    return icon;
}

static HIMAGELIST IconList(const SHSTOCKICONID* ids, int n, int px) {
    UINT flags = kClassic ? (ILC_COLOR24 | ILC_MASK) : (ILC_COLOR32 | ILC_MASK);
    HIMAGELIST il = ImageList_Create(px, px, flags, n, 0);
    for (int i = 0; i < n; i++) {
        HICON ic = StockIcon(ids[i], px);
        ImageList_AddIcon(il, ic);
        if (ic) DestroyIcon(ic);
    }
    return il;
}

static HWND Make(const wchar_t* cls, const wchar_t* text, DWORD style, int x, int y, int w, int h,
                 HWND parent, int id = 0, DWORD ex = 0) {
    HWND c = CreateWindowExW(ex, cls, text, WS_CHILD | WS_VISIBLE | style, x, y, w, h, parent,
                             (HMENU)(INT_PTR)id, g_inst, nullptr);
    SendMessageW(c, WM_SETFONT, (WPARAM)g_font, FALSE);
    return c;
}

// 一行：文字 + （齿轮按钮）+ 复选框。Win32 没有原生开关控件，用复选框。
static void Rows(HWND page, int x, int y, int w, const ToggleRow* rows, int n, int pitch, int& id) {
    for (int i = 0; i < n; i++) {
        int ry = y + i * pitch;
        Make(L"STATIC", rows[i].text, SS_LEFT | SS_CENTERIMAGE | SS_NOPREFIX, x, ry, w - 90, 24, page);
        HWND cb = Make(L"BUTTON", L"", BS_AUTOCHECKBOX | WS_TABSTOP, x + w - 16, ry + 4, 16, 16, page, id++);
        if (rows[i].on) SendMessageW(cb, BM_SETCHECK, BST_CHECKED, 0);
        if (rows[i].gear) {
            HWND b = Make(L"BUTTON", L"", BS_PUSHBUTTON | BS_ICON | WS_TABSTOP, x + w - 16 - 12 - 28, ry, 28, 24, page, id++);
            SendMessageW(b, BM_SETIMAGE, IMAGE_ICON, (LPARAM)g_gear);
        }
    }
}

static void Slider(HWND page, int x, int y, int w, const wchar_t* label, int value, HWND* track, HWND* text) {
    Make(L"STATIC", label, SS_LEFT | SS_NOPREFIX, x, y, 120, 20, page);
    wchar_t buf[16];
    swprintf_s(buf, L"%d%%", value);
    *text = Make(L"STATIC", buf, SS_RIGHT | SS_NOPREFIX, x + w - 80, y, 80, 20, page);
    *track = Make(TRACKBAR_CLASSW, L"", TBS_HORZ | TBS_AUTOTICKS | TBS_BOTTOM | WS_TABSTOP, x - 6, y + 22, w + 12, 32, page);
    SendMessageW(*track, TBM_SETRANGE, TRUE, MAKELPARAM(0, 100));
    SendMessageW(*track, TBM_SETTICFREQ, 10, 0);
    SendMessageW(*track, TBM_SETPAGESIZE, 0, 10);
    SendMessageW(*track, TBM_SETPOS, TRUE, value);
}

static HWND Toolbar(HWND parent, int x, int y, int w, int h, const SHSTOCKICONID* ids, int n, bool group, int idBase) {
    HWND tb = CreateWindowExW(0, TOOLBARCLASSNAMEW, nullptr,
                              WS_CHILD | WS_VISIBLE | TBSTYLE_FLAT | TBSTYLE_WRAPABLE | CCS_VERT | CCS_NORESIZE |
                                  CCS_NODIVIDER | CCS_NOPARENTALIGN,
                              x, y, w, h, parent, (HMENU)(INT_PTR)idBase, g_inst, nullptr);
    SendMessageW(tb, TB_BUTTONSTRUCTSIZE, sizeof(TBBUTTON), 0);
    SendMessageW(tb, TB_SETIMAGELIST, 0, (LPARAM)IconList(ids, n, 24));
    TBBUTTON b[12] = {};
    for (int i = 0; i < n; i++) {
        b[i].iBitmap = i;
        b[i].idCommand = idBase + 1 + i;
        b[i].fsState = TBSTATE_ENABLED | TBSTATE_WRAP | ((group && i == 0) ? TBSTATE_CHECKED : 0);
        b[i].fsStyle = group ? BTNS_CHECKGROUP : BTNS_BUTTON;
        b[i].iString = -1;
    }
    SendMessageW(tb, TB_ADDBUTTONS, n, (LPARAM)b);
    SendMessageW(tb, TB_SETBUTTONSIZE, 0, MAKELPARAM(38, 38));
    return tb;
}

static INT_PTR CALLBACK PageProc(HWND, UINT msg, WPARAM, LPARAM lp) {
    if (msg == WM_INITDIALOG) return TRUE;
    if (msg == WM_HSCROLL) {
        HWND src = (HWND)lp;
        wchar_t buf[16];
        int v = (int)SendMessageW(src, TBM_GETPOS, 0, 0);
        swprintf_s(buf, L"%d%%", v);
        if (src == g_tbBright) SetWindowTextW(g_valBright, buf);
        if (src == g_tbContrast) SetWindowTextW(g_valContrast, buf);
        return TRUE;
    }
    return FALSE;
}

// 用一个空的对话框模板当“标签页内容页”，这样能拿到标准的对话框行为和主题纹理
static HWND CreatePage(HWND parent) {
    struct alignas(4) EmptyDlg { DLGTEMPLATE t; WORD menu, cls, title; } d = {};
    d.t.style = WS_CHILD | DS_CONTROL;
    d.t.dwExtendedStyle = WS_EX_CONTROLPARENT;
    return CreateDialogIndirectParamW(g_inst, &d.t, parent, PageProc, 0);
}

static void BuildUi(HWND hwnd) {
    RECT cr;
    GetClientRect(hwnd, &cr);
    const int W = cr.right, H = cr.bottom;

    // 左侧图标栏（竖排工具栏）
    const int railW = 44;
    static const SHSTOCKICONID railTop[] = {SIID_SOFTWARE, SIID_DESKTOPPC, SIID_AUDIOFILES, SIID_WORLD,
                                            SIID_KEY,      SIID_DOCNOASSOC, SIID_FOLDER};
    static const SHSTOCKICONID railBottom[] = {SIID_USERS, SIID_SETTINGS};
    Toolbar(hwnd, 8, 8, railW, 7 * 40, railTop, 7, true, 100);
    Toolbar(hwnd, 8, H - 8 - 2 * 40, railW, 2 * 40, railBottom, 2, false, 200);

    // 顶部标签页
    const int tx = 8 + railW + 8;
    HWND tab = CreateWindowExW(0, WC_TABCONTROLW, L"", WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | WS_TABSTOP, tx, 8,
                               W - tx - 8, H - 16, hwnd, (HMENU)10, g_inst, nullptr);
    SendMessageW(tab, WM_SETFONT, (WPARAM)g_font, FALSE);
    static const SHSTOCKICONID tabIcons[] = {SIID_SOFTWARE, SIID_DESKTOPPC, SIID_AUDIOFILES, SIID_WORLD, SIID_KEY};
    TabCtrl_SetImageList(tab, IconList(tabIcons, 5, 16));
    TabCtrl_SetPadding(tab, 10, 4);
    const wchar_t* tabs[] = {L"常规", L"画面", L"音频", L"网络", L"快捷键"};
    for (int i = 0; i < 5; i++) {
        TCITEMW it = {};
        it.mask = TCIF_TEXT | TCIF_IMAGE;
        it.pszText = (LPWSTR)tabs[i];
        it.iImage = i;
        TabCtrl_InsertItem(tab, i, &it);
    }

    RECT pr;
    GetClientRect(tab, &pr);
    TabCtrl_AdjustRect(tab, FALSE, &pr);
    MapWindowPoints(tab, hwnd, (POINT*)&pr, 2);
    g_page = CreatePage(hwnd);
    if (!kClassic) EnableThemeDialogTexture(g_page, ETDT_ENABLETAB);
    SetWindowPos(g_page, HWND_TOP, pr.left, pr.top, pr.right - pr.left, pr.bottom - pr.top, SWP_SHOWWINDOW);

    const int PW = pr.right - pr.left, PH = pr.bottom - pr.top;
    const int m = 12, gap = 12, colW = (PW - 2 * m - gap) / 2;
    const int lx = m, rx = m + colW + gap;
    const int top = 6, bottom = PH - 10;
    const int head = 28, inset = 14;
    int id = 1000;

    // 左：常规选项
    Make(L"BUTTON", L"常规选项", BS_GROUPBOX, lx, top, colW, bottom - top, g_page);
    int pitchL = (bottom - top - head - 12) / 10;
    if (pitchL > 44) pitchL = 44;
    Rows(g_page, lx + inset, top + head, colW - 2 * inset, kGeneral, 10, pitchL, id);

    // 右上：性能
    const int pitchR = 40;
    const int perfH = head + 5 * pitchR + 6;
    Make(L"BUTTON", L"性能", BS_GROUPBOX, rx, top, colW, perfH, g_page);
    Rows(g_page, rx + inset, top + head, colW - 2 * inset, kPerf, 5, pitchR, id);

    // 右下：显示
    const int dy = top + perfH + 10;
    Make(L"BUTTON", L"显示", BS_GROUPBOX, rx, dy, colW, bottom - dy, g_page);
    Rows(g_page, rx + inset, dy + head, colW - 2 * inset, kDisplay, 2, pitchR, id);
    int sy = dy + head + 2 * pitchR + 2;
    Make(L"STATIC", L"", SS_ETCHEDHORZ, rx + inset, sy, colW - 2 * inset, 2, g_page);
    sy += 14;
    Slider(g_page, rx + inset, sy, colW - 2 * inset, L"亮度", 80, &g_tbBright, &g_valBright);
    Slider(g_page, rx + inset, sy + 62, colW - 2 * inset, L"对比度", 35, &g_tbContrast, &g_valContrast);
}

static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_CREATE:
        BuildUi(hwnd);
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

static void ApplyWin2000Colors() {
    const int idx[] = {COLOR_ACTIVECAPTION, COLOR_GRADIENTACTIVECAPTION, COLOR_CAPTIONTEXT,
                       COLOR_INACTIVECAPTION, COLOR_GRADIENTINACTIVECAPTION, COLOR_INACTIVECAPTIONTEXT,
                       COLOR_BTNFACE, COLOR_BTNSHADOW, COLOR_BTNHIGHLIGHT, COLOR_3DDKSHADOW, COLOR_3DLIGHT,
                       COLOR_ACTIVEBORDER, COLOR_INACTIVEBORDER, COLOR_HIGHLIGHT, COLOR_HIGHLIGHTTEXT};
    const COLORREF val[] = {RGB(10, 36, 106),   RGB(166, 202, 240), RGB(255, 255, 255),
                            RGB(128, 128, 128), RGB(192, 192, 192), RGB(212, 208, 200),
                            RGB(212, 208, 200), RGB(128, 128, 128), RGB(255, 255, 255), RGB(64, 64, 64),
                            RGB(212, 208, 200), RGB(212, 208, 200), RGB(212, 208, 200), RGB(10, 36, 106),
                            RGB(255, 255, 255)};
    SetSysColors(ARRAYSIZE(idx), idx, val);
    SystemParametersInfoW(SPI_SETGRADIENTCAPTIONS, 0, (PVOID)TRUE, 0);
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE, PWSTR cmd, int show) {
    g_inst = inst;
    if (kClassic) {
        SetThemeAppProperties(0);  // 不画视觉样式：经典边框、经典控件
        if (cmd && wcsstr(cmd, L"/win2000")) ApplyWin2000Colors();
    } else {
        SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    }

    INITCOMMONCONTROLSEX icc = {sizeof(icc), ICC_TAB_CLASSES | ICC_BAR_CLASSES | ICC_STANDARD_CLASSES};
    InitCommonControlsEx(&icc);

    // 经典版用宋体 9 磅（Windows 2000 中文版的界面字体），现代版用微软雅黑 UI 9 磅
    g_font = CreateFontW(-12, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                         CLIP_DEFAULT_PRECIS, kClassic ? NONANTIALIASED_QUALITY : CLEARTYPE_QUALITY,
                         DEFAULT_PITCH | FF_DONTCARE, kClassic ? L"SimSun" : L"Microsoft YaHei UI");
    g_gear = StockIcon(SIID_SETTINGS, 16);

    WNDCLASSEXW wc = {sizeof(wc)};
    wc.lpfnWndProc = WndProc;
    wc.hInstance = inst;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
    wc.lpszClassName = L"NovaWin32";
    wc.hIcon = StockIcon(SIID_SOFTWARE, 32);
    wc.hIconSm = StockIcon(SIID_SOFTWARE, 16);
    RegisterClassExW(&wc);

    const DWORD style = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_CLIPCHILDREN;
    HWND hwnd = CreateWindowExW(WS_EX_CONTROLPARENT, wc.lpszClassName, kTitle, style, CW_USEDEFAULT, CW_USEDEFAULT,
                                kWinW, kWinH, nullptr, nullptr, inst, nullptr);
    if (kClassic) {
        DWMNCRENDERINGPOLICY ncrp = DWMNCRP_DISABLED;
        DwmSetWindowAttribute(hwnd, DWMWA_NCRENDERING_POLICY, &ncrp, sizeof(ncrp));
        DWM_WINDOW_CORNER_PREFERENCE corner = DWMWCP_DONOTROUND;
        DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corner, sizeof(corner));
        SetWindowTheme(hwnd, L"", L"");
        SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
    }
    ShowWindow(hwnd, show);
    UpdateWindow(hwnd);

    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        if (!IsDialogMessageW(hwnd, &msg)) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }
    return (int)msg.wParam;
}
