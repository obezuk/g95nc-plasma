const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict'), path = require('node:path');
const monitor = {};
vm.createContext(monitor);
vm.runInContext(fs.readFileSync(path.join(__dirname, '../plasma/com.obezuk.g95nc/contents/ui/Monitor.js'), 'utf8'), monitor);
const plain = value => JSON.parse(JSON.stringify(value));
const fixtures = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/firmware-1009.2.json')));
for (const row of fixtures) assert.equal(monitor.decode(row.registers).profile, row.profile);
function fake(signature = 1, sources = [16, 0], options = {}) {
    return {
        signature, sources: [...sources], main: 15, writes: [], reads: 0, waits: [],
        wait(ms) { this.waits.push(ms); return Promise.resolve(); },
        read() {
            this.reads++;
            if (options.badRead && options.badRead(this)) return Promise.resolve('VCP E2 unsupported');
            const e3 = [7,9,11,13].includes(this.signature) ? 'xc0 x01' : this.sources.slice(0,2).map(v => 'x' + v.toString(16).padStart(2,'0')).join(' ');
            return Promise.resolve(`VCP 60 SNC x${this.main.toString(16)}\nVCP E2 CNC x00 x7f x39 xd${this.signature.toString(16)}\nVCP E3 CNC x51 x51 ${e3}\n`);
        },
        write(code, value) {
            this.writes.push([code, value]);
            if (options.failWrite && options.failWrite(this, code, value)) return Promise.reject(Error('Write failed'));
            if (code === 'E2' && !options.ignoreMode) {
                if (value === 0) this.signature &= 14;
                else if (value === 1) this.signature |= 1;
                else if (value === 2) this.signature = 1;
                else this.signature = ({3:1,4:3,5:5,6:7,7:9,8:11,9:13,16:15})[value];
            } else if (code === '60') this.main = value;
            else if (code === 'E3') {
                if (value === 0x1000) this.sources.reverse();
                else this.sources[value >> 8] = value & 255;
            }
            return Promise.resolve();
        }
    };
}
function permutations(values, n) {
    return n === 0 ? [[]] : values.flatMap((v, i) => permutations(values.filter((_, j) => j !== i), n-1).map(rest => [v, ...rest]));
}
(async () => {
    for (let n = 0; n < 16; n += 2) {
        const io = fake(n); assert.equal(monitor.decode(monitor.parse(await io.read())).profile, 'single');
    }
    assert.throws(() => monitor.decode(monitor.parse('VCP E2 CNC x00 x7f x40 xd1')), /Incomplete/);
    const wrongFamily = (await fake().read()).replace('x39', 'x40');
    assert.throws(() => monitor.decode(monitor.parse(wrongFamily)), /Unexpected/);
    for (const text of ['', 'VCP E2 CNC x00 x7f x39 xzz', 'VCP E2 CNC x00 x7f x139 xd1']) assert.throws(() => monitor.decode(monitor.parse(text)), /Incomplete/);
    for (const profile of Object.keys(monitor.profiles)) {
        for (const signature of [0,1,14,15]) {
            const io = fake(signature);
            const target = {profile, inputs: monitor.inputs.slice(0, monitor.profiles[profile].widths.length)};
            const result = await monitor.apply(io, target);
            assert.equal(result.profile, profile);
            const expectedModes = [];
            if (profile !== 'single') {
                if (!(signature & 1)) expectedModes.push(['E2',1]);
                if (monitor.profiles[profile].kind === 'pbp' && (signature & 14) === 14) expectedModes.push(['E2',2]);
            }
            expectedModes.push(['E2', monitor.profiles[profile].command]);
            assert.deepEqual(io.writes.filter(w => w[0] === 'E2'), expectedModes);
            assert.deepEqual(io.writes.slice(0, expectedModes.length), expectedModes);
            assert.ok(io.waits.every(ms => ms === 3000));
            if (target.inputs.length === 3) assert.equal(result.verification, 'readback_only');
        }
    }
    const swap = fake();
    await monitor.apply(swap, {profile:'50-50',inputs:['HDMI1','DisplayPort']});
    assert.deepEqual(swap.writes, [['E2',3],['E3',0x1000]]);
    const ignored = fake(1, [16,0], {ignoreMode:true});
    await assert.rejects(monitor.apply(ignored,{profile:'25-75',inputs:['HDMI1','DisplayPort']}), /no input commands/);
    assert.ok(ignored.writes.every(w => w[0] === 'E2'));
    const failed = fake(1,[16,0],{failWrite:(_io,code)=>code === 'E3'});
    await assert.rejects(monitor.apply(failed,{profile:'50-50',inputs:['HDMI1','DisplayPort']}), /Write failed/);
    assert.equal(failed.writes.filter(w=>w[0] === 'E3').length,1);
    const retry = fake(1,[16,0],{badRead:io=>io.reads === 3});
    await monitor.apply(retry,{profile:'50-50',inputs:['HDMI1','DisplayPort']});
    assert.equal(retry.writes.filter(w=>w[0] === 'E3').length,1);
    for (const size of [2,3]) for (const old of permutations(monitor.inputs,size)) for (const target of permutations(monitor.inputs,size)) {
        const current = old.slice();
        for (const [code,value] of monitor.uniquePlan(old,target)) {
            assert.equal(code,'E3');
            current[value>>8] = Object.keys(monitor.sourceCodes).find(name=>monitor.sourceCodes[name] === (value&255));
            assert.equal(new Set(current).size,size);
        }
        assert.deepEqual(current,target);
    }
    for (const value of [{profile:'toString',inputs:[]},{profile:'50-50',inputs:['HDMI1','HDMI1']},{profile:'single',inputs:['bogus']}]) assert.throws(()=>monitor.validate(value));
    for (const [code,value] of [['E2',true],['E2',99],['E3',0x310],['60',16]]) assert.throws(()=>monitor.validateWrite(code,value));
    console.log('JavaScript protocol checks passed: captured replies, all layouts, PiP transitions, verification, native swaps, failures, read retries, and all unique input permutations.');
})().catch(error=>{console.error(error);process.exitCode=1;});
