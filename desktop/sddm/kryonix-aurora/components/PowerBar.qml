// PowerBar.qml — suspender / reiniciar / desligar.
// Cada ação respeita as capacidades do sddm (canSuspend/canReboot/canPowerOff);
// desabilitada fica esmaecida e não clicável.
import QtQuick 2.15
import "../Colors.js" as Colors

Row {
    id: bar
    spacing: 12

    Repeater {
        model: [
            {
                icon: "../assets/suspend.svg",
                kind: "suspend",
                enabled: (typeof sddm !== "undefined") && sddm.canSuspend
            },
            {
                icon: "../assets/reboot.svg",
                kind: "reboot",
                enabled: (typeof sddm !== "undefined") && sddm.canReboot
            },
            {
                icon: "../assets/power.svg",
                kind: "poweroff",
                enabled: (typeof sddm !== "undefined") && sddm.canPowerOff
            }
        ]
        delegate: Rectangle {
            width: 46
            height: 46
            radius: 23
            color: (ma.containsMouse && modelData.enabled) ? Colors.surfaceAlt : "transparent"
            border.color: (ma.containsMouse && modelData.enabled) ? Colors.accent : Colors.border
            border.width: 1
            opacity: modelData.enabled ? 1.0 : 0.3
            Behavior on color { ColorAnimation { duration: 120 } }

            Image {
                anchors.centerIn: parent
                source: modelData.icon
                sourceSize: Qt.size(20, 20)
                width: 20
                height: 20
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                enabled: modelData.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData.kind === "suspend") sddm.suspend()
                    else if (modelData.kind === "reboot") sddm.reboot()
                    else if (modelData.kind === "poweroff") sddm.powerOff()
                }
            }
        }
    }
}
