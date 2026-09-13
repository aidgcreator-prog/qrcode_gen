"""scan_msix.py — Pre-scan MSIX staging/dist directory for compliance issues."""

import os
import sys

# Resolve target directory (defaults to deployment/msix/staging or dist)
if len(sys.argv) > 1:
    target = os.path.abspath(sys.argv[1])
else:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    stage_dir = os.path.abspath(os.path.join(script_dir, "staging"))
    dist_dir = os.path.abspath(os.path.join(script_dir, "..", "..", "dist"))
    target = stage_dir if os.path.exists(stage_dir) else dist_dir

if not os.path.exists(target):
    print(f"[!] Directory not found for scanning: {target}")
    print("    (Build or stage first before scanning)")
    sys.exit(0)

forbidden_char_issues = []
dot_issues = []
ending_issues = []
long_paths = []

for root, dirs, files in os.walk(target):
    for name in files + dirs:
        rel = os.path.relpath(os.path.join(root, name), target)
        for ch in ['<', '>', '|', '?', '*']:
            if ch in name:
                forbidden_char_issues.append(f"BAD_CHAR[{ch}]: {rel}")
        if name.startswith('.'):
            dot_issues.append(f"STARTS_PERIOD: {rel}")
        if name.endswith('.') or name.endswith(' '):
            ending_issues.append(f"ENDS_BAD: {rel}")

for root, dirs, files in os.walk(target):
    for name in files:
        full = os.path.join(root, name)
        rel = os.path.relpath(full, target)
        if len(rel) > 200:
            long_paths.append(f"LEN={len(rel)}: {rel}")

total_critical = len(forbidden_char_issues) + len(ending_issues)
print(f"[*] Scanned target: {target}")
print(f"[*] Dot-prefixed items found: {len(dot_issues)} (pruned automatically during staging)")
if dot_issues:
    for i in dot_issues[:15]:
        print(f"    - {i}")
    if len(dot_issues) > 15:
        print(f"    ... and {len(dot_issues) - 15} more.")

if forbidden_char_issues:
    print(f"[!] Forbidden character issues: {len(forbidden_char_issues)}")
    for i in forbidden_char_issues[:10]:
        print(f"    - {i}")

if ending_issues:
    print(f"[!] Trailing dot/space issues: {len(ending_issues)}")
    for i in ending_issues[:10]:
        print(f"    - {i}")

print(f"[*] Long-path items (>200 chars): {len(long_paths)}")
if long_paths:
    for i in long_paths[:5]:
        print(f"    - {i}")

if total_critical > 0 or len(long_paths) > 0:
    sys.exit(1)
sys.exit(0)
