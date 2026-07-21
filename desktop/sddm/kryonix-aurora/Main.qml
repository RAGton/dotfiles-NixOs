// =============================================================================
// Main.qml — Kryonix Aurora (tema SDDM, QtQuick)
//
// Layout em duas zonas separadas por uma DIVISÓRIA vertical:
//   - Esquerda: marca (logo) + relógio/data + hostname + indicadores
//               (Caps Lock + layout do teclado) + seletor de sessão +
//               botões de energia (suspender/reiniciar/desligar).
//   - Direita:  card de login (avatar REAL do usuário + senha + Entrar).
//
// SDDM injeta como context properties globais: sddm, userModel, sessionModel,
// keyboard, screenModel, config. Imports: QtQuick 2.15 + components/. SVG via
// Image requer qtsvg (sddm.extraPackages).
// =============================================================================
import QtQuick 2.15
import "components"
import "Colors.js" as Colors

Rectangle {
    id: root
    color: Colors.background

    property string bgSource: (typeof config !== "undefined" && config.background)
                              ? config.background
                              : "assets/background.svg"

    // --- Fundo SVG (fallback gracioso) ---
    Image {
        anchors.fill: parent
        source: root.bgSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        onStatusChanged: if (status === Image.Error) visible = false
    }

    // ===== Zona ESQUERDA: marca + relógio + indicadores + sessão =====
    Item {
        id: leftZone
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: parent.width * 0.58

        Column {
            anchors.centerIn: parent
            spacing: 20

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "assets/logo.png"
                sourceSize: Qt.size(76, 76)
                width: 76
                height: 76
            }
            Clock { anchors.horizontalCenter: parent.horizontalCenter }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (typeof sddm !== "undefined" && sddm.hostName) ? sddm.hostName : ""
                color: Colors.muted
                font.pixelSize: 14
            }
            Indicators { anchors.horizontalCenter: parent.horizontalCenter }
            SessionSelector {
                id: sessionSelector
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // Botões de energia: canto inferior ESQUERDO da zona esquerda.
        PowerBar {
            anchors {
                left: parent.left
                bottom: parent.bottom
                margins: 28
            }
        }
    }

    // ===== DIVISÓRIA vertical (linha + glow accent) =====
    Rectangle {
        id: divider
        anchors {
            left: leftZone.right
            verticalCenter: parent.verticalCenter
        }
        width: 1
        height: parent.height * 0.64
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Colors.border }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    Rectangle {
        anchors {
            horizontalCenter: divider.horizontalCenter
            verticalCenter: parent.verticalCenter
        }
        width: 3
        height: 92
        radius: 1.5
        opacity: 0.55
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Colors.accent }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ===== Zona DIREITA: APENAS o login =====
    Item {
        id: rightZone
        anchors {
            left: divider.right
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }

        LoginCard {
            id: loginCard
            anchors.centerIn: parent
            sessionIndex: sessionSelector.currentIndex
        }
    }

    // Entrada animada do card.
    Component.onCompleted: {
        loginCard.opacity = 0
        loginCard.takeFocus()
        introAnim.start()
    }
    NumberAnimation {
        id: introAnim
        target: loginCard
        property: "opacity"
        from: 0
        to: 1
        duration: 320
        easing.type: Easing.OutCubic
    }
}
