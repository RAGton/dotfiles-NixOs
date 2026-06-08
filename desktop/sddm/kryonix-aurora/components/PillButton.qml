// PillButton.qml — botão accent "pílula" (sem QtQuick.Controls).
import QtQuick 2.15
import "../Colors.js" as Colors

Rectangle {
    id: btn
    property string text: ""
    signal clicked()

    width: parent ? parent.width : 280
    height: 46
    radius: 12
    color: ma.pressed
           ? Colors.accentStrong
           : (ma.containsMouse ? Qt.lighter(Colors.accent, 1.1) : Colors.accent)
    Behavior on color { ColorAnimation { duration: 120 } }
    scale: ma.pressed ? 0.985 : 1.0
    Behavior on scale { NumberAnimation { duration: 80 } }

    Text {
        anchors.centerIn: parent
        text: btn.text
        color: Colors.background
        font.pixelSize: 16
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
