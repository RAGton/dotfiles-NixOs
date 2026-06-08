// Clock.qml — relógio + data (atualiza a cada segundo).
import QtQuick 2.15
import "../Colors.js" as Colors

Column {
    id: clock
    spacing: 2
    property var now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.now = new Date()
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(clock.now, "HH:mm")
        color: Colors.text
        font.pixelSize: 76
        font.weight: Font.Light
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(clock.now, "dddd, dd 'de' MMMM")
        color: Colors.muted
        font.pixelSize: 18
        font.capitalization: Font.Capitalize
    }
}
