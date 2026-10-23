import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Item {
    id: editor
    property string selectedSource: ""
    required property var backend
    signal configureRequested()
    implicitWidth: 600
    implicitHeight: content.implicitHeight + 40
    Layout.minimumWidth: 520
    Layout.preferredWidth: 600
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight
    EditorColors { id: colors }
    Rectangle { anchors.fill: parent; color: colors.panel; radius: 14 }
    ColumnLayout {
        id: content
        x: 20; y: 20
        width: parent.width - 40
        spacing: 16
        ColumnLayout {
            visible: !backend.configured
            Layout.fillWidth: true
            Controls.Label { text: i18n("Choose your G95NC monitor") }
            Controls.Button {
                text: i18n("Configure…")
                icon.name: "configure"
                onClicked: configureRequested()
            }
        }
        ColumnLayout {
            visible: backend.ready
            Layout.fillWidth: true
            enabled: !backend.busy
            spacing: 16
            LayoutCanvas {
                id: screen
                backend: editor.backend
                selectedSource: editor.selectedSource
                Layout.fillWidth: true
                Layout.preferredHeight: width * 9 / 32
                onPicked: function(source) { editor.selectedSource = source; }
                onAssigned: editor.selectedSource = ""
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                color: colors.ribbon
                radius: 12
                RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                Repeater {
                    model: Object.keys(backend.profiles)
                    Controls.ToolButton {
                        id: controlButton
                        required property string modelData
                        readonly property var profile: backend.profiles[modelData]
                        Layout.fillWidth: true
                        Layout.preferredWidth: 48
                        implicitHeight: 40
                        background: Rectangle {
                            radius: 8
                            color: parent.checked ? colors.surface : parent.hovered ? colors.hover : "transparent"
                            border.width: parent.checked || parent.activeFocus ? 1 : 0
                            border.color: parent.activeFocus ? colors.secondary : colors.border
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        checkable: true
                        checked: backend.draft.profile === modelData
                        Accessible.name: profile.label
                        Controls.ToolTip.visible: hovered
                        Controls.ToolTip.text: profile.label
                        contentItem: Item {
                            LayoutPreview {
                                anchors.centerIn: parent
                                width: Math.min(parent.width - 10, 44)
                                height: width * 9 / 32
                                widths: profile.widths
                                pip: profile.kind === 'pip'
                                selected: controlButton.checked
                            }
                        }
                        onClicked: { editor.selectedSource = ""; backend.choose(modelData); }
                    }
                }
            }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: backend.inputs
                    SourceButton {
                        required property string modelData
                        Layout.fillWidth: true
                        source: modelData
                        canvas: screen
                        selected: editor.selectedSource === modelData
                        assigned: backend.draft.inputs.indexOf(modelData) >= 0
                        onPicked: function(source) { editor.selectedSource = source; }
                    }
                }
            }
        }

        Controls.Label {
            visible: backend.error.length > 0
            text: backend.error
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Kirigami.Theme.negativeTextColor
        }
        RowLayout {
            visible: backend.configured && (backend.error.length > 0 || backend.loading || backend.busy || backend.ready && backend.dirty)
            Layout.fillWidth: true
            Layout.topMargin: 2
            Controls.ToolButton {
                visible: backend.error.length > 0
                icon.name: "view-refresh"
                Accessible.name: i18n("Retry connection")
                enabled: !backend.loading && !backend.pending
                onClicked: backend.refresh()
            }
            Item { Layout.fillWidth: true }
            Controls.BusyIndicator {
                visible: backend.loading || backend.busy
                running: visible
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
            }
            Controls.Button {
                visible: backend.ready && (backend.dirty || backend.pending)
                text: backend.pending ? i18n("Applying…") : i18n("Confirm")
                enabled: backend.canApply
                implicitWidth: 112
                implicitHeight: 38
                contentItem: Controls.Label {
                    text: parent.text
                    color: colors.surface
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 10
                    color: parent.enabled ? parent.hovered ? colors.secondary : colors.text : colors.muted
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                onClicked: backend.apply()
            }
        }
    }
}
