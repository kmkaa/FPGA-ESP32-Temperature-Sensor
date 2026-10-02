import subprocess
import re
import sys
from datetime import datetime 

#test vectors 
TEST_VECTORS = [
    "0000000000",
    "1111111111",
    "1010101010",
    "0101010101",
    "1100110011",
    "1000000001",
    "0111111110",
    "1001100110",
]

TESTBENCHES = [
    ("SPI Master (MCP3008)", "mcp3008_spi_master_tb"),
    ("SPI follower (ESP32)", "esp32_spi_follower_tb"),
]

PASS_RE = re.compile(r"PASS: .*matches", re.IGNORECASE)
FAIL_RE = re.compile(r"FAIL:", re.IGNORECASE)


def run_one(tb_name: str, vector: str) -> tuple[bool, str]:
    cmd = [
        "vsim", "-c", "-lib", "work", tb_name,
        f"+GOLDEN={vector}",
        "-do", "run -all; quit -f",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    output = result.stdout + result.stderr
 
    passed = bool(PASS_RE.search(output)) and not bool(FAIL_RE.search(output))
    return passed, output
 
 
def main() -> int:
    print(f"=== Regression run started: {datetime.now().isoformat(timespec='seconds')} ===\n")
 
    total = 0
    total_pass = 0
    failures = []
 
    for friendly_name, tb_name in TESTBENCHES:
        print(f"--- {friendly_name} ({tb_name}) ---")
        for vector in TEST_VECTORS:
            total += 1
            try:
                passed, output = run_one(tb_name, vector)
            except FileNotFoundError:
                print("ERROR: 'vsim' not found on PATH. "
                      "Run this from a Questa/ModelSim-enabled shell.")
                return 2
            except subprocess.TimeoutExpired:
                passed = False
                output = "(simulation timed out)"
 
            status = "PASS" if passed else "FAIL"
            print(f"  vector={vector}  ->  {status}")
 
            if passed:
                total_pass += 1
            else:
                failures.append((friendly_name, vector, output))
        print()
 
    total_fail = total - total_pass
 
    print("=== Regression Summary ===")
    print(f"  Total tests run : {total}")
    print(f"  Passed          : {total_pass}")
    print(f"  Failed          : {total_fail}")
    print()
 
    if failures:
        print("=== Failure Details ===")
        for name, vector, output in failures:
            print(f"[{name}] vector={vector}")
            print(output.strip())
            print("-" * 60)
 
    # Write a plain-text report file alongside the script, useful as a
    # concrete artifact for a portfolio README or CI log.
    report_path = "regression_report.txt"
    with open(report_path, "w") as f:
        f.write(f"Regression run: {datetime.now().isoformat(timespec='seconds')}\n")
        f.write(f"Total: {total}  Passed: {total_pass}  Failed: {total_fail}\n\n")
        for name, vector, output in failures:
            f.write(f"[FAIL] {name} vector={vector}\n{output}\n{'-'*60}\n")
    print(f"Report written to {report_path}")
 
    return 0 if total_fail == 0 else 1
 
 
if __name__ == "__main__":
    sys.exit(main())