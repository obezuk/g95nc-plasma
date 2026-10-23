// Monitor protocol and transaction logic. No process or filesystem access here.
var inputs = ['DisplayPort', 'HDMI1', 'HDMI2', 'HDMI3'];
var sourceCodes = {HDMI1: 0, HDMI2: 1, HDMI3: 2, DisplayPort: 16};
var mainCodes = {DisplayPort: 15, HDMI1: 17, HDMI2: 18, HDMI3: 50};
var profiles = {
    single: {label: 'Full screen', widths: [100], command: 0, kind: 'single'},
    '50-50': {label: '50 / 50', widths: [50, 50], command: 3, kind: 'pbp'},
    '25-75': {label: '25 / 75', widths: [25, 75], command: 5, kind: 'pbp'},
    '75-25': {label: '75 / 25', widths: [75, 25], command: 4, kind: 'pbp'},
    '33-33-33': {label: '33 / 33 / 33', widths: [100/3, 100/3, 100/3], command: 6, kind: 'pbp'},
    '50-25-25': {label: '50 / 25 / 25', widths: [50, 25, 25], command: 7, kind: 'pbp'},
    '25-50-25': {label: '25 / 50 / 25', widths: [25, 50, 25], command: 8, kind: 'pbp'},
    '25-25-50': {label: '25 / 25 / 50', widths: [25, 25, 50], command: 9, kind: 'pbp'},
    pip: {label: '100 / PiP', widths: [100, 25], command: 16, kind: 'pip'}
};
function own(object, key) { return Object.prototype.hasOwnProperty.call(object, key); }
function hex(value) { return '0x' + ('0000' + value.toString(16)).slice(-4); }
function parse(output) {
    var result = {};
    output.split('\n').forEach(function(line) {
        var fields = line.trim().split(/\s+/), maximum = null, value;
        if (fields[0] !== 'VCP') return;
        var bytes = fields.slice(3);
        if (!bytes.every(part => /^(x|0x)?[0-9a-f]+$/i.test(part))) return;
        bytes = bytes.map(part => parseInt(part.replace(/^x/i, ''), 16));
        if (fields[2] === 'CNC' && bytes.length === 4 && bytes.every(n => n <= 255)) {
            maximum = bytes[0] * 256 + bytes[1]; value = bytes[2] * 256 + bytes[3];
        } else if (fields[2] === 'SNC' && bytes.length === 1) value = bytes[0];
        else return;
        if (value > 65535) return;
        var code = fields[1].toUpperCase();
        result[code] = {code: code, current: value, current_hex: hex(value), maximum: maximum, type: fields[2]};
    });
    return result;
}
function decode(registers) {
    if (!['E2', 'E3', '60'].every(code => own(registers, code))) throw Error('Incomplete DDC reply: expected E2, E3 and 60');
    var e2 = registers.E2.current, e3 = registers.E3.current;
    if (e2 >> 8 !== 0x39) throw Error('Unexpected E2 status family; expected G95NC 0x39xx');
    var signature = e2 & 15;
    var profile = !(signature & 1) ? 'single' : {1:'50-50',3:'75-25',5:'25-75',7:'33-33-33',9:'50-25-25',11:'25-50-25',13:'25-25-50',15:'pip'}[signature];
    var mode = profiles[profile].kind === 'single' ? 'single' : profile === 'pip' ? 'pip' : profiles[profile].widths.length === 2 ? 'two-pane' : 'three-pane';
    function source(code) { return Object.keys(sourceCodes).find(name => sourceCodes[name] === code); }
    var panes = null, left = source(e3 >> 8), right = source(e3 & 255);
    if ((mode === 'two-pane' || mode === 'pip') && left && right) panes = [left, right];
    return {registers: registers, raw: {'60': registers['60'].current_hex, E2: hex(e2), E3: hex(e3)},
        mode: mode, input: Object.keys(mainCodes).find(name => mainCodes[name] === registers['60'].current) || 'unknown',
        panes: panes, profile: profile, ratio: profiles[profile].label};
}
function validate(layout) {
    if (!layout || !own(profiles, layout.profile) || !Array.isArray(layout.inputs)) throw Error('Unknown layout');
    if (layout.inputs.length !== profiles[layout.profile].widths.length) throw Error('Assign one input to each pane');
    if (!layout.inputs.every((name, index) => own(sourceCodes, name) && layout.inputs.indexOf(name) === index)) throw Error('Assign distinct monitor inputs');
    return {profile: layout.profile, inputs: layout.inputs.slice()};
}
function validateWrite(code, value) {
    if (!Number.isInteger(value) || value < 0 || value > 65535) throw Error('Invalid VCP value');
    var valid = code === 'E2' ? [0,1,2,3,4,5,6,7,8,9,16].indexOf(value) >= 0
        : code === '60' ? Object.values(mainCodes).indexOf(value) >= 0
        : code === 'E3' && (value === 0x1000 || (value >> 8) <= 2 && Object.values(sourceCodes).indexOf(value & 255) >= 0);
    if (!valid) throw Error('Unsupported VCP command');
}
function modes(before, layout) {
    var profile = profiles[layout.profile], signature = before.registers.E2.current & 15, writes = [];
    if (profile.kind !== 'single') {
        if (!(signature & 1)) writes.push(['E2', 1]);
        if (profile.kind === 'pbp' && (signature & 14) === 14) writes.push(['E2', 2]);
    }
    writes.push(['E2', profile.command]);
    return writes;
}
function verifyMode(state, layout) {
    if (state.profile !== layout.profile) throw Error('Mode readback did not match the layout; no input commands were sent');
}
function uniquePlan(current, target) {
    current = current.slice();
    if (current.length !== target.length || new Set(current).size !== current.length) throw Error('Invalid current pane state');
    var writes = [];
    while (JSON.stringify(current) !== JSON.stringify(target)) {
        var pending = target.map((source, i) => source !== current[i] ? i : -1).filter(i => i >= 0);
        var pane = pending.find(i => current.indexOf(target[i]) < 0), source;
        if (pane === undefined) {
            pane = pending[0]; source = Object.keys(sourceCodes).find(name => current.indexOf(name) < 0);
        } else source = target[pane];
        current[pane] = source;
        writes.push(['E3', (pane << 8) | sourceCodes[source]]);
    }
    return writes;
}
function assignments(state, layout) {
    var target = layout.inputs;
    if (layout.profile === 'single') return [['60', mainCodes[target[0]]]];
    if (profiles[layout.profile].kind === 'pbp' && state.mode === 'two-pane' && target.length === 2
        && JSON.stringify(state.panes) === JSON.stringify(target.slice().reverse())) return [['E3', 0x1000]];
    if (state.panes && state.panes.length === target.length && new Set(state.panes).size === target.length) return uniquePlan(state.panes, target);
    return target.map((source, i) => ['E3', (i << 8) | sourceCodes[source]]);
}
function verifyResult(state, layout) {
    if (state.profile !== layout.profile) throw Error('Final layout readback does not match');
    if (layout.profile === 'single') {
        if (state.input !== layout.inputs[0]) throw Error('Full-screen readback does not match requested input');
    } else if (state.panes && JSON.stringify(state.panes) !== JSON.stringify(layout.inputs)) throw Error('Pane readback does not match requested inputs');
    state.applied_layout = layout;
    state.verification = layout.profile === 'single' || state.panes ? 'sources_confirmed' : 'readback_only';
    return state;
}
// Transport supplies Promise-returning read(), write(code,value), and wait(ms).
// The caller owns a transaction-wide lock. Only reads may be retried.
function read(transport, retries) {
    return transport.read().then(output => decode(parse(output))).catch(function(error) {
        if (!retries) throw error;
        return transport.wait(3000).then(() => read(transport, retries - 1));
    });
}
function perform(transport, writes) {
    writes.forEach(write => validateWrite(write[0], write[1]));
    return read(transport, 0).then(function() {
        var chain = Promise.resolve();
        writes.forEach(write => { chain = chain.then(() => transport.write(write[0], write[1])).then(() => transport.wait(3000)); });
        return chain;
    }).then(() => read(transport, 2));
}
function apply(transport, value) {
    var layout = validate(value);
    return read(transport, 0)
        .then(before => perform(transport, modes(before, layout)))
        .then(function(state) {
            verifyMode(state, layout);
            var writes = assignments(state, layout);
            return writes.length ? perform(transport, writes) : state;
        }).then(state => verifyResult(state, layout));
}
