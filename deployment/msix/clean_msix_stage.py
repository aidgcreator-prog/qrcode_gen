"""clean_msix_stage.py — Remove MSIX-incompatible files from the staging directory.

MSIX (AppX) package format rules:
1. Directory names starting with an UNDERSCORE (_) are FORBIDDEN by MSIX/OPC.
2. Files/folders starting with a PERIOD (.) are FORBIDDEN.
3. OPC System Reserved Filenames: [Content_Types].xml
4. OPC Invalid Characters: [ ] # % < > : " | ? *
5. '+' (and URL-encoded '%2B') are rejected by MakeAppx (0x8007000b).
"""

import os
import sys
import shutil

INVALID_CHARS = set('[]#%+<>:"|?*')
RESERVED_FILENAMES = frozenset([
    '[Content_Types].xml',
])

NOARCHIVE_ERROR = """\
[FATAL] MSIX stage contains a PyInstaller 'noarchive=True' module tree:
  {paths}
With noarchive=True, PyInstaller writes every pure-Python module as an on-disk
.pyc tree (e.g. pkg_resources/_vendor). MSIX/OPC forbids '_'-prefixed
directory names, so stripping these trees would ship a bundle that crashes at
startup with:
    ImportError: The 'jaraco' package is required
FIX: rebuild with noarchive=False in build.spec.
ABORTING — nothing was deleted.
"""


def _dir_holds_direct_pyc(abs_dir: str) -> bool:
    for root, _dirs, files in os.walk(abs_dir):
        if os.path.basename(root) == "__pycache__":
            continue
        for name in files:
            if name.endswith(".pyc"):
                return True
    return False


def find_noarchive_module_trees(stage_dir: str) -> list:
    stage_dir = os.path.abspath(stage_dir)
    offenders = []
    for root, dirs, _files in os.walk(stage_dir):
        for d in dirs:
            if not d.startswith("_"):
                continue
            if _dir_holds_direct_pyc(os.path.join(root, d)):
                offenders.append(os.path.relpath(os.path.join(root, d), stage_dir))
    return offenders


def classify(name: str, is_dir: bool, is_root_dir: bool = False) -> str | None:
    if is_dir:
        if is_root_dir and name.startswith('_'):
            return f"root dir starts with '{name[0]}'"
        if name == "_rels":
            return "OPC-reserved relationship directory name"
        if name.startswith('.'):
            return f"dir starts with '.'"
        if name == "__pycache__":
            return "pycache directory"
        if name == "licenses":
            return "dist-info licenses directory"
    else:
        if name.startswith('.'):
            return f"file starts with '.'"
        if name in RESERVED_FILENAMES:
            return "OPC-reserved system filename"

    if name.endswith('.') or name.endswith(' '):
        return "ends with period or space"

    for ch in INVALID_CHARS:
        if ch in name:
            return f"contains invalid char '{ch}'"

    return None


def clean(stage_dir: str) -> int:
    removed = 0
    stage_dir = os.path.abspath(stage_dir)

    offenders = find_noarchive_module_trees(stage_dir)
    if offenders:
        shown = ", ".join(offenders[:5])
        if len(offenders) > 5:
            shown += f" ... ({len(offenders)} total)"
        raise SystemExit(NOARCHIVE_ERROR.format(paths=shown))

    for root, dirs, files in os.walk(stage_dir, topdown=True):
        is_root = (os.path.abspath(root) == stage_dir)

        to_prune = []
        for d in list(dirs):
            reason = classify(d, is_dir=True, is_root_dir=is_root)
            if reason:
                full = os.path.join(root, d)
                rel = os.path.relpath(full, stage_dir)
                print(f"  [REMOVE-DIR ] {rel}  ({reason})")
                shutil.rmtree(full, ignore_errors=True)
                to_prune.append(d)
                removed += 1
        for d in to_prune:
            dirs.remove(d)

        for f in list(files):
            if is_root and f in ('AppxManifest.xml', 'QRCodeGenerator.exe'):
                continue
            reason = classify(f, is_dir=False)
            if reason:
                full = os.path.join(root, f)
                rel = os.path.relpath(full, stage_dir)
                print(f"  [REMOVE-FILE] {rel}  ({reason})")
                try:
                    os.remove(full)
                    removed += 1
                except OSError as e:
                    print(f"  [WARN] Could not remove {full}: {e}")

    # Post-clean verification
    remaining = []
    for root, dirs, files in os.walk(stage_dir, topdown=True):
        is_root = (os.path.abspath(root) == stage_dir)
        for d in dirs:
            reason = classify(d, is_dir=True, is_root_dir=is_root)
            if reason:
                remaining.append(os.path.relpath(os.path.join(root, d), stage_dir))
        for f in files:
            if is_root and f in ('AppxManifest.xml', 'QRCodeGenerator.exe'):
                continue
            reason = classify(f, is_dir=False)
            if reason:
                remaining.append(os.path.relpath(os.path.join(root, f), stage_dir))
    if remaining:
        shown = "\n  ".join(remaining[:10])
        if len(remaining) > 10:
            shown += f"\n  ... ({len(remaining)} total)"
        raise SystemExit(
            f"\n[FATAL] MSIX staging still contains {len(remaining)} invalid file(s) "
            f"after cleanup:\n  {shown}\n"
            f"MakeAppx will reject these. Fix the source or add them to clean_msix_stage.py."
        )

    return removed


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python clean_msix_stage.py <stage_dir>")
        sys.exit(1)

    stage = sys.argv[1]
    if not os.path.isdir(stage):
        print(f"[ERROR] Stage directory not found: {stage}")
        sys.exit(1)

    print(f"[*] Scanning for MSIX-incompatible names in: {stage}")
    count = clean(stage)
    print(f"[OK] Removed {count} incompatible item(s).")
