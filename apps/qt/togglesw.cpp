#include "togglesw.h"

#include <QEasingCurve>
#include <QEnterEvent>
#include <QPainter>
#include <QPen>
#include <QPropertyAnimation>

namespace {

// 两个颜色之间按 t（0..1）插值，开关滑动时颜色也跟着渐变
QColor mix(const QColor &a, const QColor &b, qreal t)
{
    return QColor(a.red() + qRound((b.red() - a.red()) * t),
                  a.green() + qRound((b.green() - a.green()) * t),
                  a.blue() + qRound((b.blue() - a.blue()) * t));
}

} // namespace

ToggleSwitch::ToggleSwitch(QWidget *parent)
    : QAbstractButton(parent), m_accent(0x41, 0xcd, 0x52)
{
    setCheckable(true);
    setCursor(Qt::PointingHandCursor);
    setSizePolicy(QSizePolicy::Fixed, QSizePolicy::Fixed);

    m_anim = new QPropertyAnimation(this, "offset", this);
    m_anim->setDuration(150);
    m_anim->setEasingCurve(QEasingCurve::InOutCubic);

    connect(this, &QAbstractButton::toggled, this, [this](bool on) {
        const qreal target = on ? 1.0 : 0.0;
        m_anim->stop();
        if (!isVisible()) {  // 还没显示（初始化时）：直接到位，不播动画
            setOffset(target);
            return;
        }
        m_anim->setStartValue(m_offset);
        m_anim->setEndValue(target);
        m_anim->start();
    });
}

QSize ToggleSwitch::sizeHint() const
{
    return QSize(40, 22);
}

void ToggleSwitch::setOffset(qreal value)
{
    m_offset = value;
    update();
}

void ToggleSwitch::setAccent(const QColor &color)
{
    m_accent = color;
    update();
}

void ToggleSwitch::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing);

    const qreal t = m_offset;

    // 轨道：关的时候是深色底 + 灰色描边，开的时候整条变成强调色
    QRectF track(0, 0, 40, 20);
    track.moveCenter(QRectF(rect()).center());
    track.adjust(0.5, 0.5, -0.5, -0.5);  // 1 像素描边落在像素中间，边缘更清楚
    const qreal radius = track.height() / 2;

    const QColor fillOff(0x23, 0x26, 0x2e);
    const QColor borderOff(hasFocus() ? QColor(0x8a, 0x90, 0x9c) : QColor(0x6b, 0x71, 0x7e));
    p.setPen(QPen(mix(borderOff, m_accent, t), 1.0));
    p.setBrush(mix(fillOff, m_accent, t));
    p.drawRoundedRect(track, radius, radius);

    // 圆点：从左滑到右，鼠标悬停或按下时稍微变大
    const qreal knob = isDown() ? 7.5 : (m_hover ? 7.0 : 6.0);
    const qreal x = track.left() + radius + (track.width() - 2 * radius) * t;
    p.setPen(Qt::NoPen);
    p.setBrush(mix(QColor(0xa6, 0xab, 0xb5), QColor(0x0f, 0x11, 0x15), t));
    p.drawEllipse(QPointF(x, track.center().y()), knob, knob);
}

void ToggleSwitch::enterEvent(QEnterEvent *event)
{
    m_hover = true;
    update();
    QAbstractButton::enterEvent(event);
}

void ToggleSwitch::leaveEvent(QEvent *event)
{
    m_hover = false;
    update();
    QAbstractButton::leaveEvent(event);
}
