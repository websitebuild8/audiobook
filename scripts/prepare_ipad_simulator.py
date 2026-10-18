"""Select an installed 13-inch/12.9-inch iPad simulator on a Codemagic Mac."""
import json
import os
import subprocess


def simctl(*args):
    return subprocess.check_output(['xcrun', 'simctl', *args], text=True)


def select_device(devices):
    candidates = []
    for runtime, entries in devices.items():
        if '.iOS-' not in runtime:
            continue
        version = tuple(int(part) for part in runtime.split('.iOS-')[1].split('-'))
        for device in entries:
            name = device['name']
            if device.get('isAvailable') and 'iPad Pro' in name and (
                '13-inch' in name or '12.9-inch' in name
            ):
                candidates.append((version, name, device['udid']))
    if not candidates:
        raise RuntimeError('No available 13-inch/12.9-inch iPad Pro simulator. Select a Codemagic Xcode image with an iPad Pro simulator runtime.')
    return max(candidates)[2]


if __name__ == '__main__':
    devices = json.loads(simctl('list', 'devices', 'available', '--json'))['devices']
    udid = select_device(devices)
    state = next(d['state'] for entries in devices.values() for d in entries if d['udid'] == udid)
    if state != 'Booted':
        simctl('boot', udid)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', udid, '-b'], check=True)
    simctl('status_bar', udid, 'override', '--time', '9:41', '--dataNetwork', 'wifi',
           '--wifiMode', 'active', '--wifiBars', '3', '--batteryState', 'charged', '--batteryLevel', '100')
    with open(os.environ['CM_ENV'], 'a') as env:
        env.write(f'IPAD_SIMULATOR_UDID={udid}\n')
    print(f'iPad simulator ready: {udid}')
