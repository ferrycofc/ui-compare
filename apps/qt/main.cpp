// Nova 设置面板 —— Qt Widgets（C++）
//
// 同一份 C++ 代码可以编译到 Windows / macOS / Linux。这里拿出 Qt Widgets 最拿手的几样：
//   · Fusion 风格 + 深色 QPalette：外观不跟系统主题走，各平台一模一样
//   · QSS 样式表（写法像 CSS）：卡片、标签页、滑块、按钮都靠它换装
//   · QPainter 自绘：带动画的开关、头像，以及用 Segoe Fluent Icons 字体画出来的图标

#include <QApplication>
#include <QColor>
#include <QFont>
#include <QFrame>
#include <QHBoxLayout>
#include <QIcon>
#include <QLabel>
#include <QPainter>
#include <QPalette>
#include <QPixmap>
#include <QSlider>
#include <QString>
#include <QStringList>
#include <QStyleHints>
#include <QTabBar>
#include <QToolButton>
#include <QVBoxLayout>
#include <QWidget>

#include <iterator>

#include "togglesw.h"

// ---------- 配色 ----------
static const QColor kAccent(0x41, 0xcd, 0x52);  // Qt 品牌绿
static const QColor kText(0xe6, 0xe8, 0xee);
static const QColor kMuted(0x9a, 0xa0, 0xab);
static const QColor kWindow(0x13, 0x14, 0x18);
static const QColor kCard(0x1b, 0x1d, 0x23);

// QSS 样式表：和网页 CSS 很像，按 objectName（#xxx）和子控件（::tab、::handle）选中
static const char kStyleSheet[] = R"(
QFrame#rail { background: #0f1013; border: none; border-right: 1px solid #22252c; }
QToolButton#railButton { border: none; border-radius: 8px; background: transparent; }
QToolButton#railButton:hover { background: #1c1f26; }
QToolButton#railButton:checked { background: #1a2a1e; }

