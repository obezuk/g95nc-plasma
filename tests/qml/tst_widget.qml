import QtQuick
import QtTest
import "../widget/contents/ui" as Widget
TestCase {
    id: test
    name: "StandaloneWidget"
    visible: true
    when: windowShown
    width: 640; height: 440
    Widget.Controller { id: control; monitorSerial: "TEST-MONITOR"; active: true }
    Widget.Editor { id: editor; width: 600; height: implicitHeight; backend: control }
    function test_roundtrip() {
        tryCompare(control, "ready", true, 10000);
        compare(control.error, ""); compare(control.dirty, false);
        control.choose('50-50'); control.assign(0, 'HDMI1');
        verify(control.canApply); compare(control.draft.inputs[1], 'DisplayPort');
        control.apply();
        verify(control.pending); verify(!control.canApply);
        tryCompare(control, 'pending', false, 30000);
        compare(control.error, ''); compare(control.dirty, false);
        compare(control.draft.inputs[0], 'HDMI1');
        const canvas = findChild(editor, 'layoutCanvas');
        verify(canvas !== null);
        function dragSource(source, x, y) {
            const button = findChild(editor, 'source' + source);
            const end = button.mapFromItem(canvas, x, y);
            mousePress(button, button.width / 2, button.height / 2, Qt.LeftButton);
            mouseMove(button, end.x, end.y, 30);
            mouseRelease(button, end.x, end.y, Qt.LeftButton);
            wait(30);
        }
        function dragCanvas(x1, y1, x2, y2) {
            mousePress(canvas, x1, y1, Qt.LeftButton);
            mouseMove(canvas, x2, y2, 30);
            mouseRelease(canvas, x2, y2, Qt.LeftButton);
            wait(30);
        }
        control.choose('single'); control.assign(0, 'DisplayPort');
        wait(30);
        dragSource('HDMI1', canvas.width * .5, canvas.height * .5);
        compare(control.draft.profile, '50-50');
        compare(control.draft.inputs.join(','), 'DisplayPort,HDMI1');
        control.choose('25-75'); wait(30);
        dragSource('HDMI2', canvas.width * .8, canvas.height * .5);
        compare(control.draft.profile, '33-33-33');
        compare(control.draft.inputs.join(','), 'DisplayPort,HDMI1,HDMI2');
        dragCanvas(canvas.width / 3, canvas.height / 2, canvas.width / 2, canvas.height / 2);
        compare(control.draft.profile, '50-25-25');
        dragCanvas(canvas.width * .2, canvas.height / 2, canvas.width * .88, canvas.height / 2);
        compare(control.draft.inputs.join(','), 'HDMI2,HDMI1,DisplayPort');
        dragSource('HDMI3', canvas.width * .62, canvas.height / 2);
        compare(control.draft.inputs.join(','), 'HDMI2,HDMI3,DisplayPort');
        const beforeOutside = JSON.stringify(control.draft);
        dragSource('HDMI1', canvas.width + 30, canvas.height / 2);
        compare(JSON.stringify(control.draft), beforeOutside);
        const divider = findChild(canvas, 'divider0');
        divider.forceActiveFocus(); keyClick(Qt.Key_Left);
        compare(control.draft.profile, '33-33-33');
        const beforeTouch = control.draft.inputs.join(',');
        const touch = touchEvent(canvas);
        touch.press(0, canvas, canvas.width * .15, canvas.height / 2).commit();
        touch.move(0, canvas, canvas.width * .85, canvas.height / 2).commit();
        touch.release(0, canvas, canvas.width * .85, canvas.height / 2).commit();
        wait(30);
        compare(control.draft.inputs.join(','), 'DisplayPort,HDMI3,HDMI2');
        touch.press(0, canvas, canvas.width * .15, canvas.height / 2).commit();
        touch.move(0, canvas, canvas.width * .85, canvas.height / 2).commit();
        touch.release(0, canvas, canvas.width * .85, canvas.height / 2).commit();
        wait(30);
        compare(control.draft.inputs.join(','), beforeTouch);
        // Click-to-pick plus keyboard placement also swaps sources.
        const source = findChild(editor, 'sourceDisplayPort');
        mouseClick(source);
        findChild(canvas, 'pane0').forceActiveFocus(); keyClick(Qt.Key_Return);
        compare(control.draft.inputs.join(','), 'DisplayPort,HDMI3,HDMI2');
        mouseClick(findChild(canvas, 'remove1')); wait(30);
        compare(control.draft.profile, '50-50');
        compare(control.draft.inputs.join(','), 'DisplayPort,HDMI2');
        mouseClick(findChild(canvas, 'remove1')); wait(30);
        compare(control.draft.profile, 'single');
        verify(findChild(canvas, 'remove0') === null);
        // None of these edits replaced the last confirmed layout.
        compare(control.appliedLayout.profile, '50-50');
        compare(control.appliedLayout.inputs.join(','), 'HDMI1,DisplayPort');
        control.choose('33-33-33'); wait(100);
        verify(editor.height > 100);
        grabImage(editor).save(Qt.resolvedUrl('../preview.png').toString().replace(/^file:\/\//, ''));
        // Shell metacharacters must be passed literally to the helper.
        control.monitorSerial = "TEST' $(false); \"quoted\"";
        tryCompare(control, 'ready', true, 10000);
        compare(control.error, '');
        control.monitorSerial = 'FAIL';
        tryVerify(() => control.error.length > 0, 10000);
        compare(control.error, 'Simulated monitor failure');
        verify(!control.canApply);
        const component = Qt.createComponent('../widget/contents/ui/main.qml');
        compare(component.status, Component.Ready, component.errorString());
        const settings = Qt.createComponent('../widget/contents/ui/configGeneral.qml');
        compare(settings.status, Component.Ready, settings.errorString());
    }
}
