// Nova 设置面板 —— Dear ImGui（立即模式 UI）+ Win32 窗口 + Direct3D 11
//
// 立即模式：没有“控件对象”，每一帧都把整个界面从头画一遍，状态就是普通的 C++ 变量。
// 开关、滑块的填充条都是用 ImDrawList 自己画的，几十行代码就是一个带动画的新控件。

#include "imgui.h"
#include "imgui_impl_win32.h"
#include "imgui_impl_dx11.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <d3d11.h>
#include <dwmapi.h>
#include <math.h>
#include <stdio.h>
#include <map>
#include <string>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3dcompiler.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")

// ---------------------------------------------------------------- 数据

struct Row { const char* text; bool gear; bool on; };

static Row g_general[] = {
    {u8"开机自启", true, true},   {u8"最小化到托盘", true, true}, {u8"自动更新", true, false},
    {u8"硬件加速", true, true},   {u8"垂直同步", true, false},   {u8"显示帧率", true, false},
    {u8"低延迟模式", true, false}, {u8"夜间模式", false, true},  {u8"后台静音", false, false},
    {u8"发送使用统计", false, false},
};
static Row g_perf[] = {
    {u8"帧率限制", true, true}, {u8"动态分辨率", true, false}, {u8"预加载资源", true, false},
    {u8"多线程渲染", true, true}, {u8"省电模式", true, false},
};
static Row g_display[] = {{u8"自动亮度", false, false}, {"HDR", false, true}};

static int g_bright = 80, g_contrast = 35;
static int g_rail = 0, g_tab = 0;

// 图标：Windows 11 自带的 Segoe Fluent Icons 字体
enum : unsigned { IC_GENERAL = 0xE9E9, IC_DISPLAY = 0xE7F4, IC_AUDIO = 0xE767, IC_NET = 0xE774, IC_KEYS = 0xE765,
                  IC_LIST = 0xE8FD, IC_FOLDER = 0xE8B7, IC_GEAR = 0xE713, IC_PERF = 0xEC4A, IC_SUN = 0xE706 };

static std::string Glyph(unsigned cp) {
    char s[4] = {(char)(0xE0 | (cp >> 12)), (char)(0x80 | ((cp >> 6) & 0x3F)), (char)(0x80 | (cp & 0x3F)), 0};
    return s;
}

// ---------------------------------------------------------------- 配色

