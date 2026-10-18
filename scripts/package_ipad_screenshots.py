"""Validate the complete screenshot set before creating the upload archive."""
from pathlib import Path
import struct
import zipfile

root = Path('build/app-store-screenshots')
files = sorted((root / 'ipad-13').glob('*.png'))
expected = {f'{number:02}-{screen}-{mode}.png'
            for number, screen in enumerate(['library', 'books', 'audiobooks', 'reader', 'audio-player'], 1)
            for mode in ['light', 'dark']}
if {file.name for file in files} != expected:
    raise SystemExit('Incomplete screenshot set; expected 10 light/dark screenshots.')
for file in files:
    data = file.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', data[16:24]) not in {(2064, 2752), (2048, 2732)}:
        raise SystemExit(f'Invalid screenshot format or dimensions: {file.name}')
with zipfile.ZipFile(root / 'ipad-13-screenshots.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in files:
        archive.write(file, file.name)
print('Packaged 10 iPad screenshots. Inspect all images before App Store upload.')
