import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: chip

    property string label: ""
    property string value: ""
    property color labelColor: "#708299"
    property color valueColor: "#f3f8fc"
    property color surfaceColor: "#1a2433"
    property color borderColor: "#2c4158"

    radius: 12
    color: surfaceColor
    border.width: 1
    border.color: borderColor
    implicitHeight: 60

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 2

        Text {
            text: chip.label
            color: chip.labelColor
            font.family: "Noto Sans"
            font.pointSize: 8
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.1
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Text {
            text: chip.value
            color: chip.valueColor
            font.family: "Noto Sans"
            font.pointSize: 11
            font.bold: true
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }
}
