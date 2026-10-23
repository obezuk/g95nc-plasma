import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.kcmutils as KCMUtils

PlasmoidItem {
    id: root
    toolTipMainText: i18n("G95NC Control")
    toolTipSubText: control.pending ? i18n("Applying layout…") : i18n("Monitor layouts and inputs")
    Plasmoid.icon: Qt.resolvedUrl("../images/g95nc.svg").toString()
    preferredRepresentation: compactRepresentation

    Controller {
        id: control
        monitorSerial: Plasmoid.configuration.monitorSerial
        active: root.expanded
    }
    compactRepresentation: Controls.ToolButton {
        contentItem: Item {
            implicitWidth: 32
            implicitHeight: 32
            MonitorIcon {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
            }
        }
        Accessible.name: i18n("G95NC Control")
        onClicked: root.expanded = !root.expanded
    }
    fullRepresentation: Editor {
        backend: control
        onConfigureRequested: Plasmoid.internalAction("configure").trigger()
        onDisplayConfigurationRequested: KCMUtils.KCMLauncher.openSystemSettings("kcm_kscreen")
    }
}