static ImU32 Hex(unsigned rgb, float a = 1.0f) {
    return IM_COL32((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF, (int)(a * 255));
}
static const unsigned kBg = 0x0F1014, kRail = 0x0B0C0F, kCard = 0x17181D, kBorder = 0x25272F;
static const unsigned kAccent = 0x8B7CF6, kText = 0xE6E7EE, kMuted = 0x8E909C, kTrack = 0x2A2C35;

static ImFont* g_font;      // 正文 15px + 图标
static ImFont* g_bold;      // 标题 15px 粗体 + 图标
static ImFont* g_icons;     // 侧边栏图标 19px

// 给录屏脚本用：记下几个控件的位置（窗口里的坐标），启动后写到 exe 旁边的 nova-points.json
static std::map<std::string, ImVec4> g_points;

// ---------------------------------------------------------------- 自定义控件

static float Approach(float cur, float target, float speed) {
    float d = target - cur;
    if (fabsf(d) <= speed) return target;
    return cur + (d > 0 ? speed : -speed);
}

// 带动画的开关：InvisibleButton 负责点击，ImDrawList 负责画，动画进度存在 ImGui 的状态存储里
static bool ToggleSwitch(const char* id, bool* v) {
    const ImVec2 size(38, 22);
    ImVec2 p = ImGui::GetCursorScreenPos();
    bool clicked = ImGui::InvisibleButton(id, size);
    if (clicked) *v = !*v;
    bool hovered = ImGui::IsItemHovered();

    ImGuiStorage* st = ImGui::GetStateStorage();
    ImGuiID key = ImGui::GetItemID();
    float t = st->GetFloat(key, *v ? 1.0f : 0.0f);
    t = Approach(t, *v ? 1.0f : 0.0f, ImGui::GetIO().DeltaTime * 7.0f);  // 约 140 ms
    st->SetFloat(key, t);
    float e = t * t * (3 - 2 * t);  // smoothstep 缓动

    ImVec4 off = ImGui::ColorConvertU32ToFloat4(Hex(hovered ? 0x33363F : kTrack));
    ImVec4 on = ImGui::ColorConvertU32ToFloat4(Hex(kAccent));
    ImVec4 c(off.x + (on.x - off.x) * e, off.y + (on.y - off.y) * e, off.z + (on.z - off.z) * e, 1.0f);

    ImDrawList* dl = ImGui::GetWindowDrawList();
    float r = size.y * 0.5f;
    dl->AddRectFilled(p, ImVec2(p.x + size.x, p.y + size.y), ImGui::ColorConvertFloat4ToU32(c), r);
    float kx = p.x + r + e * (size.x - size.y);
    dl->AddCircleFilled(ImVec2(kx, p.y + r), r - 3.5f, Hex(t > 0.5f ? 0xFFFFFF : 0x9A9CA8), 24);

    g_points[id] = ImVec4(p.x + size.x * 0.5f, p.y + size.y * 0.5f, 0, 0);
    return clicked;
}

static void IconButton(const char* id, unsigned icon) {
    const ImVec2 size(28, 28);
    ImVec2 p = ImGui::GetCursorScreenPos();
    ImGui::InvisibleButton(id, size);
    bool hovered = ImGui::IsItemHovered(), held = ImGui::IsItemActive();
    ImDrawList* dl = ImGui::GetWindowDrawList();
    if (hovered) dl->AddRectFilled(p, ImVec2(p.x + size.x, p.y + size.y), Hex(0xFFFFFF, held ? 0.10f : 0.06f), 6);
    std::string g = Glyph(icon);
    ImVec2 ts = ImGui::CalcTextSize(g.c_str());
    dl->AddText(ImVec2(p.x + (size.x - ts.x) * 0.5f, p.y + (size.y - ts.y) * 0.5f), Hex(hovered ? kText : kMuted), g.c_str());
}

// 滑块：用 ImGui 自带的 SliderInt 处理拖动，再在上面画细轨道、紫色填充和圆形把手
static void NovaSlider(const char* id, const char* label, int* v, float width) {
    ImGui::PushFont(g_font);
    ImVec2 p = ImGui::GetCursorScreenPos();
    ImDrawList* dl = ImGui::GetWindowDrawList();
    dl->AddText(p, Hex(kText), label);
    char buf[16];
    snprintf(buf, sizeof buf, "%d%%", *v);
    ImVec2 ts = ImGui::CalcTextSize(buf);
    dl->AddText(ImVec2(p.x + width - ts.x, p.y), Hex(kMuted), buf);
    ImGui::Dummy(ImVec2(width, ts.y + 8));

    ImGui::PushStyleColor(ImGuiCol_FrameBg, 0u);
    ImGui::PushStyleColor(ImGuiCol_FrameBgHovered, 0u);
    ImGui::PushStyleColor(ImGuiCol_FrameBgActive, 0u);
    ImGui::PushStyleColor(ImGuiCol_SliderGrab, 0u);
    ImGui::PushStyleColor(ImGuiCol_SliderGrabActive, 0u);
    ImGui::PushStyleVar(ImGuiStyleVar_FramePadding, ImVec2(0, 4));
    ImGui::PushStyleVar(ImGuiStyleVar_GrabMinSize, 16.0f);
    ImGui::SetNextItemWidth(width);
    ImGui::SliderInt(id, v, 0, 100, "");
    bool active = ImGui::IsItemActive(), hovered = ImGui::IsItemHovered();
    ImGui::PopStyleVar(2);
    ImGui::PopStyleColor(5);

    // SliderInt 的把手中心：左右各留 2px 边距和半个把手宽
    ImVec2 a = ImGui::GetItemRectMin(), b = ImGui::GetItemRectMax();
    float grab = 16.0f, pad = 2.0f;
    float x0 = a.x + pad + grab * 0.5f, usable = (b.x - a.x) - 2 * pad - grab;
    float gx = x0 + usable * (*v / 100.0f), cy = (a.y + b.y) * 0.5f;
    dl->AddRectFilled(ImVec2(x0, cy - 2), ImVec2(x0 + usable, cy + 2), Hex(kTrack), 2);
    dl->AddRectFilled(ImVec2(x0, cy - 2), ImVec2(gx, cy + 2), Hex(kAccent), 2);
    if (hovered || active) dl->AddCircleFilled(ImVec2(gx, cy), 13, Hex(kAccent, 0.18f), 32);
    dl->AddCircleFilled(ImVec2(gx, cy), 8, Hex(kAccent), 32);
    dl->AddCircleFilled(ImVec2(gx, cy), 3.5f, Hex(0xFFFFFF), 16);

    g_points[label] = ImVec4(gx, cy, x0, usable);
    ImGui::PopFont();
}

// ---------------------------------------------------------------- 界面

static void CardHeader(unsigned icon, const char* title) {
    ImVec2 p = ImGui::GetCursorScreenPos();
    ImDrawList* dl = ImGui::GetWindowDrawList();
    ImGui::PushFont(g_bold);
    dl->AddText(p, Hex(kAccent), Glyph(icon).c_str());
    dl->AddText(ImVec2(p.x + 26, p.y), Hex(kText), title);
    ImGui::PopFont();
    g_points[title] = ImVec4(p.x + 40, p.y + 8, 0, 0);
}

static void Rows(Row* rows, int n, float width, float pitch) {
    for (int i = 0; i < n; i++) {
        ImGui::PushID(i);
        ImVec2 p = ImGui::GetCursorScreenPos();
        ImDrawList* dl = ImGui::GetWindowDrawList();
        bool hovered = ImGui::IsMouseHoveringRect(ImVec2(p.x - 8, p.y), ImVec2(p.x + width + 8, p.y + pitch));
        if (hovered) dl->AddRectFilled(ImVec2(p.x - 8, p.y + 2), ImVec2(p.x + width + 8, p.y + pitch - 2), Hex(0xFFFFFF, 0.03f), 6);
        if (i > 0) dl->AddLine(ImVec2(p.x, p.y), ImVec2(p.x + width, p.y), Hex(0xFFFFFF, 0.05f));

        float ty = p.y + (pitch - ImGui::GetTextLineHeight()) * 0.5f;
        dl->AddText(ImVec2(p.x, ty), Hex(rows[i].on ? kText : 0xB9BBC6), rows[i].text);
        g_points[std::string("label:") + rows[i].text] = ImVec4(p.x + 30, p.y + pitch * 0.5f, 0, 0);

        if (rows[i].gear) {
            ImGui::SetCursorScreenPos(ImVec2(p.x + width - 38 - 12 - 28, p.y + (pitch - 28) * 0.5f));
            IconButton("gear", IC_GEAR);
        }
        ImGui::SetCursorScreenPos(ImVec2(p.x + width - 38, p.y + (pitch - 22) * 0.5f));
        ToggleSwitch(rows[i].text, &rows[i].on);
        ImGui::SetCursorScreenPos(ImVec2(p.x, p.y + pitch));
        ImGui::PopID();
    }
}

static bool BeginCard(const char* id, ImVec2 pos, ImVec2 size) {
    ImGui::SetCursorPos(pos);
    ImGui::PushStyleColor(ImGuiCol_ChildBg, Hex(kCard));
    ImGui::PushStyleColor(ImGuiCol_Border, Hex(kBorder));
    ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(16, 14));
    bool open = ImGui::BeginChild(id, size, ImGuiChildFlags_Borders, ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_NoScrollWithMouse);
    ImGui::PopStyleVar();
    ImGui::PopStyleColor(2);
    return open;
}

