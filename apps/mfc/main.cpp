// Nova 设置面板 —— MFC（C++，Visual C++ 自带的类库）
//
// MFC 是 Win32 的 C++ 外壳：窗口、控件都包成了类，消息用“消息映射”宏分发。
// 这里用到了 2008 年加入的 Feature Pack：CMFCVisualManagerOffice2007（Office 2007 皮肤）、
// CMFCTabCtrl（OneNote 风格的彩色标签）、CMFCButton（带图标、由皮肤绘制的按钮和复选框）、
// CDrawingManager（渐变绘制）。

#include <afxwin.h>
#include <afxext.h>
#include <afxcontrolbars.h>
#include <afxcmn.h>
#include <afxtempl.h>
#include <shlobj.h>

#pragma comment(lib, "shell32.lib")

#pragma comment(linker, "\"/manifestdependency:type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")

// 统一的窗口外框（和 Win32 版一样，看得见的大小约 906 x 653）
static const int kWinW = 920;
static const int kWinH = 660;

struct Row { LPCWSTR text; bool gear; bool on; };

static const Row kGeneral[] = {
    {L"开机自启", true, true},   {L"最小化到托盘", true, true}, {L"自动更新", true, false},
    {L"硬件加速", true, true},   {L"垂直同步", true, false},   {L"显示帧率", true, false},
    {L"低延迟模式", true, false}, {L"夜间模式", false, true},  {L"后台静音", false, false},
    {L"发送使用统计", false, false},
};
static const Row kPerf[] = {
    {L"帧率限制", true, true}, {L"动态分辨率", true, false}, {L"预加载资源", true, false},
    {L"多线程渲染", true, true}, {L"省电模式", true, false},
};
static const Row kDisplay[] = {{L"自动亮度", false, false}, {L"HDR", false, true}};

// 图标全部来自 Windows 自带的 DLL（和 Win32 版相同）
struct SysIcon { LPCWSTR dll; int index; };
static const SysIcon kIcoGeneral = {L"shell32.dll", 21}, kIcoDisplay = {L"imageres.dll", 104}, kIcoAudio = {L"ddores.dll", 1},
                     kIcoNetwork = {L"shell32.dll", 13}, kIcoKeys = {L"ddores.dll", 30}, kIcoList = {L"shell32.dll", 70},
                     kIcoFolder = {L"shell32.dll", 4}, kIcoUser = {L"shell32.dll", 160}, kIcoSettings = {L"shell32.dll", 314};

static HICON LoadSysIcon(const SysIcon& s, int px) {
    wchar_t path[MAX_PATH];
    GetSystemDirectoryW(path, MAX_PATH);
    wcscat_s(path, L"\\");
    wcscat_s(path, s.dll);
    HICON icon = nullptr;
    SHDefExtractIconW(path, s.index, 0, &icon, nullptr, MAKELONG(px, px));
    return icon;
}

// Office 2007 银色主题里的几个颜色
static const COLORREF kPageBg = RGB(255, 255, 255);
static const COLORREF kRailTop = RGB(232, 236, 243);
static const COLORREF kRailBottom = RGB(208, 215, 226);

// ---------------------------------------------------------------- “常规”标签页的内容

class CNovaPage : public CWnd {
public:
    CFont* m_font = nullptr;
    CBrush m_bg;
    CArray<CWnd*, CWnd*> m_ctrls;
    CSliderCtrl m_bright, m_contrast;
    CStatic m_brightVal, m_contrastVal;
    UINT m_nextId = 1000;

    BOOL CreatePage(CWnd* parent) {
        m_bg.CreateSolidBrush(kPageBg);
        CString cls = AfxRegisterWndClass(CS_HREDRAW | CS_VREDRAW, ::LoadCursor(nullptr, IDC_ARROW), nullptr, nullptr);
        return CreateEx(WS_EX_CONTROLPARENT, cls, L"", WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN, CRect(0, 0, 100, 100), parent, 1);
    }

    template <class T> T* Add(T* c) {
        m_ctrls.Add(c);
        return c;
    }

