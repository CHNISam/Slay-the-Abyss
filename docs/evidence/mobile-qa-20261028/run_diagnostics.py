"""Replay the six investigation cases; success confirms baseline observations, not fixes."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
CASES = [
    ("mobile-map-lock-repro.lua", "MAP_LOST_RELEASE_CURRENT_SOURCE_CONFIRMED"),
    ("mobile-touch-carry-repro.lua", "TOUCH_CARRY_CURRENT_SOURCE_CONFIRMED"),
    ("mobile-overlay-repro.lua", "OVERLAY_REWARD_SKIP_FRESH_POINTER_RESTORED"),
    ("mobile-click-only-actions-repro.lua", "MIXED_HOST_REWARD_RECOVERS_AFTER_EXIT"),
    ("mobile_rules_diag.lua", "MOBILE_RULES_DIAG_PASS"),
    ("mobile_target_diag.lua", "MOBILE_TARGET_DIAG_PASS"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    environment = os.environ.copy()
    environment["LUA_PATH"] = "src/lua/?.lua;build/lua/?.lua;;"
    environment["LUA_INIT"] = ""
    results = []
    for filename, marker in CASES:
        try:
            process = subprocess.run(
                [str(ROOT / "node_modules/.bin/fengari"), str(HERE / filename)],
                cwd=ROOT, env=environment, capture_output=True, text=True, timeout=30,
            )
            # Fengari can print a Lua failure while returning zero: inspect evidence too.
            passed = (process.returncode == 0 and marker in process.stdout
                      and not process.stderr.strip() and "stack traceback:" not in process.stdout)
            result = {"file": filename, "exit_code": process.returncode,
                      "expected_marker": marker, "observation_confirmed": passed,
                      "stdout": process.stdout, "stderr": process.stderr}
        except subprocess.TimeoutExpired as error:
            result = {"file": filename, "exit_code": None, "expected_marker": marker,
                      "observation_confirmed": False, "error": str(error)}
        results.append(result)
        print(f"{filename}: {'OBSERVATION_CONFIRMED' if result['observation_confirmed'] else 'FAILED'}")
    evidence = {"baseline": "7a87de3aec83281221a3680b0d02aeb5b41aa2ba",
                "meaning": "Baseline diagnosis and negative controls; no production fix or device acceptance",
                "cases": results}
    if args.output:
        args.output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if not all(result["observation_confirmed"] for result in results):
        print(json.dumps(evidence, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    print(f"Confirmed {len(results)}/{len(results)} diagnostic observations; production fixes NOT performed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