static void DrawUi() {
    ImGuiViewport* vp = ImGui::GetMainViewport();
    ImGui::SetNextWindowPos(vp->Pos);
    ImGui::SetNextWindowSize(vp->Size);
    ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(0, 0));
    ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    ImGui::Begin("nova", nullptr, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoSavedSettings |
                                      ImGuiWindowFlags_NoBringToFrontOnFocus | ImGuiWindowFlags_NoScrollWithMouse);
    ImGui::PopStyleVar(2);
    ImDrawList* dl = ImGui::GetWindowDrawList();
    const ImVec2 o = ImGui::GetWindowPos();
    const float W = vp->Size.x, H = vp->Size.y;

    // ---- 左侧图标栏
    const float railW = 60;
    dl->AddRectFilled(o, ImVec2(o.x + railW, o.y + H), Hex(kRail));
    dl->AddLine(ImVec2(o.x + railW, o.y), ImVec2(o.x + railW, o.y + H), Hex(kBorder));
    static const unsigned railIcons[] = {IC_GENERAL, IC_DISPLAY, IC_AUDIO, IC_NET, IC_KEYS, IC_LIST, IC_FOLDER};
    ImGui::PushFont(g_icons);
    for (int i = 0; i < 7; i++) {
        ImVec2 p(o.x + 10, o.y + 12 + i * 48.0f);
        ImGui::SetCursorScreenPos(p);
        ImGui::PushID(100 + i);
        if (ImGui::InvisibleButton("rail", ImVec2(40, 40))) g_rail = i;
        bool hov = ImGui::IsItemHovered();
        ImGui::PopID();
        bool sel = g_rail == i;
        if (sel) {
            dl->AddRectFilled(p, ImVec2(p.x + 40, p.y + 40), Hex(kAccent, 0.18f), 10);
            dl->AddRectFilled(ImVec2(o.x, p.y + 10), ImVec2(o.x + 3, p.y + 30), Hex(kAccent), 2);
        } else if (hov) {
            dl->AddRectFilled(p, ImVec2(p.x + 40, p.y + 40), Hex(0xFFFFFF, 0.05f), 10);
        }
        std::string g = Glyph(railIcons[i]);
        ImVec2 ts = ImGui::CalcTextSize(g.c_str());
        dl->AddText(ImVec2(p.x + (40 - ts.x) * 0.5f, p.y + (40 - ts.y) * 0.5f), Hex(sel ? 0xC9C1FF : (hov ? kText : kMuted)), g.c_str());
    }
    ImGui::PopFont();
    // 头像 + 设置
    ImVec2 av(o.x + railW * 0.5f, o.y + H - 84);
    dl->AddCircleFilled(av, 15, Hex(kAccent), 32);
    dl->AddCircle(av, 18, Hex(kAccent, 0.35f), 32, 1.5f);
    ImGui::PushFont(g_bold);
    ImVec2 ns = ImGui::CalcTextSize("N");
    dl->AddText(ImVec2(av.x - ns.x * 0.5f, av.y - ns.y * 0.5f), Hex(0xFFFFFF), "N");
    ImGui::PopFont();
    ImGui::SetCursorScreenPos(ImVec2(o.x + 16, o.y + H - 50));
    ImGui::PushFont(g_icons);
    IconButton("railgear", IC_GEAR);
    ImGui::PopFont();

    // ---- 顶部标签
    const float cx = railW + 18, cw = W - railW - 36;
    static const unsigned tabIcons[] = {IC_GENERAL, IC_DISPLAY, IC_AUDIO, IC_NET, IC_KEYS};
    static const char* tabs[] = {u8"常规", u8"画面", u8"音频", u8"网络", u8"快捷键"};
    float tx = o.x + cx;
    const float tabY = o.y + 12, tabH = 36;
    ImGui::PushFont(g_font);
    for (int i = 0; i < 5; i++) {
        std::string g = Glyph(tabIcons[i]);
        float w = 22 + ImGui::CalcTextSize(tabs[i]).x + 20;
        ImGui::SetCursorScreenPos(ImVec2(tx, tabY));
        ImGui::PushID(200 + i);
        if (ImGui::InvisibleButton("tab", ImVec2(w, tabH))) g_tab = i;
        bool hov = ImGui::IsItemHovered();
        ImGui::PopID();
        bool sel = g_tab == i;
        ImU32 col = Hex(sel ? kText : (hov ? 0xC4C6D0 : kMuted));
        float ty = tabY + (tabH - ImGui::GetTextLineHeight()) * 0.5f - 2;
        dl->AddText(ImVec2(tx + 10, ty), sel ? Hex(kAccent) : col, g.c_str());
        dl->AddText(ImVec2(tx + 32, ty), col, tabs[i]);
        if (sel) dl->AddRectFilled(ImVec2(tx + 10, tabY + tabH - 3), ImVec2(tx + w - 10, tabY + tabH), Hex(kAccent), 2);
        tx += w + 4;
    }
    ImGui::PopFont();
    dl->AddLine(ImVec2(o.x + cx, tabY + tabH), ImVec2(o.x + cx + cw, tabY + tabH), Hex(kBorder));

    // ---- 三张卡片
    const float top = tabY - o.y + tabH + 14, bottom = H - 16, gap = 12;
    const float colW = (cw - gap) / 2;
    const float inner = colW - 32;

    ImGui::PushFont(g_font);
    if (BeginCard("general", ImVec2(cx, top), ImVec2(colW, bottom - top))) {
        CardHeader(IC_GENERAL, u8"常规选项");
        ImGui::Dummy(ImVec2(0, 30));
        Rows(g_general, 10, inner, 46);
    }
    ImGui::EndChild();

    const float perfH = 14 + 30 + 5 * 40 + 12;
    if (BeginCard("perf", ImVec2(cx + colW + gap, top), ImVec2(colW, perfH))) {
        CardHeader(IC_PERF, u8"性能");
        ImGui::Dummy(ImVec2(0, 30));
        Rows(g_perf, 5, inner, 40);
    }
    ImGui::EndChild();

    const float dispTop = top + perfH + gap;
    if (BeginCard("display", ImVec2(cx + colW + gap, dispTop), ImVec2(colW, bottom - dispTop))) {
        CardHeader(IC_SUN, u8"显示");
        ImGui::Dummy(ImVec2(0, 30));
        Rows(g_display, 2, inner, 40);
        ImVec2 p = ImGui::GetCursorScreenPos();
        ImGui::GetWindowDrawList()->AddLine(ImVec2(p.x, p.y + 6), ImVec2(p.x + inner, p.y + 6), Hex(kBorder));
        ImGui::Dummy(ImVec2(0, 16));
        NovaSlider("##bright", u8"亮度", &g_bright, inner);
        ImGui::Dummy(ImVec2(0, 8));
        NovaSlider("##contrast", u8"对比度", &g_contrast, inner);
    }
    ImGui::EndChild();
    ImGui::PopFont();

    ImGui::End();
}

