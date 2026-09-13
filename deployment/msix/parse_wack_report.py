"""parse_wack_report.py — Parse and summarize Windows App Certification Kit (WACK) XML report."""

import os
import sys
import xml.etree.ElementTree as ET


def parse_report(report_path: str) -> int:
    if not os.path.exists(report_path):
        print(f"[WARN] Report file not found: {report_path}")
        return 1

    try:
        tree = ET.parse(report_path)
        root = tree.getroot()
        passed = 0
        mandatory_failed = 0
        optional_failed = 0
        warnings = 0

        fail_details = []
        warn_details = []

        for test in root.iter("TEST"):
            res = (test.get("RESULT") or "").strip().upper()
            if not res:
                res_el = test.find("RESULT")
                if res_el is not None and res_el.text:
                    res = res_el.text.strip().upper()

            is_optional = (test.get("OPTIONAL") or "").strip().upper() == "TRUE"
            name = test.get("NAME") or test.get("Title") or "Unknown Test"

            # Collect messages
            messages = []
            messages_el = test.find("MESSAGES")
            if messages_el is not None:
                for msg in messages_el.iter("MESSAGE"):
                    txt = (msg.get("TEXT") or msg.text or "").strip()
                    if txt:
                        messages.append(txt)

            if res == "PASS":
                passed += 1
            elif res == "FAIL":
                if is_optional:
                    optional_failed += 1
                    fail_details.append((name, True, messages))
                else:
                    mandatory_failed += 1
                    fail_details.append((name, False, messages))
            elif res in ("WARNING", "WARN"):
                warnings += 1
                warn_details.append((name, is_optional, messages))

        if fail_details:
            print("\n  Failures:")
            for name, is_opt, msgs in fail_details:
                opt_tag = " (Optional/Info for Desktop Bridge)" if is_opt else " [MANDATORY]"
                print(f"    - [FAIL]{opt_tag} {name}")
                for m in msgs[:5]:
                    print(f"        * {m}")
                if len(msgs) > 5:
                    print(f"        * ... ({len(msgs) - 5} more)")

        if warn_details:
            print("\n  Warnings:")
            for name, is_opt, msgs in warn_details:
                print(f"    - [WARN] {name}")
                for m in msgs[:3]:
                    print(f"        * {m}")

        print(f"\n[+] Passed Tests     : {passed}")
        if warnings > 0:
            print(f"[!] Warnings         : {warnings}")
        if optional_failed > 0:
            print(f"[*] Optional / Info  : {optional_failed} (Permitted for fullTrust Desktop Bridge apps)")
        if mandatory_failed > 0:
            print(f"[X] Mandatory Failed : {mandatory_failed}")
            return 1
        else:
            print(f"[+] Mandatory Failed : 0 (PASSED STORE COMPLIANCE)")
            return 0

    except Exception as e:
        print(f"[ERROR] Failed to parse WACK XML report: {e}")
        return 1


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python parse_wack_report.py <wack_report.xml>")
        sys.exit(1)

    sys.exit(parse_report(sys.argv[1]))
