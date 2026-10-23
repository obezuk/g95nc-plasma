import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root
    toolTipMainText: i18n("G95NC Control")
    toolTipSubText: control.pending ? i18n("Applying layout…") : i18n("Monitor layouts and inputs")
    Plasmoid.icon: "video-display"
    preferredRepresentation: compactRepresentation

    Controller {
        id: control
        monitorSerial: Plasmoid.configuration.monitorSerial
        active: root.expanded
    }
    compactRepresentation: Controls.ToolButton {
        icon.name: "video-display"
        Accessible.name: i18n("G95NC Control")
        onClicked: root.expanded = !root.expanded
    }
    fullRepresentation: Editor {
        backend: control
        onConfigureRequested: Plasmoid.internalAction("configure").trigger()
    }
}
