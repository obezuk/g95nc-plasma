import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Item {
    id: canvas
    required property var backend
    property string selectedSource: ""
    property string draggingSource: ""
    property int dropPane: -1
    property point dragPoint
    EditorColors { id: colors }
    signal picked(string source)
    signal assigned()
    readonly property var widths: backend.profiles[backend.draft.profile] ? backend.profiles[backend.draft.profile].widths : [100]
    readonly property bool pip: backend.draft.profile === 'pip'
    implicitHeight: width * 9 / 32
    objectName: "layoutCanvas"
    function boundary(index) { return widths.slice(0, index + 1).reduce((a,b) => a+b, 0); }
    function paneAt(x, y) {
        if (x < 0 || y < 0 || x > width || y > height) return -1;
        if (pip) return x >= width * .7 && x <= width * .95 && y >= height * .56 && y <= height * .86 ? 1 : 0;
        for (let i = 0; i < widths.length; i++) if (x <= width * boundary(i) / 100) return i;
        return widths.length - 1;
    }
    function dividerAt(x, y) {
        if (pip || y < height * .2 || y > height * .8) return -1;
        for (let i = 0; i < widths.length - 1; i++) if (Math.abs(x - width * boundary(i) / 100) <= 9) return i;
        return -1;
    }
    function place(source, x, y) {
        const index = paneAt(x, y);
        if (index >= 0 && source && !backend.busy) { backend.drop(index, source); assigned(); }
    }
    function selectPane(index) {
        if (selectedSource) { backend.drop(index, selectedSource); assigned(); }
        else picked(backend.draft.inputs[index]);
    }
    LayoutPreview {
        anchors.fill: parent; widths: canvas.widths; pip: canvas.pip
        highlightedPane: canvas.dropPane >= 0 ? canvas.dropPane : canvas.backend.draft.inputs.indexOf(canvas.selectedSource)
    }
    Repeater {
        id: panes
        model: canvas.backend.draft.inputs
        Item {
            id: pane
            required property int index
            required property string modelData
            objectName: "pane" + index
            activeFocusOnTab: true
            x: canvas.pip ? (index === 0 ? 0 : canvas.width * .7) : canvas.width * (canvas.boundary(index) - canvas.widths[index]) / 100
            y: canvas.pip && index === 1 ? canvas.height * .56 : 0
            width: canvas.pip ? canvas.width * (index === 0 ? 1 : .25) : canvas.width * canvas.widths[index] / 100
            height: canvas.pip && index === 1 ? canvas.height * .3 : canvas.height
            Accessible.role: Accessible.Button
            Accessible.name: modelData
            Keys.onReturnPressed: canvas.selectPane(index)
            Keys.onSpacePressed: canvas.selectPane(index)
            Rectangle {
                x: 4; y: parent.height * .22; width: parent.width - 8; height: parent.height * .56
                radius: 4
                visible: pane.activeFocus && !canvas.draggingSource && !canvas.selectedSource
                color: "transparent"
                border.color: colors.outline
                border.width: 1
            }
            Column {
                anchors.centerIn: parent
                // Keep the main label clear of the PiP inset.
                anchors.horizontalCenterOffset: canvas.pip && pane.index === 0 ? -canvas.width * .12 : 0
                spacing: 8
                opacity: canvas.draggingSource === pane.modelData ? .4 : 1
                Behavior on opacity { NumberAnimation { duration: 100 } }
                ConnectorIcon { anchors.horizontalCenter: parent.horizontalCenter; source: pane.modelData; width: 32; height: 25; ink: colors.secondary; visible: !canvas.pip || pane.index === 0 }
                Controls.Label { text: pane.modelData; font.pixelSize: canvas.pip && pane.index === 1 ? 11 : 14; font.weight: Font.Medium; color: colors.text }
            }
        }
    }
    Repeater {
        model: canvas.pip ? 0 : canvas.widths.length - 1
        Item {
            required property int index
            objectName: "divider" + index
            activeFocusOnTab: true
            x: canvas.width * canvas.boundary(index) / 100 - 9
            y: canvas.height * .25
            width: 18; height: canvas.height * .5
            Accessible.role: Accessible.Slider
            Accessible.name: qsTr("Divider %1").arg(index + 1)
            Keys.onLeftPressed: canvas.backend.resize(index, canvas.boundary(index) - 20)
            Keys.onRightPressed: canvas.backend.resize(index, canvas.boundary(index) + 20)
            Rectangle {
                anchors.centerIn: parent
                width: 12; height: Math.min(38, parent.height); radius: 6
                color: colors.surface
                border.color: colors.border
                Rectangle {
                    anchors.centerIn: parent
                    width: 3; height: 24; radius: 2
                    color: gestures.resizeIndex === index || parent.parent.activeFocus ? colors.text : colors.muted
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }
        }
    }
    // One stable event surface retains the pointer while resizing rebuilds the panes.
    MouseArea {
        id: gestures
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        enabled: !canvas.backend.busy
        property int resizeIndex: -1
        property string source: ""
        property point origin
        property bool moving: false
        cursorShape: resizeIndex >= 0 || canvas.dividerAt(mouseX, mouseY) >= 0 ? Qt.SizeHorCursor : moving ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: function(mouse) {
            origin = Qt.point(mouse.x, mouse.y); moving = false;
            resizeIndex = canvas.dividerAt(mouse.x, mouse.y);
            const index = canvas.paneAt(mouse.x, mouse.y);
            source = index >= 0 ? canvas.backend.draft.inputs[index] : '';
            if (index >= 0) panes.itemAt(index).forceActiveFocus();
        }
        onPositionChanged: function(mouse) {
            if (!pressed) return;
            if (resizeIndex >= 0) { canvas.backend.resize(resizeIndex, mouse.x * 100 / canvas.width); return; }
            if (Math.hypot(mouse.x - origin.x, mouse.y - origin.y) > 8) moving = true;
            if (moving) { canvas.draggingSource = source; canvas.dragPoint = Qt.point(mouse.x, mouse.y); canvas.dropPane = canvas.paneAt(mouse.x, mouse.y); }
        }
        onReleased: function(mouse) {
            if (resizeIndex < 0) {
                if (moving) canvas.place(source, mouse.x, mouse.y);
                else { const index = canvas.paneAt(mouse.x, mouse.y); if (index >= 0) canvas.selectPane(index); }
            }
            resizeIndex = -1; moving = false; canvas.draggingSource = ''; canvas.dropPane = -1;
        }
        onCanceled: { resizeIndex = -1; moving = false; canvas.draggingSource = ''; canvas.dropPane = -1; }
    }
    // Removal controls sit above the canvas gesture surface.
    Repeater {
        model: canvas.backend.draft.inputs.length > 1 ? canvas.backend.draft.inputs : []
        Controls.ToolButton {
            required property int index
            required property string modelData
            objectName: "remove" + index
            width: 22; height: 22
            opacity: hovered || activeFocus || canvas.selectedSource === modelData ? 1 : .45
            Behavior on opacity { NumberAnimation { duration: 120 } }
            background: Rectangle { radius: 11; color: colors.surface; border.color: colors.border }
            contentItem: Controls.Label { text: "×"; font.pixelSize: 15; color: colors.secondary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            x: canvas.pip ? (index === 0 ? canvas.width * .65 : canvas.width * .95) - width : canvas.width * canvas.boundary(index) / 100 - width - 4
            y: canvas.pip && index === 1 ? canvas.height * .56 - 10 : canvas.height * .19
            text: "×"
            Accessible.name: qsTr("Remove %1").arg(modelData)
            onClicked: { const owner = canvas; owner.backend.remove(index); owner.assigned(); }
        }
    }
    Rectangle {
        z: 10
        visible: canvas.draggingSource.length > 0
        x: canvas.dragPoint.x + 12; y: canvas.dragPoint.y - 36
        width: dragLabel.implicitWidth + 24; height: 32
        radius: 9
        color: colors.surface; border.color: colors.outline
        opacity: .96
        Controls.Label { id: dragLabel; anchors.centerIn: parent; text: canvas.draggingSource; font.pixelSize: 12; font.weight: Font.Medium; color: colors.text }
    }

}
