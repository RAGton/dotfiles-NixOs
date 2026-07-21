import QtQuick 2.15
import QtQuick.Controls 2.15

Button {
    id: control

    property color accentColor: "#4ba3ff"
    property color surfaceColor: "#162232"
    property color surfaceBorderColor: "#29405a"
    property color textColor: "#f3f8fc"
    property color primaryTextColor: "#041420"
    property bool primary: false

    implicitHeight: 46
    implicitWidth: primary ? 168 : 116
    hoverEnabled: true

    font.family: "Noto Sans"
    font.pointSize: 11

    contentItem: Text {
        text: control.text
        color: control.primary ? control.primaryTextColor : control.textColor
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: 12
        border.width: 1
        border.color: control.primary ? Qt.lighter(control.accentColor, 1.05) : control.surfaceBorderColor
        color: control.primary ? control.accentColor : control.surfaceColor

        Behavior on color {
            ColorAnimation { duration: 140 }
        }

        Behavior on border.color {
            ColorAnimation { duration: 140 }
        }
    }

    states: [
        State {
            name: "disabled"
            when: !control.enabled
            PropertyChanges {
                target: control
                opacity: 0.45
            }
        },
        State {
            name: "pressed"
            when: control.down
            PropertyChanges {
                target: control.background
                color: control.primary ? Qt.darker(control.accentColor, 1.18) : Qt.lighter(control.surfaceColor, 1.08)
                border.color: control.primary ? Qt.darker(control.accentColor, 1.08) : Qt.lighter(control.surfaceBorderColor, 1.12)
            }
        },
        State {
            name: "hovered"
            when: control.hovered
            PropertyChanges {
                target: control.background
                color: control.primary ? Qt.lighter(control.accentColor, 1.06) : Qt.lighter(control.surfaceColor, 1.12)
                border.color: control.primary ? Qt.lighter(control.accentColor, 1.06) : Qt.lighter(control.surfaceBorderColor, 1.18)
            }
        },
        State {
            name: "focused"
            when: control.visualFocus
            PropertyChanges {
                target: control.background
                border.color: control.accentColor
            }
        }
    ]
}
