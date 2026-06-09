// Indicators.qml — Linha de indicadores do greeter (Caps Lock + layout teclado).
// Mostrados na zona ESQUERDA do tema (logo abaixo do hostname). Usam o context
// global `keyboard` que o SDDM injeta; com fallback gracioso quando ausente.
import QtQuick 2.15
import "../Colors.js" as Colors

Row {
    id: indicators
    spacing: 10

    property bool hasKeyboard: typeof keyboard !== "undefined" && keyboard !== null
    property bool capsLock: hasKeyboard && keyboard.capsLock
    property string layoutName: {
        if (!hasKeyboard) return ""
        var l = keyboard.layouts ? keyboard.layouts[keyboard.currentLayout] : null
        return l && l.shortName ? l.shortName.toUpperCase() : ""
    }

    // Pílula de Caps Lock (acende quando ativo).
    Rectangle {
        width: capsTxt.implicitWidth + 18
        height: 22
        radius: 11
        color: indicators.capsLock ? Colors.accent : "transparent"
        border.color: indicators.capsLock ? Colors.accent : Colors.border
        border.width: 1
        opacity: indicators.capsLock ? 1.0 : 0.55
        Behavior on color { ColorAnimation { duration: 120 } }
        Text {
            id: capsTxt
            anchors.centerIn: parent
            text: "CAPS"
            color: indicators.capsLock ? Colors.background : Colors.muted
            font.pixelSize: 11
            font.bold: true
        }
    }

    // Pílula do layout de teclado atual.
    Rectangle {
        width: Math.max(36, langTxt.implicitWidth + 18)
        height: 22
        radius: 11
        color: "transparent"
        border.color: Colors.border
        border.width: 1
        visible: indicators.layoutName !== ""
        Text {
            id: langTxt
            anchors.centerIn: parent
            text: indicators.layoutName
            color: Colors.text
            font.pixelSize: 11
            font.bold: true
        }
    }
}
