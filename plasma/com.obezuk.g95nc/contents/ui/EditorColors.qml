import QtQuick
import org.kde.kirigami as Kirigami
QtObject {
    function inputColor(source) {
        const palette = dark
            ? {DisplayPort: '#b6d8f4', HDMI1: '#ddf797', HDMI2: '#f8c39c', HDMI3: '#dac3f6'}
            : {DisplayPort: '#3175a5', HDMI1: '#608039', HDMI2: '#9b622f', HDMI3: '#7956a0'};
        return palette[source] || text;
    }
    function inputFill(source, emphasized) {
        const accent = Qt.tint("transparent", inputColor(source));
        return Qt.tint(surface, Qt.rgba(accent.r, accent.g, accent.b, emphasized ? .28 : dark ? .14 : .10));
    }
    readonly property bool dark: Kirigami.Theme.backgroundColor.r * .2126 + Kirigami.Theme.backgroundColor.g * .7152 + Kirigami.Theme.backgroundColor.b * .0722 < .45
    readonly property color panel: dark ? '#242428' : '#fafafa'
    readonly property color surface: dark ? '#34343b' : '#ffffff'
    readonly property color ribbon: dark ? '#1d1d22' : '#eeeef2'
    readonly property color hover: dark ? '#404049' : '#e8e8ee'
    readonly property color border: dark ? '#4c4c57' : '#dddde4'
    readonly property color text: dark ? '#eeeef2' : '#323238'
    readonly property color secondary: dark ? '#b5b5c0' : '#73737f'
    readonly property color muted: dark ? '#898996' : '#9898a3'
    readonly property color paneTop: dark ? '#3d3d47' : '#f4f4f7'
    readonly property color paneBottom: dark ? '#303039' : '#e6e6ec'
    readonly property color paneAltTop: dark ? '#353540' : '#eaeaf0'
    readonly property color paneAltBottom: dark ? '#292932' : '#dcdce5'
    readonly property color paneSelected: dark ? '#51515e' : '#d7d7e2'
    readonly property color outline: dark ? '#70707f' : '#bdbdc9'
}
