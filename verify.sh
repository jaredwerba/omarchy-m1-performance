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

echo "=== 3. Frequencies (may need elevation) ==="
pkexec --disable-internal-agent cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq 2>/dev/null | sort | uniq -c || echo "Run with pkexec for full freq data"
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
echo "- For performance mode, expect ~2.0-3.0 GHz sustained on M1 cores."
echo "- Compare events/sec and freqs in balanced vs performance."
echo "- Monitor temps during sustained loads."
echo "- Re-apply after kernel updates if needed."
echo
echo "Report complete. Use -v on the main script for more details during apply."
