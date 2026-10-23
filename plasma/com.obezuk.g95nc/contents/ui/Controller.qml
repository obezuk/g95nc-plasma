import QtQuick
import "Monitor.js" as Monitor
import "Layout.js" as Layout

Item {
    id: controller
    visible: false
    property string monitorSerial
    property bool active: false
    property var profiles: ({})
    property var inputs: []
    property var draft: ({profile: "single", inputs: ["DisplayPort"]})
    property var appliedLayout: null
    property string error: ""
    property bool loading: false
    property bool pending: false
    property bool ready: false
    property bool available: false
    property var submitted: null
    property string requestSerial: ""
    property var io: transport
    readonly property bool configured: monitorSerial.trim().length > 0
    readonly property bool dirty: !Layout.same(draft, appliedLayout)
    readonly property bool busy: pending || loading
    readonly property bool canApply: ready && available && !busy && dirty && Layout.valid(draft, profiles, inputs)

    Transport { id: transport }
    function execute(action) {
        if (busy || !configured) return;
        requestSerial = monitorSerial.trim();
        if (requestSerial.length > 128 || /[\r\n\0]/.test(requestSerial)) {
            error = 'Invalid monitor serial.'; return;
        }
        if (action === 'apply') {
            submitted = {profile: draft.profile, inputs: draft.inputs.slice()};
            pending = true;
        } else loading = true;
        error = '';
        io.open(requestSerial).then(function() {
            return action === 'apply' ? Monitor.apply(io, submitted) : Monitor.read(io, 0);
        }).then(function(state) {
            return io.close().then(function() {
                receive({ok: true, monitor: state, profiles: Monitor.profiles, inputs: Monitor.inputs});
            });
        }).catch(function(failure) {
            // Never retry an action after an ambiguous write or failed verification.
            io.close().catch(function() {}).then(function() {
                receive({ok: false, error: failure.message || String(failure)});
            });
        });
    }
    function refresh() { execute('read'); }
    function choose(profile) { draft = Layout.choose(profile, draft, profiles, inputs); }
    function assign(index, source) { draft = Layout.assign(draft, index, source); }
    function drop(index, source) { if (!busy) draft = Layout.drop(draft, index, source, profiles, inputs); }
    function remove(index) { if (!busy) draft = Layout.remove(draft, index, profiles); }
    function resize(index, percent) { if (!busy) draft = Layout.snap(draft, index, percent, profiles); }
    function apply() { if (canApply) execute('apply'); }
    function receive(result) {
        const wasApplying = pending;
        pending = false; loading = false;
        if (requestSerial !== monitorSerial.trim()) { ready = false; appliedLayout = null; if (active) refresh(); return; }
        if (!result.ok) {
            available = false; error = result.error || 'Monitor command failed.';
            if (wasApplying) appliedLayout = null;
            return;
        }
        profiles = result.profiles; inputs = result.inputs; available = true;
        if (wasApplying) appliedLayout = submitted;
        const actual = Layout.measured(result.monitor, profiles, inputs);
        if (!ready || !dirty) {
            if (actual) { draft = {profile: actual.profile, inputs: actual.inputs.slice()}; appliedLayout = actual; }
            else if (!wasApplying) {
                appliedLayout = null;
                const profile = profiles[result.monitor.profile] ? result.monitor.profile : 'single';
                draft = Layout.choose(profile, draft, profiles, inputs);
            }
        }
        ready = true; error = '';
    }
    Timer { interval: 30000; repeat: true; running: controller.active && controller.configured; onTriggered: controller.refresh() }
    Component.onCompleted: if (active) refresh()
    onActiveChanged: if (active) refresh()
    onMonitorSerialChanged: {
        ready = false; available = false; appliedLayout = null; error = '';
        if (active && !busy) refresh();
    }
}