// ---------------------------------------------------------------- 字体

static void LoadFonts() {
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = nullptr;

    // 只烘焙界面上用到的汉字，图集很小
    static ImVector<ImWchar> ranges;
    ImFontGlyphRangesBuilder b;
    b.AddRanges(io.Fonts->GetGlyphRangesDefault());
    const char* texts[] = {u8"常规画面音频网络快捷键常规选项性能显示亮度对比度0123456789%",
                           u8"开机自启最小化到托盘自动更新硬件加速垂直同步显示帧率低延迟模式夜间模式后台静音发送使用统计",
                           u8"帧率限制动态分辨率预加载资源多线程渲染省电模式自动亮度"};
    for (const char* t : texts) b.AddText(t);
    b.BuildRanges(&ranges);
    static const ImWchar iconRange[] = {0xE700, 0xEC4F, 0};

    char winDir[MAX_PATH];
    GetWindowsDirectoryA(winDir, MAX_PATH);
    std::string fonts = std::string(winDir) + "\\Fonts\\";

    auto load = [&](const char* file, float size, float iconSize) -> ImFont* {
        ImFont* f = io.Fonts->AddFontFromFileTTF((fonts + file).c_str(), size, nullptr, ranges.Data);
        if (!f) f = io.Fonts->AddFontDefault();
        ImFontConfig cfg;
        cfg.MergeMode = true;
        cfg.PixelSnapH = true;
        cfg.GlyphOffset = ImVec2(0, 2);
        cfg.GlyphMinAdvanceX = iconSize;
        io.Fonts->AddFontFromFileTTF((fonts + "SegoeIcons.ttf").c_str(), iconSize, &cfg, iconRange);
        return f;
    };
    g_font = load("msyh.ttc", 15.0f, 16.0f);
    g_bold = load("msyhbd.ttc", 15.0f, 16.0f);
    g_icons = io.Fonts->AddFontFromFileTTF((fonts + "SegoeIcons.ttf").c_str(), 19.0f, nullptr, iconRange);
    if (!g_icons) g_icons = g_font;
}

