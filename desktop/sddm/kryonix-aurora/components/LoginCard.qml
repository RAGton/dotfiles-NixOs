// LoginCard.qml — card de login (zona direita).
// Mostra o AVATAR REAL do usuário (userModel.icon, recortado em círculo via
// OpacityMask), nome, campo de senha e Entrar. Setas trocam de usuário quando
// há mais de um. Login via sddm.login(name, senha, sessionIndex).
import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import "../Colors.js" as Colors

Rectangle {
    id: card
    width: 340
    height: content.implicitHeight + 56
    radius: 20
    color: Colors.surface
    border.color: Colors.border
    border.width: 1

    property int sessionIndex: 0

    // --- Usuários: array {name, realName, icon} montado a partir do userModel ---
    property var users: []
    property int userIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0)
                            ? userModel.lastIndex : 0
    property var currentUser: (users.length > 0 && userIndex >= 0 && userIndex < users.length)
                              ? users[userIndex]
                              : ({ name: "", realName: "", icon: "" })

    Repeater {
        model: userModel
        Item {
            Component.onCompleted: {
                var a = card.users.slice()
                a[index] = {
                    name: ("" + model.name),
                    realName: (model.realName && ("" + model.realName).length > 0)
                              ? ("" + model.realName) : ("" + model.name),
                    icon: ("" + model.icon)
                }
                card.users = a
            }
        }
    }

    function takeFocus() { passwordField.focusInput() }
    function doLogin() {
        errorText.text = ""
        var u = (card.currentUser.name && card.currentUser.name.length > 0)
                ? card.currentUser.name
                : ((typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : "")
        sddm.login(u, passwordField.text, card.sessionIndex)
    }

    // Shake horizontal em falha (transform, não interfere nas âncoras).
    transform: Translate { id: shakeT; x: 0 }
    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeT; property: "x"; to: 12;  duration: 50 }
        NumberAnimation { target: shakeT; property: "x"; to: -12; duration: 50 }
        NumberAnimation { target: shakeT; property: "x"; to: 6;   duration: 50 }
        NumberAnimation { target: shakeT; property: "x"; to: 0;   duration: 50 }
    }

    Connections {
        target: sddm
        function onLoginSucceeded() { errorText.text = "" }
        function onLoginFailed() {
            errorText.text = "Usuário ou senha inválidos"
            passwordField.text = ""
            passwordField.focusInput()
            shake.restart()
        }
        function onInformationMessage(message) { errorText.text = message }
    }

    Column {
        id: content
        anchors.centerIn: parent
        width: parent.width - 48
        spacing: 14

        // ---- Avatar real + setas (multiusuário) ----
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: card.users.length > 1
                text: "‹"
                color: Colors.muted
                font.pixelSize: 30
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.userIndex = (card.userIndex - 1 + card.users.length) % card.users.length
                }
            }

            Item {
                id: avatarBox
                width: 96
                height: 96
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: (card.currentUser.icon && card.currentUser.icon.length > 0)
                            ? card.currentUser.icon : "../assets/avatar.svg"
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(96, 96)
                    visible: false
                    onStatusChanged: if (status === Image.Error) source = "../assets/avatar.svg"
                }
                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }
                OpacityMask {
                    anchors.fill: parent
                    source: avatarImg
                    maskSource: avatarMask
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: Colors.accent
                    border.width: 2
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: card.users.length > 1
                text: "›"
                color: Colors.muted
                font.pixelSize: 30
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.userIndex = (card.userIndex + 1) % card.users.length
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (card.currentUser.realName && card.currentUser.realName.length > 0)
                  ? card.currentUser.realName : "Usuário"
            color: Colors.text
            font.pixelSize: 19
            font.weight: Font.Medium
            bottomPadding: 2
        }

        InputField {
            id: passwordField
            placeholder: "Senha"
            echo: true
            onAccepted: card.doLogin()
        }

        Text {
            id: capsHint
            anchors.horizontalCenter: parent.horizontalCenter
            visible: (typeof keyboard !== "undefined") && keyboard.capsLock
            text: "Caps Lock ativado"
            color: Colors.muted
            font.pixelSize: 12
        }

        Text {
            id: errorText
            anchors.horizontalCenter: parent.horizontalCenter
            text: ""
            visible: text.length > 0
            color: Colors.danger
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.WordWrap
        }

        PillButton {
            text: "Entrar"
            onClicked: card.doLogin()
        }
    }
}
