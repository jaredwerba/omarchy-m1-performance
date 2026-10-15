#!/bin/bash
set -euo pipefail

# Enhanced M1/Apple Silicon CPU Performance Mode script for Omarchy (Asahi Linux)
# Applies performance, balanced, or power-saver settings via direct sysfs writes.
# Includes hardware detection, logging, before/after where possible.

VERSION="2.0-enhanced"
SCRIPT_NAME=$(basename "$0")

usage() {
    cat << EOF
$SCRIPT_NAME - Set CPU performance mode on Apple Silicon (M1+)

Usage: $SCRIPT_NAME [MODE] [OPTIONS]

Modes:
  performance   Maximum clocks, boost enabled, low-latency I/O (default)
  balanced      Dynamic scaling with good responsiveness
  power-saver   Conservative for battery/heat savings

Options:
  -h, --help     Show this help
  -v, --verbose  Verbose output with before/after details
  --version      Show version

Examples:
  sudo -S -p '' $SCRIPT_NAME performance
  $SCRIPT_NAME balanced -v

Notes:
  - Requires write access to /sys (use pkexec or root for full effect)
  - Persists via the accompanying systemd service
  - Increases power/heat in performance mode
EOF
}

VERBOSE=0
MODE="${1:-performance}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        -v|--verbose) VERBOSE=1; shift ;;
        --version) echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
        performance|balanced|power-saver|powersave) MODE="$1"; shift ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

detect_hardware() {
    if [ -f /sys/firmware/devicetree/base/compatible ]; then
        if grep -q "apple,t8103\|apple,j313" /sys/firmware/devicetree/base/compatible 2>/dev/null; then
            log "Detected: Apple M1 (T8103 / j313) - Icestorm + Firestorm cores"
            return 0
        fi
    fi
    if lscpu 2>/dev/null | grep -qi "Apple"; then
        log "Detected: Apple Silicon (generic)"
        return 0
    fi
    log "Warning: Not clearly detected as Apple M1. Proceeding anyway."
}

show_before() {
    if [ "$VERBOSE" -eq 1 ]; then
        log "Before state:"
        echo "  Governors: $(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | sort | uniq -c | tr '\n' ' ')"
        echo "  Boost: $(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || echo 'N/A')"
        echo "  ASPM: $(cat /sys/module/pcie_aspm/parameters/policy 2>/dev/null || echo 'N/A')"
        echo "  NVMe sched: $(cat /sys/block/nvme0n1/queue/scheduler 2>/dev/null || echo 'N/A')"
    fi
}

apply_settings() {
    case "$MODE" in
      performance)
        gov_target="performance"
        boost_val=1
        aspm_policy="performance"
        sched="none"
        msg="performance (max clocks, no power saving)"
        ;;
      balanced)
        gov_target="schedutil"
        boost_val=1
        aspm_policy="default"
        sched="mq-deadline"
        msg="balanced (dynamic + good responsiveness)"
        ;;
      power-saver|powersave)
        gov_target="schedutil"
        boost_val=0
        aspm_policy="powersave"
        sched="mq-deadline"
        msg="power-saver (lower clocks, more savings)"
        ;;
      *)
        log "Unknown mode $MODE, defaulting to performance"
        gov_target="performance"
        boost_val=1
        aspm_policy="performance"
        sched="none"
        msg="performance"
        ;;
    esac

    log "Applying $msg ..."

    # CPU governor - all cores
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
      if [ -w "$gov" ]; then
        echo "$gov_target" > "$gov" 2>/dev/null || true
      fi
    done

    # Boost - global and per-policy
    if [ -w /sys/devices/system/cpu/cpufreq/boost ]; then
      echo "$boost_val" > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
    fi
    for b in /sys/devices/system/cpu/cpufreq/policy*/boost; do
      if [ -w "$b" ]; then
        echo "$boost_val" > "$b" 2>/dev/null || true
      fi
    done

    # NVMe scheduler for low latency
    for dev in /sys/block/nvme*/queue/scheduler; do
      if [ -w "$dev" ]; then
        echo "$sched" > "$dev" 2>/dev/null || true
      fi
    done

    # PCIe ASPM policy
    if [ -w /sys/module/pcie_aspm/parameters/policy ]; then
      echo "$aspm_policy" > /sys/module/pcie_aspm/parameters/policy 2>/dev/null || true
    fi

    log "Applied: Governor=$gov_target, Boost=$boost_val, ASPM=$aspm_policy, Sched=$sched"
}

show_after() {
    if [ "$VERBOSE" -eq 1 ]; then
        log "After state:"
        echo "  Governors: $(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | sort | uniq -c | tr '\n' ' ')"
        echo "  Boost: $(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || echo 'N/A')"
    fi
    log "CPU $msg settings applied."
}

main() {
    detect_hardware
    show_before
    apply_settings
    show_after
    echo "Done. Re-run with -v for before/after details."
}

main "$@"