static void ApplyStyle() {
    ImGuiStyle& s = ImGui::GetStyle();
    s.ChildRounding = 10;
    s.ChildBorderSize = 1;
    s.FrameRounding = 6;
    s.GrabRounding = 8;
    s.ItemSpacing = ImVec2(8, 0);
    ImVec4* c = s.Colors;
    c[ImGuiCol_WindowBg] = ImGui::ColorConvertU32ToFloat4(Hex(kBg));
    c[ImGuiCol_Text] = ImGui::ColorConvertU32ToFloat4(Hex(kText));
}

// ---------------------------------------------------------------- 写坐标文件（给录屏脚本）

static void WritePoints(HWND hwnd) {
    RECT fr;
    if (FAILED(DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, &fr, sizeof fr))) GetWindowRect(hwnd, &fr);
    POINT org = {0, 0};
    ClientToScreen(hwnd, &org);
    int dx = org.x - fr.left, dy = org.y - fr.top;

    wchar_t path[MAX_PATH];
    GetModuleFileNameW(nullptr, path, MAX_PATH);
    wchar_t* slash = wcsrchr(path, L'\\');
    if (slash) wcscpy_s(slash + 1, MAX_PATH - (slash + 1 - path), L"nova-points.json");
    FILE* f = nullptr;
    if (_wfopen_s(&f, path, L"wb") || !f) return;

    auto pt = [&](const char* key, const ImVec4& v, bool slider) {
        if (slider)
            fprintf(f, "  \"%s\": [%d, %d, %d, %d]", key, (int)v.x + dx, (int)v.y + dy, (int)v.z + dx, (int)v.w);
        else
            fprintf(f, "  \"%s\": [%d, %d]", key, (int)v.x + dx, (int)v.y + dy);
    };
    fprintf(f, "{\n");
    pt(u8"常规选项", g_points[std::string("label:") + u8"开机自启"], false);
    const char* toggles[] = {u8"开机自启", u8"自动更新", u8"低延迟模式", "HDR"};
    for (const char* k : toggles) { fprintf(f, ",\n"); pt(k, g_points[k], false); }
    fprintf(f, ",\n");
    pt(u8"亮度", g_points[u8"亮度"], true);
    fprintf(f, "\n}\n");
    fclose(f);
}

