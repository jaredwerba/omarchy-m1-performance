#!/bin/bash
set -euo pipefail

mode="${1:-performance}"

echo "Setting CPU to $mode mode..."

case "$mode" in
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
    echo "Unknown mode $mode, defaulting to performance"
    gov_target="performance"
    boost_val=1
    aspm_policy="performance"
    sched="none"
    msg="performance"
    ;;
esac

# CPU governor
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  if [ -w "$gov" ]; then
    echo "$gov_target" > "$gov" 2>/dev/null || true
  fi
done

# Boost
if [ -w /sys/devices/system/cpu/cpufreq/boost ]; then
  echo "$boost_val" > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
fi
for b in /sys/devices/system/cpu/cpufreq/policy*/boost; do
  if [ -w "$b" ]; then
    echo "$boost_val" > "$b" 2>/dev/null || true
  fi
done

# NVMe scheduler
for dev in /sys/block/nvme*/queue/scheduler; do
  if [ -w "$dev" ]; then
    echo "$sched" > "$dev" 2>/dev/null || true
  fi
done

# PCIe ASPM
if [ -w /sys/module/pcie_aspm/parameters/policy ]; then
  echo "$aspm_policy" > /sys/module/pcie_aspm/parameters/policy 2>/dev/null || true
fi

echo "CPU $msg settings applied. Governor: $gov_target, boost: $boost_val"
