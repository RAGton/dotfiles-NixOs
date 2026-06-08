// =============================================================================
// Main.qml — Kryonix Aurora (tema SDDM, QtQuick)
//
// Raiz do greeter. SDDM injeta como context properties globais (acessíveis em
// QUALQUER componente): sddm, userModel, sessionModel, keyboard, screenModel,
// config (theme.conf). Importa só QtQuick 2.15 + a pasta components/ (sem
// QtQuick.Controls) para minimizar dependências de módulos QML no greeter.
// SVG via Image requer o plugin qtsvg (declarado em sddm.extraPackages).
// =============================================================================
import QtQuick 2.15
import "components"
import "Colors.js" as Colors

Rectangle {
    id: root
    color: Colors.background

    // SDDM redimensiona o root para o tamanho da tela (SizeRootObjectToView);
    // os filhos usam âncoras relativas a `parent` (== root).
    property string bgSource: (typeof config !== "undefined" && config.background)
                              ? config.background
                              : "assets/background.svg"

    // --- Fundo SVG (fallback gracioso: cor base se qtsvg/arquivo faltar) ---
    Image {
        anchors.fill: parent
        source: root.bgSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        onStatusChanged: if (status === Image.Error) visible = false
    }

    // --- Logo discreto (topo esquerdo) ---
    Image {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 28
        source: "assets/logo.svg"
        sourceSize: Qt.size(40, 40)
        width: 40
        height: 40
        opacity: 0.9
    }

    // --- Relógio + data (terço superior) ---
    Clock {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(parent.height * 0.16)
    }

    // --- Card central de login ---
    LoginCard {
        id: loginCard
        anchors.centerIn: parent
        sessionIndex: sessionSelector.currentIndex
    }

    // --- Hostname (rodapé centro) ---
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        text: (typeof sddm !== "undefined" && sddm.hostName) ? sddm.hostName : ""
        color: Colors.muted
        font.pixelSize: 13
    }

    // --- Seletor de sessão (rodapé esquerdo) ---
    SessionSelector {
        id: sessionSelector
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 28
    }

    // --- Energia: suspender / reiniciar / desligar (rodapé direito) ---
    PowerBar {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
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
