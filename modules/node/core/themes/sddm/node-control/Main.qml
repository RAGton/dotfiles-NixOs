import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0 as SDDM
import "Components"

Item {
    id: root

    width: parent ? parent.width : (config.ScreenWidth || 1920)
    height: parent ? parent.height : (config.ScreenHeight || 1080)
    focus: true

    readonly property color primaryText: config.PrimaryTextColor || "#f3f8fc"
    readonly property color secondaryText: config.SecondaryTextColor || "#9fb2c8"
    readonly property color mutedText: config.MutedTextColor || "#708299"
    readonly property color accent: config.AccentColor || "#4ba3ff"
    readonly property color accentSoft: config.AccentSoftColor || "#8fd0ff"
    readonly property color surface: config.SurfaceColor || "#f40c1420"
    readonly property color surfaceBorder: config.SurfaceBorderColor || "#2c4158"
    readonly property color field: config.FieldColor || "#162232"
    readonly property color fieldBorder: config.FieldBorderColor || "#29405a"
    readonly property color fieldFocus: config.FieldFocusColor || "#4ba3ff"
    readonly property color primaryButtonText: config.PrimaryButtonTextColor || "#041420"
    readonly property int cardWidth: Math.max(420, Math.min(width * 0.34, 520))
    readonly property string displayHostName: (config.HostLabel && config.HostLabel !== "") ? config.HostLabel : ((sddm.hostName && sddm.hostName !== "") ? sddm.hostName : (config.FallbackHostName || "node-client"))
    readonly property int selectedSessionIndex: sessionSelector.currentIndex >= 0 ? sessionSelector.currentIndex : sessionModel.lastIndex

    SDDM.TextConstants {
        id: textConstants
    }

    function triggerLogin() {
        errorLabel.text = ""
        sddm.login(usernameField.text, passwordField.text, root.selectedSessionIndex)
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            errorLabel.text = ""
        }

        function onLoginFailed() {
            passwordField.text = ""
            errorLabel.text = config.TranslateLoginFailed || (textConstants.loginFailed + "!")
            passwordField.forceActiveFocus()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#08111d"
    }

    Image {
        id: backgroundImage
        anchors.fill: parent
        source: Qt.resolvedUrl(config.Background || "Background.png")
        asynchronous: true
        cache: true
        fillMode: config.ScaleImageCropped == "true" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        mipmap: true
    }

    Rectangle {
        anchors.fill: parent
        color: "#9810192a"
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#d90a1018" }
            GradientStop { position: 0.36; color: "#7f09111e" }
            GradientStop { position: 1.0; color: "#1f09111a" }
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#26000000" }
            GradientStop { position: 0.72; color: "#05000000" }
            GradientStop { position: 1.0; color: "#66040b15" }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 82
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72
        spacing: 10

        Text {
            text: config.HeaderText || "NODE Control"
            color: root.accentSoft
            font.family: "Noto Sans"
            font.pointSize: 12
            font.bold: true
            font.letterSpacing: 2.4
        }

        Text {
            id: timeLabel
            color: root.primaryText
            font.family: "Noto Sans"
            font.pointSize: 38
            font.weight: Font.DemiBold

            function updateClock() {
                text = new Date().toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
            }
        }

        Text {
            id: dateLabel
            color: root.secondaryText
            font.family: "Noto Sans"
            font.pointSize: 14

            function updateDate() {
                text = new Date().toLocaleDateString(Qt.locale(), Locale.LongFormat)
            }
        }

        Text {
            width: Math.min(root.width * 0.34, 520)
            text: config.WelcomeText || "Controle previsivel para clientes diskless"
            color: root.secondaryText
            wrapMode: Text.WordWrap
            font.family: "Noto Sans"
            font.pointSize: 12
            lineHeight: 1.25
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                timeLabel.updateClock()
                dateLabel.updateDate()
            }
        }

        Component.onCompleted: {
            timeLabel.updateClock()
            dateLabel.updateDate()
        }
    }

    Rectangle {
        id: loginCard

        width: root.cardWidth
        height: Math.max(560, Math.min(root.height - ((config.ScreenPadding || 72) * 2), 640))
        anchors.right: parent.right
        anchors.rightMargin: config.ScreenPadding || 72
        anchors.verticalCenter: parent.verticalCenter
        radius: 24
        color: root.surface
        border.width: 1
        border.color: root.surfaceBorder
        layer.enabled: true
        layer.samples: 4

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 4
            radius: 4
            color: root.accent
            opacity: 0.92
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            anchors.topMargin: 28
            anchors.bottomMargin: 24
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Image {
                    source: Qt.resolvedUrl("Logo.png")
                    sourceSize.width: 72
                    sourceSize.height: 72
                    fillMode: Image.PreserveAspectFit
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 72
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: config.HeaderText || "NODE Control"
                        color: root.accentSoft
                        font.family: "Noto Sans"
                        font.pointSize: 10
                        font.bold: true
                        font.letterSpacing: 1.8
                    }

                    Text {
                        text: config.SubHeaderText || "Acesso operacional"
                        color: root.primaryText
                        font.family: "Noto Sans"
                        font.pointSize: 20
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Greeter declarativo do cliente NODE"
                        color: root.secondaryText
                        font.family: "Noto Sans"
                        font.pointSize: 11
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                InfoChip {
                    Layout.fillWidth: true
                    label: "Host"
                    value: root.displayHostName
                    labelColor: root.mutedText
                    valueColor: root.primaryText
                    surfaceColor: "#172231"
                    borderColor: root.surfaceBorder
                }

                InfoChip {
                    Layout.fillWidth: true
                    label: "Perfil"
                    value: config.ProfileLabel || "desktop"
                    labelColor: root.mutedText
                    valueColor: root.primaryText
                    surfaceColor: "#172231"
                    borderColor: root.surfaceBorder
                }
            }

            InfoChip {
                Layout.fillWidth: true
                label: "Transporte"
                value: config.TransportLabel || "PXE + HTTP + NFS + NFSv4"
                labelColor: root.mutedText
                valueColor: root.primaryText
                surfaceColor: "#172231"
                borderColor: root.surfaceBorder
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Usuario"
                    color: root.secondaryText
                    font.family: "Noto Sans"
                    font.pointSize: 10
                    font.bold: true
                }

                TextField {
                    id: usernameField
                    Layout.fillWidth: true
                    implicitHeight: 48
                    text: config.ForceLastUser == "true" ? userModel.lastUser : ""
                    color: root.primaryText
                    placeholderText: textConstants.userName
                    selectByMouse: true
                    font.family: "Noto Sans"
                    font.pointSize: 12
                    leftPadding: 16
                    rightPadding: 16
                    background: Rectangle {
                        radius: 14
                        color: root.field
                        border.width: usernameField.activeFocus ? 2 : 1
                        border.color: usernameField.activeFocus ? root.fieldFocus : root.fieldBorder
                    }
                    Keys.onReturnPressed: passwordField.forceActiveFocus()
                    KeyNavigation.tab: passwordField
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Senha"
                    color: root.secondaryText
                    font.family: "Noto Sans"
                    font.pointSize: 10
                    font.bold: true
                }

                TextField {
                    id: passwordField
                    Layout.fillWidth: true
                    implicitHeight: 52
                    color: root.primaryText
                    echoMode: TextInput.Password
                    placeholderText: textConstants.password
                    selectByMouse: true
                    font.family: "Noto Sans"
                    font.pointSize: 14
                    leftPadding: 16
                    rightPadding: 16
                    passwordCharacter: "•"
                    focus: config.ForcePasswordFocus == "true"
                    background: Rectangle {
                        radius: 14
                        color: root.field
                        border.width: passwordField.activeFocus ? 2 : 1
                        border.color: passwordField.activeFocus ? root.fieldFocus : root.fieldBorder
                    }
                    Keys.onReturnPressed: root.triggerLogin()
                    KeyNavigation.backtab: usernameField
                    KeyNavigation.tab: sessionSelector
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: config.TranslateSession || textConstants.session
                    color: root.secondaryText
                    font.family: "Noto Sans"
                    font.pointSize: 10
                    font.bold: true
                }

                ComboBox {
                    id: sessionSelector
                    Layout.fillWidth: true
                    implicitHeight: 48
                    model: sessionModel
                    currentIndex: sessionModel.lastIndex
                    textRole: "name"
                    font.family: "Noto Sans"
                    font.pointSize: 12
                    hoverEnabled: true

                    delegate: ItemDelegate {
                        width: sessionSelector.width
                        contentItem: Text {
                            text: model.name
                            color: sessionSelector.highlightedIndex === index ? "#041420" : root.primaryText
                            font: sessionSelector.font
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        highlighted: sessionSelector.highlightedIndex === index
                        background: Rectangle {
                            color: highlighted ? root.accentSoft : "#162232"
                        }
                    }

                    contentItem: Text {
                        leftPadding: 16
                        rightPadding: 36
                        text: sessionSelector.displayText
                        font: sessionSelector.font
                        color: root.primaryText
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    indicator: Canvas {
                        x: sessionSelector.width - width - 18
                        y: (sessionSelector.height - height) / 2
                        width: 12
                        height: 8
                        contextType: "2d"
                        onPaint: {
                            context.reset()
                            context.moveTo(0, 0)
                            context.lineTo(width, 0)
                            context.lineTo(width / 2, height)
                            context.closePath()
                            context.fillStyle = root.accentSoft
                            context.fill()
                        }
                    }

                    background: Rectangle {
                        radius: 14
                        color: root.field
                        border.width: sessionSelector.visualFocus ? 2 : 1
                        border.color: sessionSelector.visualFocus ? root.fieldFocus : root.fieldBorder
                    }

                    popup: Popup {
                        y: sessionSelector.height + 8
                        width: sessionSelector.width
                        padding: 1
                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: sessionSelector.popup.visible ? sessionSelector.delegateModel : null
                            currentIndex: sessionSelector.highlightedIndex
                        }
                        background: Rectangle {
                            radius: 14
                            color: "#132030"
                            border.width: 1
                            border.color: root.surfaceBorder
                        }
                    }

                    KeyNavigation.backtab: passwordField
                    KeyNavigation.tab: loginButton
                }
            }

            Text {
                id: errorLabel
                Layout.fillWidth: true
                visible: text !== ""
                text: ""
                color: "#ff8d8d"
                font.family: "Noto Sans"
                font.pointSize: 10
                wrapMode: Text.WordWrap
            }

            ActionButton {
                id: loginButton
                Layout.fillWidth: true
                text: config.TranslateLogin || textConstants.login
                primary: true
                accentColor: root.accent
                surfaceColor: root.field
                surfaceBorderColor: root.surfaceBorder
                textColor: root.primaryText
                primaryTextColor: root.primaryButtonText
                onClicked: root.triggerLogin()
                KeyNavigation.backtab: sessionSelector
                KeyNavigation.tab: suspendButton
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: "#243446"
                opacity: 0.9
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "Perfil e transporte do cliente publicados de forma declarativa; o greeter nao depende de telemetria em tempo real."
                    color: root.mutedText
                    wrapMode: Text.WordWrap
                    font.family: "Noto Sans"
                    font.pointSize: 9
                    lineHeight: 1.2
                }

                RowLayout {
                    spacing: 8

                    ActionButton {
                        id: suspendButton
                        text: config.TranslateSuspend || textConstants.suspend
                        enabled: sddm.canSuspend
                        primary: false
                        accentColor: root.accent
                        surfaceColor: root.field
                        surfaceBorderColor: root.surfaceBorder
                        textColor: root.primaryText
                        primaryTextColor: root.primaryButtonText
                        onClicked: sddm.suspend()
                        KeyNavigation.backtab: loginButton
                        KeyNavigation.tab: rebootButton
                    }

                    ActionButton {
                        id: rebootButton
                        text: config.TranslateReboot || textConstants.reboot
                        enabled: sddm.canReboot
                        primary: false
                        accentColor: root.accent
                        surfaceColor: root.field
                        surfaceBorderColor: root.surfaceBorder
                        textColor: root.primaryText
                        primaryTextColor: root.primaryButtonText
                        onClicked: sddm.reboot()
                        KeyNavigation.backtab: suspendButton
                        KeyNavigation.tab: shutdownButton
                    }

                    ActionButton {
                        id: shutdownButton
                        text: config.TranslateShutdown || textConstants.shutdown
                        enabled: sddm.canPowerOff
                        primary: false
                        accentColor: root.accent
                        surfaceColor: root.field
                        surfaceBorderColor: root.surfaceBorder
                        textColor: root.primaryText
                        primaryTextColor: root.primaryButtonText
                        onClicked: sddm.powerOff()
                        KeyNavigation.backtab: rebootButton
                        KeyNavigation.tab: usernameField
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (usernameField.text === "")
            usernameField.forceActiveFocus()
        else
            passwordField.forceActiveFocus()
    }
}
