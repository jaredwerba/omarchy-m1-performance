#!/bin/bash
set -euo pipefail

# Enhanced M1/Apple Silicon CPU Performance Mode script for Omarchy (Asahi Linux)
# Applies performance, balanced, or power-saver settings via direct sysfs writes.
# If you are not root, this re-runs itself through passwordless sudo.
# That only works after install.sh writes the scoped sudoers rule.

VERSION="2.1-nopasswd"
SCRIPT_NAME=$(basename "$0")
INSTALLED_PATH="/usr/local/bin/set-cpu-performance.sh"

# Help and version do not need root. Every real mode change does.
needs_root=1
for arg in "$@"; do
  case "$arg" in
    -h|--help|--version) needs_root=0 ;;
  esac
done

if [[ "$(id -u)" -ne 0 && "$needs_root" -eq 1 ]]; then
  target="$INSTALLED_PATH"
  if [[ ! -x "$target" ]]; then
    target="$0"
  fi
  if ! sudo -n -- "$target" "$@"; then
    echo "Could not switch mode without a password." >&2
    echo "Install the one-time rule: sudo ./install.sh" >&2
    echo "After that, run: $SCRIPT_NAME performance" >&2
    exit 1
  fi
  exit 0
fi

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
  --status      Print current settings and exit. Does not change anything
  --version      Show version

Examples:
  $SCRIPT_NAME performance
  $SCRIPT_NAME balanced -v
  cpu-mode power-saver

Notes:
  - Mode changes need root once, via a scoped passwordless sudo rule
  - Run install.sh once. Later switches do not ask for a password
  - Persists via the accompanying systemd service
  - Increases power/heat in performance mode
EOF
}

VERBOSE=0
STATUS=0
MODE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        -v|--verbose) VERBOSE=1; shift ;;
        --status) STATUS=1; shift ;;
        --version) echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
        performance|balanced|power-saver|powersave) MODE="$1"; shift ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

MODE="${MODE:-performance}"

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

print_status() {
    echo "Governors: $(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | sort | uniq -c | tr '\n' ' ')"
    echo "Boost: $(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || echo N/A)"
    echo "ASPM: $(cat /sys/module/pcie_aspm/parameters/policy 2>/dev/null || echo N/A)"
    echo "NVMe: $(cat /sys/block/nvme0n1/queue/scheduler 2>/dev/null || echo N/A)"
    echo "Frequencies:"
    cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq 2>/dev/null | sort | uniq -c || echo "  unreadable"
}

main() {
    if [[ "$STATUS" -eq 1 ]]; then
        print_status
        exit 0
    fi
    detect_hardware
    show_before
    apply_settings
    show_after
    echo "Done. Re-run with -v for before/after details."
}

main "$@"