QTabBar::tab {
    background: transparent; color: #9aa0ab; border: none;
    border-bottom: 2px solid transparent;
    padding: 6px 12px 8px 10px; margin-right: 4px;
}
QTabBar::tab:hover:!selected { color: #cfd3da; }
QTabBar::tab:selected { color: #e6e8ee; border-bottom: 2px solid #41cd52; }

QFrame#card { background: #1b1d23; border: 1px solid #2a2d36; border-radius: 10px; }
QFrame#divider { background: #2a2d36; border: none; }
QLabel#value { color: #9aa0ab; }

QToolButton#gear { border: none; border-radius: 6px; background: transparent; }
QToolButton#gear:hover { background: #2a2d36; }
QToolButton#gear:pressed { background: #323642; }

QSlider::groove:horizontal { height: 4px; border-radius: 2px; background: #3a3e49; }
QSlider::sub-page:horizontal { height: 4px; border-radius: 2px; background: #41cd52; }
QSlider::add-page:horizontal { height: 4px; border-radius: 2px; background: #3a3e49; }
QSlider::handle:horizontal {
    width: 12px; height: 12px; margin: -7px 0;
    border-radius: 9px; border: 3px solid #1b1d23; background: #41cd52;
}
QSlider::handle:horizontal:hover { background: #63e070; }

QToolTip { color: #e6e8ee; background: #23262e; border: 1px solid #343846; padding: 4px 6px; }
)";

// ---------- 内容（和其它技术完全一样） ----------
struct ToggleRow { const char *text; bool gear; bool on; };

static const ToggleRow kGeneral[] = {
    {"开机自启", true, true},   {"最小化到托盘", true, true}, {"自动更新", true, false},
    {"硬件加速", true, true},   {"垂直同步", true, false},   {"显示帧率", true, false},
    {"低延迟模式", true, false}, {"夜间模式", false, true},  {"后台静音", false, false},
    {"发送使用统计", false, false},
};
static const ToggleRow kPerf[] = {
    {"帧率限制", true, true}, {"动态分辨率", true, false}, {"预加载资源", true, false},
    {"多线程渲染", true, true}, {"省电模式", true, false},
};
static const ToggleRow kDisplay[] = {{"自动亮度", false, false}, {"HDR", false, true}};

// Segoe Fluent Icons 码位
struct NavItem { char16_t glyph; const char *text; };
static const NavItem kNav[] = {
    {0xE9E9, "常规"}, {0xE7F4, "画面"}, {0xE767, "音频"}, {0xE774, "网络"},
    {0xE765, "快捷键"}, {0xE8FD, "列表"}, {0xE8B7, "文件夹"},
};
static const char16_t kGlyphGear = 0xE713;
static const char16_t kGlyphPerf = 0xEC4A;
static const char16_t kGlyphDisplay = 0xE706;

static void forceDarkTitleBar(QWidget &window);  // 在文件末尾（Win32 部分）

static QString tr8(const char *s) { return QString::fromUtf8(s); }

// ---------- QPainter 画图标 ----------
// 把图标字体里的一个字画到透明 QPixmap 上（按屏幕缩放比例画，高 DPI 下也清楚）
static QPixmap glyphPixmap(char16_t cp, const QColor &color, int size)
{
    const qreal dpr = qApp->devicePixelRatio();
    const int px = qRound(size * dpr);
    QPixmap pm(px, px);
    pm.setDevicePixelRatio(dpr);
    pm.fill(Qt::transparent);

    QPainter p(&pm);
    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::TextAntialiasing);
    QFont f;
    f.setFamilies(QStringList{QStringLiteral("Segoe Fluent Icons"), QStringLiteral("Segoe MDL2 Assets")});
    f.setPixelSize(size);
    p.setFont(f);
    p.setPen(color);
    p.drawText(QRectF(0, 0, size, size), Qt::AlignCenter, QString(QChar(cp)));
    return pm;
}

// 普通状态一种颜色；悬停（Active）和选中（On）可以换颜色
static QIcon glyphIcon(char16_t cp, const QColor &normal, int size,
                       const QColor &hover = QColor(), const QColor &on = QColor())
{
    QIcon icon;
    icon.addPixmap(glyphPixmap(cp, normal, size), QIcon::Normal, QIcon::Off);
    if (hover.isValid())
        icon.addPixmap(glyphPixmap(cp, hover, size), QIcon::Active, QIcon::Off);
    if (on.isValid()) {
        icon.addPixmap(glyphPixmap(cp, on, size), QIcon::Normal, QIcon::On);
        icon.addPixmap(glyphPixmap(cp, on, size), QIcon::Active, QIcon::On);
    }
    return icon;
}

// 头像：强调色圆形 + 首字母 N
static QPixmap avatarPixmap(int size)
{
    const qreal dpr = qApp->devicePixelRatio();
    const int px = qRound(size * dpr);
    QPixmap pm(px, px);
    pm.setDevicePixelRatio(dpr);
    pm.fill(Qt::transparent);

    QPainter p(&pm);
    p.setRenderHint(QPainter::Antialiasing);
    p.setPen(Qt::NoPen);
    p.setBrush(kAccent);
    p.drawEllipse(QRectF(0.5, 0.5, size - 1.0, size - 1.0));
    QFont f = QApplication::font();
    f.setPixelSize(qRound(size * 0.46));
    f.setBold(true);
    p.setFont(f);
    p.setPen(QColor(0x0f, 0x11, 0x15));
    p.drawText(QRectF(0, 0, size, size), Qt::AlignCenter, QStringLiteral("N"));
    return pm;
}

// ---------- 界面 ----------
static QWidget *buildRail()
{
    auto *rail = new QFrame;
    rail->setObjectName(QStringLiteral("rail"));
    rail->setFixedWidth(56);
    auto *v = new QVBoxLayout(rail);
    v->setContentsMargins(8, 10, 8, 12);
    v->setSpacing(4);

    // 可勾选 + autoExclusive：同一个父控件下的按钮自动变成“单选”
    bool first = true;
    for (const NavItem &it : kNav) {
        auto *b = new QToolButton;
        b->setObjectName(QStringLiteral("railButton"));
        b->setIcon(glyphIcon(it.glyph, kMuted, 20, kText, kAccent));
        b->setIconSize(QSize(20, 20));
        b->setFixedSize(40, 40);
        b->setCheckable(true);
        b->setAutoExclusive(true);
        b->setChecked(first);
        b->setToolTip(tr8(it.text));
        b->setAccessibleName(tr8(it.text));
        b->setFocusPolicy(Qt::NoFocus);
        v->addWidget(b, 0, Qt::AlignHCenter);
        first = false;
    }
    v->addStretch(1);

    auto *avatar = new QLabel;
    avatar->setPixmap(avatarPixmap(28));
    avatar->setFixedSize(28, 28);
    avatar->setToolTip(QStringLiteral("Nova"));
    v->addWidget(avatar, 0, Qt::AlignHCenter);
    v->addSpacing(10);

    auto *settings = new QToolButton;
    settings->setObjectName(QStringLiteral("railButton"));
    settings->setIcon(glyphIcon(kGlyphGear, kMuted, 20, kText));
    settings->setIconSize(QSize(20, 20));
    settings->setFixedSize(40, 40);
    settings->setToolTip(tr8("设置"));
    settings->setAccessibleName(tr8("设置"));
    settings->setFocusPolicy(Qt::NoFocus);
    v->addWidget(settings, 0, Qt::AlignHCenter);
    return rail;
}

static QTabBar *buildTabs()
{
    auto *tabs = new QTabBar;
    tabs->setDocumentMode(true);
    tabs->setDrawBase(false);
    tabs->setExpanding(false);
    tabs->setUsesScrollButtons(false);
    tabs->setIconSize(QSize(16, 16));
    tabs->setFocusPolicy(Qt::NoFocus);
    for (int i = 0; i < 5; ++i)  // 顶部只要前 5 个：常规、画面、音频、网络、快捷键
        tabs->addTab(glyphIcon(kNav[i].glyph, kMuted, 16, QColor(), kAccent), tr8(kNav[i].text));
    tabs->setCurrentIndex(0);
    return tabs;
}

// 卡片：QFrame + QSS 圆角边框；标题行 = 图标 + 粗体字
static QFrame *makeCard(char16_t glyph, const char *title, QVBoxLayout **body)
{
    auto *card = new QFrame;
    card->setObjectName(QStringLiteral("card"));
    auto *v = new QVBoxLayout(card);
    v->setContentsMargins(16, 10, 12, 10);
    v->setSpacing(0);

    auto *head = new QWidget;
    head->setFixedHeight(34);
    auto *h = new QHBoxLayout(head);
    h->setContentsMargins(0, 0, 0, 0);
    h->setSpacing(10);
    auto *icon = new QLabel;
    icon->setPixmap(glyphPixmap(glyph, kAccent, 16));
    icon->setFixedSize(16, 16);
    auto *text = new QLabel(tr8(title));
    QFont f = text->font();
    f.setBold(true);
    text->setFont(f);
    h->addWidget(icon);
    h->addWidget(text);
    h->addStretch(1);
    v->addWidget(head);
    v->addSpacing(2);

    *body = v;
    return card;
}

// 一行：文字 …… [齿轮] [开关]
static void addRows(QVBoxLayout *body, const ToggleRow *rows, int count)
{
    for (int i = 0; i < count; ++i) {
        const QString text = tr8(rows[i].text);
        auto *row = new QWidget;
        row->setFixedHeight(38);
        auto *h = new QHBoxLayout(row);
        h->setContentsMargins(0, 0, 0, 0);
        h->setSpacing(8);
        h->addWidget(new QLabel(text), 1);

        if (rows[i].gear) {
            auto *gear = new QToolButton;
            gear->setObjectName(QStringLiteral("gear"));
            gear->setAutoRaise(true);
            gear->setIcon(glyphIcon(kGlyphGear, kMuted, 16, kText));
            gear->setIconSize(QSize(16, 16));
            gear->setFixedSize(28, 28);
            gear->setToolTip(text + tr8("设置"));
            gear->setFocusPolicy(Qt::NoFocus);
            h->addWidget(gear);
        }

        auto *sw = new ToggleSwitch;
        sw->setAccent(kAccent);
        sw->setChecked(rows[i].on);
        sw->setAccessibleName(text);  // UI Automation 按这个名字找开关
        h->addWidget(sw);

        body->addWidget(row);
    }
}

// 滑块：上面一行“名字 …… NN%”，下面是 QSlider，拖动时实时更新百分比
static void addSlider(QVBoxLayout *body, const char *name, int value)
{
    const QString text = tr8(name);
    auto *head = new QWidget;
    head->setFixedHeight(22);
    auto *h = new QHBoxLayout(head);
    h->setContentsMargins(0, 0, 4, 0);
    h->addWidget(new QLabel(text), 1);
    auto *val = new QLabel(QStringLiteral("%1%").arg(value));
    val->setObjectName(QStringLiteral("value"));
    val->setAlignment(Qt::AlignRight | Qt::AlignVCenter);
    h->addWidget(val);
    body->addWidget(head);

    auto *slider = new QSlider(Qt::Horizontal);
    slider->setRange(0, 100);
    slider->setValue(value);
    slider->setPageStep(10);
    slider->setFixedHeight(28);
    slider->setAccessibleName(text);
    QObject::connect(slider, &QSlider::valueChanged, val,
                     [val](int v) { val->setText(QStringLiteral("%1%").arg(v)); });
    body->addWidget(slider);
    body->addSpacing(4);
}

static QPalette darkPalette()
{
    QPalette pal;
    pal.setColor(QPalette::Window, kWindow);
    pal.setColor(QPalette::WindowText, kText);
    pal.setColor(QPalette::Base, kCard);
    pal.setColor(QPalette::AlternateBase, QColor(0x22, 0x25, 0x2c));
    pal.setColor(QPalette::Text, kText);
    pal.setColor(QPalette::PlaceholderText, kMuted);
    pal.setColor(QPalette::Button, QColor(0x23, 0x26, 0x2e));
    pal.setColor(QPalette::ButtonText, kText);
    pal.setColor(QPalette::BrightText, Qt::white);
    pal.setColor(QPalette::Light, QColor(0x3a, 0x3e, 0x49));
    pal.setColor(QPalette::Midlight, QColor(0x2e, 0x32, 0x3b));
    pal.setColor(QPalette::Mid, QColor(0x2a, 0x2d, 0x36));
    pal.setColor(QPalette::Dark, QColor(0x0f, 0x10, 0x13));
    pal.setColor(QPalette::Shadow, Qt::black);
    pal.setColor(QPalette::Highlight, kAccent);
    pal.setColor(QPalette::HighlightedText, QColor(0x0f, 0x11, 0x15));
    pal.setColor(QPalette::Link, kAccent);
    pal.setColor(QPalette::Accent, kAccent);
    pal.setColor(QPalette::ToolTipBase, QColor(0x23, 0x26, 0x2e));
    pal.setColor(QPalette::ToolTipText, kText);
    pal.setColor(QPalette::Disabled, QPalette::WindowText, kMuted);
    pal.setColor(QPalette::Disabled, QPalette::Text, kMuted);
    pal.setColor(QPalette::Disabled, QPalette::ButtonText, kMuted);
    return pal;
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    // 深色：告诉 Qt 用深色方案（标题栏也会跟着变深），再换成 Fusion 风格 + 自己的调色板
    QGuiApplication::styleHints()->setColorScheme(Qt::ColorScheme::Dark);
    QApplication::setStyle(QStringLiteral("Fusion"));
    QApplication::setPalette(darkPalette());
    QFont font;
    font.setFamilies(QStringList{QStringLiteral("Segoe UI"), QStringLiteral("Microsoft YaHei UI")});
    font.setPixelSize(14);
    QApplication::setFont(font);
    app.setStyleSheet(QString::fromUtf8(kStyleSheet));

    QWidget window;
    window.setWindowTitle(tr8("Nova 设置 — Qt Widgets"));

    auto *root = new QHBoxLayout(&window);
    root->setContentsMargins(0, 0, 0, 0);
    root->setSpacing(0);
    root->addWidget(buildRail());

    auto *content = new QVBoxLayout;
    content->setContentsMargins(16, 8, 16, 14);
    content->setSpacing(10);
    root->addLayout(content, 1);

    content->addWidget(buildTabs(), 0, Qt::AlignLeft);

    auto *columns = new QHBoxLayout;
    columns->setSpacing(12);
    content->addLayout(columns, 1);

    // 左：常规选项（占满整列高度）
    QVBoxLayout *body = nullptr;
    QFrame *general = makeCard(kNav[0].glyph, "常规选项", &body);
    addRows(body, kGeneral, int(std::size(kGeneral)));
    body->addStretch(1);
    columns->addWidget(general, 1);

    // 右：性能 + 显示
    auto *right = new QVBoxLayout;
    right->setSpacing(12);
    columns->addLayout(right, 1);

    QFrame *perf = makeCard(kGlyphPerf, "性能", &body);
    addRows(body, kPerf, int(std::size(kPerf)));
    right->addWidget(perf);

    QFrame *display = makeCard(kGlyphDisplay, "显示", &body);
    addRows(body, kDisplay, int(std::size(kDisplay)));
    body->addSpacing(6);
    auto *divider = new QFrame;
    divider->setObjectName(QStringLiteral("divider"));
    divider->setFixedHeight(1);
    body->addWidget(divider);
    body->addSpacing(8);
    addSlider(body, "亮度", 80);
    addSlider(body, "对比度", 35);
    right->addWidget(display);
    right->addStretch(1);

    // Windows 上 setFixedSize 设的是客户区：904 x 621 + 边框 1 + 标题栏 31 ≈ 看得见的 906 x 653
    window.setFixedSize(904, 621);
    forceDarkTitleBar(window);
    window.show();
    return app.exec();
}

// ---------- Win32：强制深色标题栏 ----------
// 放在文件最后再包含 windows.h，免得它的宏影响上面的 Qt 代码
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <dwmapi.h>

static void forceDarkTitleBar(QWidget &window)
{
    const BOOL dark = TRUE;  // 20 = DWMWA_USE_IMMERSIVE_DARK_MODE
    DwmSetWindowAttribute(reinterpret_cast<HWND>(window.winId()), 20, &dark, sizeof(dark));
}
#else
static void forceDarkTitleBar(QWidget &) {}
#endif
