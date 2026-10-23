import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property string title
    property string cfg_monitorSerialDefault: ""
    property alias cfg_monitorSerial: serial.text
    Controls.TextField {
        id: serial
        Kirigami.FormData.label: i18n("Monitor serial:")
        placeholderText: i18n("Serial reported by ddcutil detect")
    }
    Controls.Label {
        text: i18n("Uses ddcutil directly. No service or API token required.")
        wrapMode: Text.Wrap
    }
}
