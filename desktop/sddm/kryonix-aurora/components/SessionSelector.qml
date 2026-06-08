// SessionSelector.qml — escolha de sessão (chips a partir do sessionModel).
// Cada chip lê o role "name" direto no delegate (sem indexar o modelo na mão).
// currentIndex é lido pelo Main e passado ao sddm.login(...).
import QtQuick 2.15
import "../Colors.js" as Colors

Row {
    id: sel
    spacing: 10

    property int currentIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0)
                               ? sessionModel.lastIndex : 0

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Sessão"
        color: Colors.muted
        font.pixelSize: 13
    }

    Repeater {
        model: sessionModel
        delegate: Rectangle {
            property bool active: index === sel.currentIndex
            height: 30
            width: label.implicitWidth + 24
            radius: 15
            color: active ? Colors.surfaceAlt : "transparent"
            border.color: active ? Colors.accent : Colors.border
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
                id: label
                anchors.centerIn: parent
                text: model.name
                color: active ? Colors.text : Colors.muted
                font.pixelSize: 13
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sel.currentIndex = index
            }
        }
    }
}
