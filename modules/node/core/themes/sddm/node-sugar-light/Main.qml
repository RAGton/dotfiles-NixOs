//
// Baseado em MarianArlt/sddm-sugar-light.
// O fork local mantem a estrutura upstream e so acrescenta um painel
// de login e uma camada de contraste para o background do NODE.
//

import QtQuick 2.11
import QtQuick.Layouts 1.11
import QtQuick.Controls 2.4
import "Components"

Pane {
    id: root

    height: config.ScreenHeight
    width: config.ScreenWidth
    padding: config.ScreenPadding || root.padding

    LayoutMirroring.enabled: config.ForceRightToLeft == "true" ? true : Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    palette.button: "transparent"
    palette.highlight: config.ThemeColor
    palette.text: config.ThemeColor
    palette.buttonText: config.ThemeColor

    font.family: config.Font
    font.pointSize: config.FontSize !== "" ? config.FontSize : parseInt(height / 80)
    focus: true

    background: Rectangle {
        color: "#081018"
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            id: loginPanel
            Layout.fillHeight: true
            Layout.minimumWidth: Math.min(parent.width * 0.32, 460)
            Layout.preferredWidth: Math.min(parent.width * 0.36, 560)
            Layout.maximumWidth: Math.min(parent.width * 0.42, 620)

            Rectangle {
                anchors.fill: parent
                color: "#d10a1220"
            }

            Rectangle {
                width: 1
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                color: "#36506e"
                opacity: 0.65
            }

            LoginForm {
                anchors.fill: parent
                anchors.margins: root.font.pointSize * 2.5
            }
        }

        Item {
            id: image
            Layout.fillWidth: true
            Layout.fillHeight: true

            Image {
                // O parser de config do SDDM/Sugar nem sempre entrega o valor
                // esperado aqui entre versoes, o que fazia o greeter cair no
                // visual azul generico. O tema NODE usa branding fixo.
                source: Qt.resolvedUrl("Background.png")
                anchors.fill: parent
                asynchronous: true
                cache: true
                fillMode: config.ScaleImageCropped == "true" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                clip: true
                mipmap: true
            }

            Rectangle {
                anchors.fill: parent
                color: "#59060c14"
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#2a6ca0d6" }
                    GradientStop { position: 0.22; color: "#140d1622" }
                    GradientStop { position: 1.0; color: "#24040a10" }
                }
                opacity: 0.35
            }

            MouseArea {
                anchors.fill: parent
                onClicked: parent.forceActiveFocus()
            }
        }
    }
}