// ---------------------------------------------------------------- Direct3D 11（与 ImGui 官方示例相同）

static ID3D11Device* g_device = nullptr;
static ID3D11DeviceContext* g_context = nullptr;
static IDXGISwapChain* g_swapChain = nullptr;
static ID3D11RenderTargetView* g_rtv = nullptr;
static bool g_occluded = false;
static UINT g_resizeW = 0, g_resizeH = 0;

static void CreateRenderTarget() {
    ID3D11Texture2D* back = nullptr;
    g_swapChain->GetBuffer(0, IID_PPV_ARGS(&back));
    g_device->CreateRenderTargetView(back, nullptr, &g_rtv);
    back->Release();
}
static void CleanupRenderTarget() {
    if (g_rtv) { g_rtv->Release(); g_rtv = nullptr; }
}

static bool CreateDeviceD3D(HWND hwnd) {
    DXGI_SWAP_CHAIN_DESC sd = {};
    sd.BufferCount = 2;
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferDesc.RefreshRate.Numerator = 60;
    sd.BufferDesc.RefreshRate.Denominator = 1;
    sd.Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.OutputWindow = hwnd;
    sd.SampleDesc.Count = 1;
    sd.Windowed = TRUE;
    sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
    const D3D_FEATURE_LEVEL levels[2] = {D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_0};
    D3D_FEATURE_LEVEL got;
    HRESULT hr = D3D11CreateDeviceAndSwapChain(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0, levels, 2, D3D11_SDK_VERSION, &sd,
                                               &g_swapChain, &g_device, &got, &g_context);
    if (hr == DXGI_ERROR_UNSUPPORTED)  // 没有显卡（比如虚拟机）时用 WARP 软件渲染
        hr = D3D11CreateDeviceAndSwapChain(nullptr, D3D_DRIVER_TYPE_WARP, nullptr, 0, levels, 2, D3D11_SDK_VERSION, &sd,
                                           &g_swapChain, &g_device, &got, &g_context);
    if (hr != S_OK) return false;
    CreateRenderTarget();
    return true;
}

