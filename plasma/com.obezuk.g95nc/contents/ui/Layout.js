// Pure layout operations shared by the controller and its offline tests.
function same(a, b) {
    return !!a && !!b && a.profile === b.profile && JSON.stringify(a.inputs) === JSON.stringify(b.inputs);
}
function valid(value, profiles, inputs) {
    return !!value && !!profiles[value.profile] && Array.isArray(value.inputs)
        && value.inputs.length === profiles[value.profile].widths.length
        && value.inputs.every((source, index) => inputs.indexOf(source) >= 0 && value.inputs.indexOf(source) === index);
}
function choose(profile, draft, profiles, inputs) {
    const next = draft.inputs.slice(0, profiles[profile].widths.length);
    inputs.forEach(source => { if (next.length < profiles[profile].widths.length && next.indexOf(source) < 0) next.push(source); });
    return {profile: profile, inputs: next};
}
function assign(draft, index, source) {
    const next = draft.inputs.slice(), previous = next.indexOf(source);
    if (previous >= 0) next[previous] = next[index];
    next[index] = source;
    return {profile: draft.profile, inputs: next};
}
function measured(monitor, profiles, inputs) {
    if (!monitor) return null;
    let value = monitor.mode === 'single' ? {profile: 'single', inputs: [monitor.input]}
        : {profile: monitor.profile, inputs: monitor.panes};
    if (valid(value, profiles, inputs)) return value;
    value = monitor.applied_layout;
    return value && value.profile === monitor.profile && valid(value, profiles, inputs) ? value : null;
}
function closest(widths, profiles) {
    const total = widths.reduce((a, b) => a + b, 0);
    let best = null, score = Infinity;
    Object.keys(profiles).forEach(id => {
        const p = profiles[id];
        if (p.kind === 'pip' || p.widths.length !== widths.length) return;
        const distance = p.widths.reduce((sum, w, i) => sum + Math.pow(w - widths[i] * 100 / total, 2), 0);
        if (distance < score) { best = id; score = distance; }
    });
    return best;
}
function drop(draft, index, source, profiles, inputs) {
    if (inputs.indexOf(source) < 0 || index < 0 || index >= draft.inputs.length) return draft;
    if (draft.inputs.indexOf(source) >= 0 || draft.inputs.length === 3) return assign(draft, index, source);
    const widths = profiles[draft.profile].kind === 'pip' ? [50, 50] : profiles[draft.profile].widths.slice();
    const next = draft.inputs.slice();
    widths.splice(index, 1, widths[index] / 2, widths[index] / 2);
    next.splice(index + 1, 0, source);
    return {profile: closest(widths, profiles), inputs: next};
}
function remove(draft, index, profiles) {
    if (draft.inputs.length < 2 || index < 0 || index >= draft.inputs.length) return draft;
    return {profile: closest(profiles[draft.profile].widths.filter((_, i) => i !== index), profiles),
        inputs: draft.inputs.filter((_, i) => i !== index)};
}
function snap(draft, index, percent, profiles) {
    let best = draft.profile, score = Infinity;
    Object.keys(profiles).forEach(id => {
        const p = profiles[id];
        if (p.kind !== 'pbp' || p.widths.length !== draft.inputs.length) return;
        const distance = Math.abs(p.widths.slice(0, index + 1).reduce((a, b) => a + b, 0) - percent);
        if (distance < score) { best = id; score = distance; }
    });
    return {profile: best, inputs: draft.inputs.slice()};
}
