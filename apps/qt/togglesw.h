// 自己画的开关控件：继承 QAbstractButton（自带“可勾选”、键盘和无障碍支持），
// paintEvent 里用 QPainter 画轨道和圆点，QPropertyAnimation 让圆点滑过去。
#pragma once

#include <QAbstractButton>
#include <QColor>

class QPropertyAnimation;

class ToggleSwitch : public QAbstractButton
{
    Q_OBJECT
    // 0 = 关，1 = 开；动画改的就是这个属性
    Q_PROPERTY(qreal offset READ offset WRITE setOffset)

public:
    explicit ToggleSwitch(QWidget *parent = nullptr);

    QSize sizeHint() const override;

    qreal offset() const { return m_offset; }
    void setOffset(qreal value);

    void setAccent(const QColor &color);

protected:
    void paintEvent(QPaintEvent *event) override;
    void enterEvent(QEnterEvent *event) override;
    void leaveEvent(QEvent *event) override;

private:
    qreal m_offset = 0.0;
    bool m_hover = false;
    QColor m_accent;
    QPropertyAnimation *m_anim = nullptr;
};
