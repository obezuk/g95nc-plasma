#!/usr/bin/python3
"""Offline process-transport fixture. Never opens an I2C device."""
import hashlib
import json
from pathlib import Path
import sys

args = sys.argv[1:]
serial = args[args.index('--sn') + 1]
if serial == 'FAIL':
    print('Simulated monitor failure', file=sys.stderr)
    sys.exit(1)
file = Path(__file__).parent / ('state-' + hashlib.sha256(serial.encode()).hexdigest() + '.json')
state = json.loads(file.read_text()) if file.exists() else {'signature': 0, 'sources': [16, 0, 1], 'main': 15, 'writes': []}
if 'setvcp' in args:
    code, value = args[-2], int(args[-1], 16)
    state['writes'].append([code, value])
    if code == 'E2':
        if value == 0: state['signature'] &= 14
        elif value == 1: state['signature'] |= 1
        elif value == 2: state['signature'] = 1
        else: state['signature'] = {3:1,4:3,5:5,6:7,7:9,8:11,9:13,16:15}[value]
    elif code == '60': state['main'] = value
    elif value == 0x1000: state['sources'][:2] = reversed(state['sources'][:2])
    else: state['sources'][value >> 8] = value & 255
    file.write_text(json.dumps(state))
else:
    e3 = 'xc0 x01' if state['signature'] in (7,9,11,13) else ' '.join(f'x{v:02x}' for v in state['sources'][:2])
    print(f"VCP 60 SNC x{state['main']:02x}\nVCP E2 CNC x00 x7f x39 xd{state['signature']:x}\nVCP E3 CNC x51 x51 {e3}")