    void Label(LPCWSTR text, const CRect& r, DWORD align = SS_LEFT) {
        CStatic* s = Add(new CStatic);
        s->Create(text, WS_CHILD | WS_VISIBLE | align | SS_CENTERIMAGE | SS_NOPREFIX, r, this);
        s->SetFont(m_font);
    }

    // 一行：文字 +（齿轮按钮，CMFCButton）+ 复选框
    void Rows(int x, int y, int w, const Row* rows, int n, int pitch) {
        for (int i = 0; i < n; i++) {
            int ry = y + i * pitch;
            Label(rows[i].text, CRect(x, ry, x + w - 90, ry + 24));  // 文字标签紧挨在复选框前面：辅助功能会把它当成复选框的名字
            // 复选框用普通的 CButton：Office 2007 皮肤画复选框要靠资源图片，在 Win11 上会退回到一种不显示对勾的画法
            CButton* cb = Add(new CButton);
            cb->Create(L"", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_AUTOCHECKBOX, CRect(x + w - 16, ry + 4, x + w, ry + 20), this, m_nextId++);
            cb->SetCheck(rows[i].on ? BST_CHECKED : BST_UNCHECKED);
            if (rows[i].gear) {
                CMFCButton* g = Add(new CMFCButton);
                g->Create(L"", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON, CRect(x + w - 18 - 12 - 30, ry, x + w - 18 - 12, ry + 24), this, m_nextId++);
                g->m_nFlatStyle = CMFCButton::BUTTONSTYLE_SEMIFLAT;
                g->m_bDrawFocus = FALSE;
                g->SetImage(LoadSysIcon(kIcoSettings, 16));
                CString tip;
                tip.Format(L"%s设置", rows[i].text);
                g->SetTooltip(tip);
            }
        }
    }

    void Group(LPCWSTR title, const CRect& r) {
        CButton* b = Add(new CButton);
        b->Create(title, WS_CHILD | WS_VISIBLE | BS_GROUPBOX, r, this, m_nextId++);
        b->SetFont(m_font);
    }

    void Slider(int x, int y, int w, LPCWSTR label, int value, CSliderCtrl& track, CStatic& text, UINT id) {
        CString v;
        v.Format(L"%d%%", value);
        text.Create(v, WS_CHILD | WS_VISIBLE | SS_RIGHT | SS_NOPREFIX, CRect(x + w - 80, y, x + w, y + 20), this);
        text.SetFont(m_font);
        Label(label, CRect(x, y, x + 120, y + 20));  // 名字标签紧挨在滑块前面
        track.Create(WS_CHILD | WS_VISIBLE | WS_TABSTOP | TBS_HORZ | TBS_AUTOTICKS | TBS_BOTTOM, CRect(x - 6, y + 22, x + w + 6, y + 54), this, id);
        track.SetRange(0, 100);
        track.SetTicFreq(10);
        track.SetPageSize(10);
        track.SetPos(value);
    }

    void Build() {
        CRect rc;
        GetClientRect(&rc);
        const int m = 12, gap = 12, colW = (rc.Width() - 2 * m - gap) / 2;
        const int lx = m, rx = m + colW + gap, top = 8, bottom = rc.Height() - 12, head = 30, inset = 14;

        Group(L"常规选项", CRect(lx, top, lx + colW, bottom));
        int pitchL = (bottom - top - head - 12) / 10;
        if (pitchL > 44) pitchL = 44;
        Rows(lx + inset, top + head, colW - 2 * inset, kGeneral, 10, pitchL);

        const int pitchR = 40, perfH = head + 5 * pitchR + 6;
        Group(L"性能", CRect(rx, top, rx + colW, top + perfH));
        Rows(rx + inset, top + head, colW - 2 * inset, kPerf, 5, pitchR);

        const int dy = top + perfH + 10;
        Group(L"显示", CRect(rx, dy, rx + colW, bottom));
        Rows(rx + inset, dy + head, colW - 2 * inset, kDisplay, 2, pitchR);
        int sy = dy + head + 2 * pitchR + 2;
        CStatic* line = Add(new CStatic);
        line->Create(L"", WS_CHILD | WS_VISIBLE | SS_ETCHEDHORZ, CRect(rx + inset, sy, rx + colW - inset, sy + 2), this);
        sy += 14;
        Slider(rx + inset, sy, colW - 2 * inset, L"亮度", 80, m_bright, m_brightVal, 2001);
        Slider(rx + inset, sy + 62, colW - 2 * inset, L"对比度", 35, m_contrast, m_contrastVal, 2002);
    }

