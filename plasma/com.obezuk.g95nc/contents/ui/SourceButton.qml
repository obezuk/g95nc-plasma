import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Controls.ToolButton {
    id: button
    required property string source
    required property var canvas
    property bool selected: false
    property bool assigned: false
    implicitHeight: 44
    EditorColors { id: colors }
    background: Rectangle {
        radius: 10
        color: button.selected ? colors.hover : button.hovered || button.assigned ? colors.surface : "transparent"
        border.color: button.selected || button.activeFocus ? colors.secondary : colors.border
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    signal picked(string source)
    objectName: "source" + source
    checkable: true
    checked: selected
    Accessible.name: source
    onClicked: picked(source)
    contentItem: Item {
        opacity: button.canvas.draggingSource === button.source ? .5 : 1
        Behavior on opacity { NumberAnimation { duration: 100 } }
        Row {
            anchors.centerIn: parent
            spacing: 7
            ConnectorIcon { source: button.source; width: 22; height: 18; anchors.verticalCenter: parent.verticalCenter; ink: button.assigned || button.selected ? colors.text : colors.muted }
            Controls.Label { text: button.source; font.pixelSize: 12; font.weight: Font.Medium; color: button.assigned || button.selected ? colors.text : colors.secondary }
        }
    }
    MouseArea {
        anchors.fill: parent
        preventStealing: true
        cursorShape: moving ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property point origin
        property bool moving: false
        onPressed: function(mouse) { origin = Qt.point(mouse.x, mouse.y); moving = false; button.forceActiveFocus(); }
        onPositionChanged: function(mouse) {
            if (!pressed) return;
            if (Math.hypot(mouse.x - origin.x, mouse.y - origin.y) > 8) moving = true;
            if (moving) {
                const point = mapToItem(button.canvas, mouse.x, mouse.y);
                button.canvas.draggingSource = button.source;
                button.canvas.dragPoint = point;
                button.canvas.dropPane = button.canvas.paneAt(point.x, point.y);
            }
        }
        onReleased: function(mouse) {
            if (moving) {
                const point = mapToItem(button.canvas, mouse.x, mouse.y);
                button.canvas.place(button.source, point.x, point.y);
            } else button.picked(button.source);
            moving = false; button.canvas.draggingSource = ''; button.canvas.dropPane = -1;
        }
        onCanceled: { moving = false; button.canvas.draggingSource = ''; button.canvas.dropPane = -1; }
    }
}
