// InputField.qml — campo de entrada "pílula" (sem QtQuick.Controls).
// Borda acende no accent ao focar; placeholder próprio; modo senha opcional.
import QtQuick 2.15
import "../Colors.js" as Colors

Rectangle {
    id: field
    property alias text: input.text
    property string placeholder: ""
    property bool echo: false
    signal accepted()

    function focusInput() { input.forceActiveFocus() }

    width: parent ? parent.width : 280
    height: 46
    radius: 12
    color: Colors.background
    border.color: input.activeFocus ? Colors.accent : Colors.border
    border.width: input.activeFocus ? 2 : 1
    Behavior on border.color { ColorAnimation { duration: 120 } }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        verticalAlignment: TextInput.AlignVCenter
        color: Colors.text
        font.pixelSize: 16
        clip: true
        echoMode: field.echo ? TextInput.Password : TextInput.Normal
        passwordCharacter: "•"
        selectionColor: Colors.accent
        selectedTextColor: Colors.background
        activeFocusOnTab: true
        onAccepted: field.accepted()
    }

    Text {
        anchors.left: input.left
        anchors.verticalCenter: input.verticalCenter
        text: field.placeholder
        color: Colors.muted
        font.pixelSize: 16
        visible: input.text.length === 0 && !input.activeFocus
    }
}