    virtual void PostNcDestroy() override {
        for (int i = 0; i < m_ctrls.GetSize(); i++) delete m_ctrls[i];
        m_ctrls.RemoveAll();
    }

protected:
    afx_msg BOOL OnEraseBkgnd(CDC* dc) {
        CRect rc;
        GetClientRect(&rc);
        dc->FillSolidRect(rc, kPageBg);
        return TRUE;
    }
    afx_msg HBRUSH OnCtlColor(CDC* dc, CWnd*, UINT) {
        dc->SetBkColor(kPageBg);
        return (HBRUSH)m_bg.GetSafeHandle();
    }
    afx_msg void OnHScroll(UINT, UINT, CScrollBar* bar) {
        CString v;
        if (bar && bar->GetSafeHwnd() == m_bright.GetSafeHwnd()) { v.Format(L"%d%%", m_bright.GetPos()); m_brightVal.SetWindowText(v); }
        if (bar && bar->GetSafeHwnd() == m_contrast.GetSafeHwnd()) { v.Format(L"%d%%", m_contrast.GetPos()); m_contrastVal.SetWindowText(v); }
    }
    DECLARE_MESSAGE_MAP()
};

BEGIN_MESSAGE_MAP(CNovaPage, CWnd)
    ON_WM_ERASEBKGND()
    ON_WM_CTLCOLOR()
    ON_WM_HSCROLL()
END_MESSAGE_MAP()

// ---------------------------------------------------------------- 主窗口

