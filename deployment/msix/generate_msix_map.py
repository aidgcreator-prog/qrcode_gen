"""generate_msix_map.py — Generate a MakeAppx mapping file from the staging directory.

Uses MakeAppx /f (mapping file) mode.

MSIX packaging rules:
- Subfolder names starting with '_' or '.' are FORBIDDEN (e.g. _rels, .libs)
- Filenames starting with '.' are FORBIDDEN
- OPC Reserved filenames: [Content_Types].xml
- Invalid chars: [ ] # % < > : " | ? *
"""

import os
import sys

INVALID_CHARS = set('[]#%+<>:"|?*')
RESERVED_FILENAMES = frozenset([
    '[Content_Types].xml',
])


def is_invalid(name: str, is_dir: bool, is_root_dir: bool = False) -> bool:
    if is_dir:
        if is_root_dir and name.startswith('_'):
            return True
        if name == "_rels":
            return True
        if name.startswith('.'):
            return True
        if name == "__pycache__":
            return True
        if name == "licenses":
            return True
    else:
        if name.startswith('.'):
            return True
        if name in RESERVED_FILENAMES:
            return True

    if name.endswith('.') or name.endswith(' '):
        return True

    for ch in INVALID_CHARS:
        if ch in name:
            return True

    return False


def generate_map(stage_dir: str, map_file: str) -> None:
    stage_dir = os.path.abspath(stage_dir)
    included = 0
    skipped = 0

    with open(map_file, 'w', encoding='utf-8') as f:
        f.write('[Files]\n')
        for root, dirs, files in os.walk(stage_dir, topdown=True):
            is_root = (os.path.abspath(root) == stage_dir)
            # Prune dirs with invalid names
            dirs[:] = [d for d in dirs if not is_invalid(d, is_dir=True, is_root_dir=is_root)]

            for name in files:
                if is_invalid(name, is_dir=False):
                    skipped += 1
                    continue

                abs_path = os.path.join(root, name)
                rel_path = os.path.relpath(abs_path, stage_dir)
                f.write(f'"{abs_path}" "{rel_path}"\n')
                included += 1

    print(f'[OK] Map written: {map_file}')
    print(f'     Included : {included} files')
    print(f'     Skipped  : {skipped} files')


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Usage: python generate_msix_map.py <stage_dir> <output_map_file>')
        sys.exit(1)
    generate_map(sys.argv[1], sys.argv[2])