static void CleanupDeviceD3D() {
    CleanupRenderTarget();
    if (g_swapChain) { g_swapChain->Release(); g_swapChain = nullptr; }
    if (g_context) { g_context->Release(); g_context = nullptr; }
    if (g_device) { g_device->Release(); g_device = nullptr; }
}

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

static LRESULT WINAPI WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (ImGui_ImplWin32_WndProcHandler(hwnd, msg, wp, lp)) return true;
    switch (msg) {
    case WM_SIZE:
        if (wp == SIZE_MINIMIZED) return 0;
        g_resizeW = (UINT)LOWORD(lp);
        g_resizeH = (UINT)HIWORD(lp);
        return 0;
    case WM_SYSCOMMAND:
        if ((wp & 0xfff0) == SC_KEYMENU) return 0;  // 不要 Alt 菜单
        break;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

// ---------------------------------------------------------------- 入口

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE, PWSTR, int) {
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

    WNDCLASSEXW wc = {sizeof(wc), CS_CLASSDC, WndProc, 0, 0, inst, nullptr, LoadCursor(nullptr, IDC_ARROW), nullptr, nullptr, L"NovaImGui", nullptr};
    RegisterClassExW(&wc);

    // 客户区 904 x 621，和其它版本看得见的窗口大小一致（906 x 653）
    const DWORD style = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX;
    RECT r = {0, 0, 904, 621};
    AdjustWindowRectEx(&r, style, FALSE, 0);
    HWND hwnd = CreateWindowExW(0, wc.lpszClassName, L"Nova 设置 — Dear ImGui", style, CW_USEDEFAULT, CW_USEDEFAULT,
                                r.right - r.left, r.bottom - r.top, nullptr, nullptr, inst, nullptr);
    BOOL dark = TRUE;
    DwmSetWindowAttribute(hwnd, 20 /* DWMWA_USE_IMMERSIVE_DARK_MODE */, &dark, sizeof dark);

    if (!CreateDeviceD3D(hwnd)) {
        CleanupDeviceD3D();
        return 1;
    }
    ShowWindow(hwnd, SW_SHOWDEFAULT);
    UpdateWindow(hwnd);

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    LoadFonts();
    ApplyStyle();
    ImGui_ImplWin32_Init(hwnd);
    ImGui_ImplDX11_Init(g_device, g_context);

    const ImVec4 bg = ImGui::ColorConvertU32ToFloat4(Hex(kBg));
    const float clear[4] = {bg.x, bg.y, bg.z, 1.0f};
    int frame = 0;
    bool done = false;
    while (!done) {
        MSG msg;
        while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
            if (msg.message == WM_QUIT) done = true;
        }
        if (done) break;
        if (g_occluded && g_swapChain->Present(0, DXGI_PRESENT_TEST) == DXGI_STATUS_OCCLUDED) {
            Sleep(10);
            continue;
        }
        g_occluded = false;
        if (g_resizeW && g_resizeH) {
            CleanupRenderTarget();
            g_swapChain->ResizeBuffers(0, g_resizeW, g_resizeH, DXGI_FORMAT_UNKNOWN, 0);
            g_resizeW = g_resizeH = 0;
            CreateRenderTarget();
        }

        ImGui_ImplDX11_NewFrame();
        ImGui_ImplWin32_NewFrame();
        ImGui::NewFrame();
        DrawUi();
        ImGui::Render();
        g_context->OMSetRenderTargets(1, &g_rtv, nullptr);
        g_context->ClearRenderTargetView(g_rtv, clear);
        ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
        HRESULT hr = g_swapChain->Present(1, 0);  // 垂直同步
        g_occluded = (hr == DXGI_STATUS_OCCLUDED);

        if (++frame == 5) WritePoints(hwnd);
    }

    ImGui_ImplDX11_Shutdown();
    ImGui_ImplWin32_Shutdown();
    ImGui::DestroyContext();
    CleanupDeviceD3D();
    DestroyWindow(hwnd);
    return 0;
}