class CMainFrame : public CFrameWnd {
public:
    CFont m_font;
    CMFCTabCtrl m_tabs;
    CNovaPage m_page;
    CStatic m_empty[4];
    CMFCButton m_rail[9];
    CImageList m_tabImages;

protected:
    afx_msg int OnCreate(LPCREATESTRUCT cs) {
        if (CFrameWnd::OnCreate(cs) == -1) return -1;

        // 微软雅黑 UI 9 磅
        m_font.CreateFont(-12, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                          CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Microsoft YaHei UI");

        CRect rc;
        GetClientRect(&rc);
        const int railW = 52;

        // 左侧图标栏：CMFCButton，第一个是“按下”状态
        const SysIcon railIcons[] = {kIcoGeneral, kIcoDisplay, kIcoAudio, kIcoNetwork, kIcoKeys, kIcoList, kIcoFolder, kIcoUser, kIcoSettings};
        const LPCWSTR railTips[] = {L"常规", L"画面", L"音频", L"网络", L"快捷键", L"列表", L"文件夹", L"账户", L"设置"};
        for (int i = 0; i < 9; i++) {
            int y = i < 7 ? 8 + i * 44 : rc.Height() - 8 - (9 - i) * 44;
            DWORD style = WS_CHILD | WS_VISIBLE | (i == 0 ? BS_AUTOCHECKBOX | BS_PUSHLIKE : BS_PUSHBUTTON);
            m_rail[i].Create(L"", style, CRect(6, y, 6 + 40, y + 40), this, 300 + i);
            m_rail[i].m_nFlatStyle = CMFCButton::BUTTONSTYLE_FLAT;
            m_rail[i].m_bDrawFocus = FALSE;
            m_rail[i].SetImage(LoadSysIcon(railIcons[i], 24));
            m_rail[i].SetTooltip(railTips[i]);
            if (i == 0) m_rail[i].SetCheck(BST_CHECKED);
        }

        // 顶部标签：CMFCTabCtrl 的 OneNote 风格，每个标签自动配一种颜色
        const SysIcon tabIcons[] = {kIcoGeneral, kIcoDisplay, kIcoAudio, kIcoNetwork, kIcoKeys};
        m_tabImages.Create(16, 16, ILC_COLOR32 | ILC_MASK, 5, 0);
        for (const SysIcon& s : tabIcons) {
            HICON ic = LoadSysIcon(s, 16);
            m_tabImages.Add(ic);
            if (ic) DestroyIcon(ic);
        }
        CRect tabRect(railW + 6, 6, rc.right - 6, rc.bottom - 6);
        m_tabs.Create(CMFCTabCtrl::STYLE_3D_ONENOTE, tabRect, this, 10, CMFCBaseTabCtrl::LOCATION_TOP);
        m_tabs.SetImageList(m_tabImages.GetSafeHandle());
        m_tabs.EnableAutoColor(TRUE);
        m_tabs.SetActiveTabBoldFont(TRUE);
        m_tabs.EnableTabSwap(FALSE);

        m_page.m_font = &m_font;
        m_page.CreatePage(&m_tabs);
        m_tabs.AddTab(&m_page, L"常规", 0, FALSE);
        const LPCWSTR names[] = {L"画面", L"音频", L"网络", L"快捷键"};
        for (int i = 0; i < 4; i++) {
            m_empty[i].Create(L"", WS_CHILD, CRect(0, 0, 10, 10), &m_tabs, 20 + i);
            m_tabs.AddTab(&m_empty[i], names[i], i + 1, FALSE);
        }
        m_tabs.SetActiveTab(0);
        m_tabs.RecalcLayout();

        // 标签页的大小定下来以后再摆控件
        CRect area;
        m_tabs.GetWndArea(area);
        if (area.Width() > 200 && area.Height() > 200) m_page.MoveWindow(area, FALSE);
        m_page.Build();
        return 0;
    }

    afx_msg BOOL OnEraseBkgnd(CDC* dc) {
        CRect rc;
        GetClientRect(&rc);
        CDrawingManager dm(*dc);
        dm.FillGradient(rc, kRailBottom, kRailTop, FALSE);  // 上浅下深的竖向渐变（Office 2007 银色）
        return TRUE;
    }

    afx_msg void OnSetFocus(CWnd*) {}  // 不要把键盘焦点交给某个按钮（截图里不出现焦点框）

    DECLARE_MESSAGE_MAP()
};

BEGIN_MESSAGE_MAP(CMainFrame, CFrameWnd)
    ON_WM_CREATE()
    ON_WM_ERASEBKGND()
    ON_WM_SETFOCUS()
END_MESSAGE_MAP()

// ---------------------------------------------------------------- 程序

class CNovaApp : public CWinAppEx {
public:
    virtual BOOL InitInstance() override {
        INITCOMMONCONTROLSEX icc = {sizeof(icc), ICC_WIN95_CLASSES | ICC_STANDARD_CLASSES};
        InitCommonControlsEx(&icc);
        CWinAppEx::InitInstance();

        // Office 2007 银色皮肤；CMFCButton 不用系统主题，而是由皮肤来画
        CMFCVisualManagerOffice2007::SetStyle(CMFCVisualManagerOffice2007::Office2007_Silver);
        CMFCVisualManager::SetDefaultManager(RUNTIME_CLASS(CMFCVisualManagerOffice2007));
        CMFCButton::EnableWindowsTheming(FALSE);

        CMainFrame* frame = new CMainFrame;
        const DWORD style = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_CLIPCHILDREN;
        if (!frame->Create(nullptr, L"Nova 设置 — MFC", style, CRect(80, 80, 80 + kWinW, 80 + kWinH))) return FALSE;
        HICON icon = LoadSysIcon(kIcoGeneral, 32);
        frame->SetIcon(icon, TRUE);
        frame->SetIcon(LoadSysIcon(kIcoGeneral, 16), FALSE);
        m_pMainWnd = frame;
        frame->ShowWindow(SW_SHOW);
        frame->UpdateWindow();
        return TRUE;
    }
};

CNovaApp theApp;
