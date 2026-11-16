"""Create allow-listed Windows payload and source archives, never personal data."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT=Path(__file__).resolve().parent
VERSIONS=json.loads((ROOT/'versions.json').read_text())
BUILD,DIST=ROOT/'build',ROOT/'dist'

def digest(data):
    return hashlib.sha256(data).hexdigest()

def checked_files(manifest):
    names=json.loads((ROOT/manifest).read_text())
    if len(names)!=len(set(names)):
        raise ValueError('Duplicate manifest entry')
    for name in names:
        parts=Path(name).parts
        if Path(name).is_absolute() or '..' in parts or '.runtime' in parts or '\\' in name:
            raise ValueError('Unsafe manifest entry')
        path=ROOT/name
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(ROOT) or any(p.is_symlink() for p in path.parents if p!=ROOT and p.is_relative_to(ROOT)):
            raise ValueError(f'Missing or linked file: {name}')
        yield name,path.read_bytes()

def archive(path,files):
    hashes={}
    with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for name,data in files:
            info=zipfile.ZipInfo(name)
            info.create_system=3
            info.external_attr=(0o100755 if name.endswith('.command') else 0o100644)<<16
            info.compress_type=zipfile.ZIP_DEFLATED
            z.writestr(info,data);hashes[name]=digest(data)
        z.writestr('FILE-HASHES.json',json.dumps(hashes,indent=2))
    with zipfile.ZipFile(path) as z:
        if z.testzip() is not None:raise ValueError('Archive CRC failure')
    print(f'{path.name}: {len(hashes)} files; CRC and SHA256 manifest generated')

def main():
    args=argparse.ArgumentParser();args.add_argument('--source-only',action='store_true');opts=args.parse_args()
    BUILD.mkdir(exist_ok=True);DIST.mkdir(exist_ok=True)
    for version in VERSIONS.values():
        if not re.fullmatch(r'\d+\.\d+\.\d+(?:-[a-z]+\.\d+)?',version):raise ValueError('Invalid version')
    source=list(checked_files('source-files.json'))
    forbidden=[b'-----BEGIN '+b'PRIVATE KEY-----']
    for name,data in source:
        if any(needle in data for needle in forbidden) or re.search(rb'[A-Za-z]:[\\/]+Users[\\/]+[A-Za-z0-9_]+',data) or re.search(rb'\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}',data):raise ValueError(f'Private data marker: {name}')
    archive(DIST/f'Codex-Quota-Sidebar-source-windows-{VERSIONS["windows"]}-macos-{VERSIONS["macos"]}.zip',source)
    extension_names=['manifest.json','background.js','panel.html','panel.css','panel.js','strings.js','icon-32.png','icon-128.png']
    extension_version=json.loads((ROOT/'browser/manifest.json').read_text())['version']
    archive(DIST/f'Codex-Quota-Sidebar-Chrome-{extension_version}.zip',[(name,(ROOT/'browser'/name).read_bytes()) for name in extension_names])
    if not opts.source_only:
        pins=json.loads((ROOT/'dependency-pins.json').read_text())
        for name,expected in pins['files'].items():
            if digest((ROOT/name).read_bytes())!=expected:raise ValueError(f'Pinned dependency mismatch: {name}')
        files=list(checked_files('runtime-files.json'))
        files.append(('Install.ps1',(ROOT/'Install.ps1').read_bytes()))
        archive(BUILD/'payload.zip',files)
    print('Mac experimental DMGs are built separately on native macOS runners; real-account acceptance remains pending.')

if __name__=='__main__':main()
