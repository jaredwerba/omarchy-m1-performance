#!/bin/bash
# verify.sh - Verification and quick benchmark helper for M1 CPU Performance Mode
# Run after applying a mode to confirm settings and get objective data.

set -euo pipefail

MODE="${1:-performance}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== M1 CPU Performance Verification Report ==="
echo "Date: $(date)"
echo "Mode tested: $MODE"
echo

echo "=== 1. Hardware ==="
cat /sys/firmware/devicetree/base/compatible 2>/dev/null | tr '\0' ' ' || echo "No DT compatible"
lscpu | grep -E 'Model name|Vendor|CPU\(s\)|Core\(s\)|Thread' | head -6
echo

echo "=== 2. Key Settings ==="
echo "Governors:"
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | sort | uniq -c
echo "Boost:"
cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || echo "N/A"
echo "ASPM policy:"
cat /sys/module/pcie_aspm/parameters/policy 2>/dev/null || echo "N/A"
echo "NVMe scheduler (nvme0n1):"
cat /sys/block/nvme0n1/queue/scheduler 2>/dev/null || echo "N/A"
echo

echo "=== 3. Frequencies ==="
if sudo -n -l /usr/local/bin/set-cpu-performance.sh >/dev/null 2>&1; then
  sudo -n -- /usr/local/bin/set-cpu-performance.sh --status | awk '/^Frequencies:/,0'
else
  cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq 2>/dev/null | sort | uniq -c || echo "Frequency files need the passwordless rule. Mode switches still work after install.sh."
fi
echo

echo "=== 4. Quick Benchmark (sysbench CPU) ==="
if command -v sysbench >/dev/null; then
    echo "Running 5s CPU benchmark (8 threads)..."
    sysbench cpu --cpu-max-prime=20000 --threads=8 --time=5 run 2>&1 | grep -E 'events per second|total time|avg:'
else
    echo "sysbench not found. Install with: sudo pacman -S sysbench"
fi
echo

echo "=== 5. Thermals (sensors) ==="
sensors 2>/dev/null | grep -E 'NAND|Hotspot|temp' | head -5 || echo "sensors output limited or not installed"
echo

echo "=== 6. Service Status ==="
systemctl status cpu-performance.service --no-pager 2>/dev/null | cat || echo "Service not found or not checked"
echo

echo "=== Recommendations ==="
echo "- This script does not change the mode. Apply the mode first."
echo "- Read cpuinfo_cur_freq for the hardware clock."
echo "- On this M1, a full load stays near 2064 MHz (E-cores) and 2988 MHz (P-cores)."
echo "- The 3204 MHz value is a boost label. It is not a higher hardware clock."
echo "- Full-load scores overlap across the three modes."
echo "- Performance mode increases idle power. It does not increase this benchmark."
echo "- Monitor temps during a long load. This Air has no fan."
echo
echo "Report complete. Use -v on the main script for more details during apply."
