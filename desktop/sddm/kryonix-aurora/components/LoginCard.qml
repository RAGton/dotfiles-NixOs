// LoginCard.qml — card central de login.
// Avatar + usuário (pré-preenchido com userModel.lastUser) + senha + Entrar.
// Conecta nos sinais do `sddm` para erro/sucesso. Enter na senha faz login.
import QtQuick 2.15
import "../Colors.js" as Colors

Rectangle {
    id: card
    width: 380
    height: content.implicitHeight + 52
    radius: 20
    color: Colors.surface
    border.color: Colors.border
    border.width: 1

    // Índice da sessão escolhida (ligado pelo Main ao SessionSelector).
    property int sessionIndex: 0

    function takeFocus() {
        if (userField.text.length > 0) passwordField.focusInput()
        else userField.focusInput()
    }
    function doLogin() {
        errorText.text = ""
        sddm.login(userField.text, passwordField.text, card.sessionIndex)
    }

    // Shake horizontal em falha (via transform, não interfere nas âncoras).
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
        width: parent.width - 56
        spacing: 14

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "../assets/avatar.svg"
            sourceSize: Qt.size(84, 84)
            width: 84
            height: 84
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Bem-vindo"
            color: Colors.text
            font.pixelSize: 20
            font.weight: Font.Medium
            bottomPadding: 4
        }

        InputField {
            id: userField
            placeholder: "Usuário"
            text: (typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : ""
            onAccepted: passwordField.focusInput()
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
