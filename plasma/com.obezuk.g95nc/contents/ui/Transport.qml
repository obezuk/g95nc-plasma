import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support
import "Monitor.js" as Monitor

Item {
    id: transport
    visible: false
    property string session: ""
    property string serverError: ""
    property bool closing: false
    property int sequence: 0
    property var callbacks: ({})
    readonly property string script: decodeURIComponent(Qt.resolvedUrl('../code/transport.sh').toString().replace(/^file:\/\//, ''))
    property Component delayFactory: Component { Timer {} }

    function quote(value) { return "'" + String(value).replace(/'/g, "'\\''") + "'"; }
    function run(args, seconds) {
        return new Promise(function(resolve, reject) {
            // Only quoted arguments cross the shell boundary; never interpolate shell code.
            const command = 'timeout -k 2 ' + (seconds || 30) + ' /usr/bin/bash ' + quote(script)
                + ' ' + args.map(quote).join(' ') + ' # g95nc-' + (++sequence);
            callbacks[command] = {resolve: resolve, reject: reject};
            executor.connectSource(command);
        });
    }
    function open(serial) {
        if (session) return Promise.reject(Error('A monitor transaction is already running.'));
        closing = false; serverError = '';
        return run(['prepare']).then(function(output) {
            session = output.trim();
            if (!/^\/[^\n]+\/session\.[A-Za-z0-9]+$/.test(session)) {
                session = ''; throw Error('Invalid monitor transport session.');
            }
            run(['serve', session, serial], 600).then(function() {
                if (!closing) serverError = 'Monitor transaction ended unexpectedly.';
            }, function(error) { if (!closing) serverError = error.message; });
            return run(['ready', session]);
        });
    }
    function close() {
        if (!session) return Promise.resolve();
        closing = true;
        return run(['close', session]).then(function() { session = ''; }, function(error) {
            session = ''; throw error;
        });
    }
    function exchange(args) {
        if (serverError) return Promise.reject(Error(serverError));
        return run(['exchange', session].concat(args));
    }
    function read() { return exchange(['read']); }
    function write(code, value) {
        Monitor.validateWrite(code, value);
        return exchange(['write', code, Monitor.hex(value)]);
    }
    function wait(milliseconds) {
        return new Promise(function(resolve) {
            const timer = delayFactory.createObject(transport, {interval: milliseconds});
            timer.triggered.connect(function() { timer.destroy(); resolve(); });
            timer.start();
        });
    }
    Plasma5Support.DataSource {
        id: executor
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            if (data['exit code'] === undefined) return;
            disconnectSource(source);
            const callback = transport.callbacks[source];
            delete transport.callbacks[source];
            if (!callback) return;
            if (data['exit code'] === 0) callback.resolve(data.stdout || '');
            else callback.reject(Error((data.stderr || '').trim() || 'Monitor transport failed (exit ' + data['exit code'] + ').'));
        }
    }
}
