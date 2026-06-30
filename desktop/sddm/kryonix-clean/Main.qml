import QtQuick 2.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0c1420"

    property string backgroundSource: (typeof config !== "undefined" && config.background)
                                      ? config.background
                                      : "assets/background-dark.svg"
    property var users: []
    property int userIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0)
                            ? userModel.lastIndex : 0
    property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0)
                               ? sessionModel.lastIndex : 0
    property bool keyboardAvailable: typeof keyboard !== "undefined" && keyboard !== null
    property bool blurSupported: false

    property var currentUser: (users.length > 0 && userIndex >= 0 && userIndex < users.length)
                              ? users[userIndex]
                              : ({ name: "", realName: "", icon: "" })

    function focusPassword() {
        passwordInput.forceActiveFocus()
    }

    function doLogin() {
        messageText.text = ""
        var userName = currentUser.name
        if ((!userName || userName.length === 0) && typeof userModel !== "undefined" && userModel.lastUser) {
            userName = userModel.lastUser
        }
        sddm.login(userName, passwordInput.text, sessionIndex)
    }

    function switchKeyboardLayout(step) {
        if (!keyboardAvailable || !keyboard.layouts || keyboard.layouts.length <= 1) {
            return
        }
        var total = keyboard.layouts.length
        keyboard.currentLayout = (keyboard.currentLayout + step + total) % total
    }

    function currentKeyboardLabel() {
        if (!keyboardAvailable || !keyboard.layouts || keyboard.layouts.length === 0) {
            return "Layout"
        }
        var layout = keyboard.layouts[keyboard.currentLayout]
        return layout && layout.shortName ? layout.shortName.toUpperCase() : "Layout"
    }

    Connections {
        target: sddm
        function onLoginSucceeded() { messageText.text = "" }
        function onLoginFailed() {
            messageText.text = "Usuario ou senha invalidos"
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
        }
        function onInformationMessage(message) { messageText.text = message }
    }

    Repeater {
        model: userModel
        Item {
            Component.onCompleted: {
                var nextUsers = root.users.slice()
                nextUsers[index] = {
                    name: "" + model.name,
                    realName: (model.realName && ("" + model.realName).length > 0)
                              ? "" + model.realName
                              : "" + model.name,
                    icon: "" + model.icon
                }
                root.users = nextUsers
            }
        }
    }

    Image {
        anchors.fill: parent
        source: root.backgroundSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        onStatusChanged: if (status === Image.Error) visible = false
    }

    Rectangle {
        anchors.fill: parent
        color: "#09111b"
        opacity: 0.18
    }

    Item {
        anchors.fill: parent
        anchors.margins: 48

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 36
            spacing: 10

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "assets/logo.svg"
                width: 56
                height: 56
                sourceSize: Qt.size(56, 56)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Kryonix"
                color: "#f3f7fb"
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(new Date(), "HH:mm")
                color: "#d9e4ef"
                font.pixelSize: 58
                font.weight: Font.Light
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(new Date(), "dddd, dd 'de' MMMM")
                color: "#9fb1c4"
                font.pixelSize: 16
                font.capitalization: Font.Capitalize
            }
        }

        Rectangle {
            id: card
            width: 420
            height: 560
            anchors.centerIn: parent
            radius: 26
            color: blurSupported ? "#7a122033" : "#dd122033"
            border.color: "#4a83a8c7"
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: "#660f1a29"
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                radius: 1
                color: "#50f8fbff"
                opacity: 0.45
            }

            Column {
                id: content
                anchors.fill: parent
                anchors.margins: 28
                spacing: 16

                Item {
                    width: parent.width
                    height: 120

                    Rectangle {
                        width: 88
                        height: 88
                        radius: 44
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#10314b"
                        border.color: "#57a7d6"
                        border.width: 1

                        Image {
                            anchors.centerIn: parent
                            source: "assets/avatar-placeholder.svg"
                            width: 52
                            height: 52
                            sourceSize: Qt.size(52, 52)
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: (root.currentUser.realName && root.currentUser.realName.length > 0)
                              ? root.currentUser.realName : "Usuario"
                        color: "#f4f7fb"
                        font.pixelSize: 20
                        font.weight: Font.Medium
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10
                    visible: root.users.length > 1

                    Rectangle {
                        width: 44
                        height: 40
                        radius: 14
                        color: userPrevMouse.pressed ? "#2f6186" : "#153149"
                        border.color: "#467695"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "<"
                            color: "#ecf4fb"
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: userPrevMouse
                            anchors.fill: parent
                            onClicked: root.userIndex = (root.userIndex - 1 + root.users.length) % root.users.length
                        }
                    }

                    Rectangle {
                        width: parent.width - 108
                        height: 40
                        radius: 14
                        color: "#101c2a"
                        border.color: "#324f67"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.currentUser.name
                            color: "#d7e3ef"
                            font.pixelSize: 15
                            elide: Text.ElideRight
                            width: parent.width - 20
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Rectangle {
                        width: 44
                        height: 40
                        radius: 14
                        color: userNextMouse.pressed ? "#2f6186" : "#153149"
                        border.color: "#467695"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: ">"
                            color: "#ecf4fb"
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: userNextMouse
                            anchors.fill: parent
                            onClicked: root.userIndex = (root.userIndex + 1) % root.users.length
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Senha"
                        color: "#cdd8e4"
                        font.pixelSize: 14
                    }

                    Rectangle {
                        width: parent.width
                        height: 50
                        radius: 16
                        color: "#101a27"
                        border.color: passwordInput.activeFocus ? "#69b7e0" : "#34516b"
                        border.width: passwordInput.activeFocus ? 2 : 1

                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#f7fbff"
                            font.pixelSize: 16
                            echoMode: TextInput.Password
                            passwordCharacter: "•"
                            selectionColor: "#7bc3e8"
                            selectedTextColor: "#0d1621"
                            onAccepted: root.doLogin()
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            visible: passwordInput.text.length === 0 && !passwordInput.activeFocus
                            text: "Digite sua senha"
                            color: "#7c90a5"
                            font.pixelSize: 16
                        }
                    }
                }

                Text {
                    id: capsText
                    text: keyboardAvailable && keyboard.capsLock ? "Caps Lock ativado" : ""
                    visible: text.length > 0
                    color: "#9eb3c7"
                    font.pixelSize: 13
                }

                Text {
                    id: messageText
                    width: parent.width
                    text: ""
                    visible: text.length > 0
                    color: "#f7a7b9"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: 16
                    color: loginMouse.pressed ? "#4f94bf" : "#69add6"

                    Text {
                        anchors.centerIn: parent
                        text: "Entrar"
                        color: "#0c1621"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: loginMouse
                        anchors.fill: parent
                        onClicked: root.doLogin()
                    }
                }

                Column {
                    spacing: 8
                    width: parent.width

                    Text {
                        text: "Sessao"
                        color: "#cdd8e4"
                        font.pixelSize: 14
                    }

                    Flow {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: sessionModel
                            delegate: Rectangle {
                                width: Math.max(86, label.implicitWidth + 26)
                                height: 34
                                radius: 12
                                color: index === root.sessionIndex ? "#173751" : "#101a27"
                                border.color: index === root.sessionIndex ? "#6bb6df" : "#324f67"
                                border.width: 1

                                Text {
                                    id: label
                                    anchors.centerIn: parent
                                    text: model.name
                                    color: "#ebf4fb"
                                    font.pixelSize: 13
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.sessionIndex = index
                                }
                            }
                        }
                    }
                }

                Column {
                    spacing: 8
                    width: parent.width

                    Text {
                        text: "Teclado"
                        color: "#cdd8e4"
                        font.pixelSize: 14
                    }

                    Row {
                        spacing: 8

                        Rectangle {
                            width: 44
                            height: 36
                            radius: 12
                            color: "#101a27"
                            border.color: "#324f67"
                            border.width: 1
                            opacity: keyboardAvailable ? 1.0 : 0.45

                            Text {
                                anchors.centerIn: parent
                                text: "<"
                                color: "#ebf4fb"
                                font.pixelSize: 16
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: keyboardAvailable
                                onClicked: root.switchKeyboardLayout(-1)
                            }
                        }

                        Rectangle {
                            width: 120
                            height: 36
                            radius: 12
                            color: "#101a27"
                            border.color: "#324f67"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root.currentKeyboardLabel()
                                color: "#ebf4fb"
                                font.pixelSize: 14
                            }
                        }

                        Rectangle {
                            width: 44
                            height: 36
                            radius: 12
                            color: "#101a27"
                            border.color: "#324f67"
                            border.width: 1
                            opacity: keyboardAvailable ? 1.0 : 0.45

                            Text {
                                anchors.centerIn: parent
                                text: ">"
                                color: "#ebf4fb"
                                font.pixelSize: 16
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: keyboardAvailable
                                onClicked: root.switchKeyboardLayout(1)
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 1
                }

                Flow {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: [
                            {
                                label: "Suspender",
                                enabled: (typeof sddm !== "undefined") && sddm.canSuspend,
                                action: "suspend"
                            },
                            {
                                label: "Reiniciar",
                                enabled: (typeof sddm !== "undefined") && sddm.canReboot,
                                action: "reboot"
                            },
                            {
                                label: "Desligar",
                                enabled: (typeof sddm !== "undefined") && sddm.canPowerOff,
                                action: "poweroff"
                            }
                        ]
                        delegate: Rectangle {
                            width: 110
                            height: 38
                            radius: 13
                            color: powerMouse.pressed && modelData.enabled ? "#173751" : "#101a27"
                            border.color: modelData.enabled ? "#3a5f7d" : "#2b3c4f"
                            border.width: 1
                            opacity: modelData.enabled ? 1.0 : 0.45

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: "#ecf4fb"
                                font.pixelSize: 13
                            }

                            MouseArea {
                                id: powerMouse
                                anchors.fill: parent
                                enabled: modelData.enabled
                                onClicked: {
                                    if (modelData.action === "suspend") sddm.suspend()
                                    else if (modelData.action === "reboot") sddm.reboot()
                                    else if (modelData.action === "poweroff") sddm.powerOff()
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            text: blurSupported ? "Glass leve ativo" : "Glass leve com fallback sem blur"
            color: "#8ca1b5"
            font.pixelSize: 12
        }
    }

    Component.onCompleted: focusPassword()
}
