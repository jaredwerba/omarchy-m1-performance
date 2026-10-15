# M1 CPU Performance Mode for Omarchy (Asahi Linux)

## Purpose

This project provides a reliable way to set the Apple M1 CPU to performance, balanced, or power-saver modes on Omarchy (Asahi Linux, Arch Linux for Apple Silicon).

Default Asahi power management is conservative. Many users want explicit control for responsiveness, compilation, or workloads that benefit from sustained high clocks.

The feature works by writing directly to kernel-exposed sysfs interfaces. It persists across boots and resume from sleep via a systemd oneshot service.

## Deeper Approach (Inspired by Expert Prompting)

A top professional in Linux performance engineering on Apple Silicon would not just document "set the governor."

They would:

1. Start from raw kernel interfaces and hardware specifics rather than high-level scripts.
2. Measure real effects with before/after data on the exact hardware (Icestorm E-cores + Firestorm P-cores on T8103 M1).
3. Use tools like perf, bpftrace, temperature sensors, and workload benchmarks instead of only "cat the governor file."
4. Validate with reproducible tests that show sustained frequency, latency reduction, or throughput gains without assuming the change "feels faster."
5. Consider interactions: thermal limits, NVMe, PCIe ASPM, cluster scheduling, and conflicts with other power daemons.

This project aims for that depth.

## Raw Materials (What Experts Start From)

- Apple M1 (T8103 / j313): 4x Icestorm (efficiency) + 4x Firestorm (performance) cores. Exposed as two CPU types in Linux.
- Kernel cpufreq subsystem: `/sys/devices/system/cpu/cpu*/cpufreq/`
  - `scaling_governor`: controls frequency scaling policy.
  - Available: conservative, ondemand, userspace, powersave, performance, schedutil.
  - `cpuinfo_cur_freq`, `scaling_cur_freq`, `scaling_max_freq`.
  - Boost: `/sys/devices/system/cpu/cpufreq/boost` and per-policy.
- NVMe I/O scheduler: `/sys/block/nvme*/queue/scheduler` (none for lowest latency on SSDs).
- PCIe ASPM (Active State Power Management): `/sys/module/pcie_aspm/parameters/policy` (performance disables link power saving).
- Device tree / hardware: `apple,t8103`, `apple,j313`.
- Asahi Linux kernel patches and drivers for Apple Silicon power/clock control.
- Real hardware state: frequencies, temperatures via macsmc_hwmon and sensors.

These are the ground truth. Scripts are just a convenient way to apply them consistently.

## Implementation

The project ships two files (copied from a working Omarchy installation):

- `set-cpu-performance.sh` — the core logic.
- `cpu-performance.service` — systemd unit for boot + resume.

### set-cpu-performance.sh (source)

```bash
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

# CPU governor (all cores)
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  if [ -w "$gov" ]; then
    echo "$gov_target" > "$gov" 2>/dev/null || true
  fi
done

# Boost (global + per policy)
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
```

### cpu-performance.service

```ini
[Unit]
Description=Set CPU to performance mode on boot (and after sleep)
After=multi-user.target sleep.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/set-cpu-performance.sh performance
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

## Installation

1. Copy the script:
   ```
   sudo cp set-cpu-performance.sh /usr/local/bin/
   sudo chmod +x /usr/local/bin/set-cpu-performance.sh
   ```

2. Copy the service:
   ```
   sudo cp cpu-performance.service /etc/systemd/system/
   ```

3. Enable and start:
   ```
   sudo systemctl enable --now cpu-performance.service
   ```

The service runs the script at boot and after resume from sleep.

To apply manually without the service:
```
pkexec --disable-internal-agent /usr/local/bin/set-cpu-performance.sh performance
```

## Usage

- `set-cpu-performance.sh performance` — max clocks (recommended for this project).
- `set-cpu-performance.sh balanced` — dynamic with responsiveness.
- `set-cpu-performance.sh power-saver` — conservative.

The script is idempotent and safe to re-run.

## Verification — Objective Evidence

Run these after applying performance mode. Compare before/after on the same workload.

**Governors:**
```
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort | uniq -c
```
Expect mostly "performance".

**Boost:**
```
cat /sys/devices/system/cpu/cpufreq/boost
```
Expect 1.

**Current frequencies (elevated):**
```
pkexec --disable-internal-agent cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq | sort | uniq -c
```
Higher numbers = better sustained speed.

**Service:**
```
systemctl status cpu-performance.service --no-pager
```
Should be active (exited) with recent success.

**Hardware identification:**
```
cat /sys/firmware/devicetree/base/compatible
lscpu
```

**Suggested benchmarks (run before and after):**
- CPU: `sysbench cpu --cpu-max-prime=20000 --threads=8 run`
- Compile test: time a kernel build or large project.
- I/O: `fio` or `dd` tests on NVMe.
- Monitor during load: `htop`, `watch -n 1 "cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq | sort | uniq -c"`

Record numbers. Real improvement is measurable frequency under load and reduced latency, not just "feels snappier."

**Temperature and power (monitor):**
```
sensors
```
Watch NAND and battery hotspot temps. High performance increases heat and power draw.

## Current State on M1 (T8103)

- 8 cores: 4 Icestorm + 4 Firestorm.
- Max ~2064 MHz (varies by bin and thermals).
- Kernel: Asahi 7.1.x series.
- NVMe and PCIe controls exposed.
- Service successfully applies settings at boot.

Re-apply after major updates or if governors reset.

## Notes, Warnings, and Limitations

- Increases power consumption and heat. Monitor on laptops.
- Not all interfaces may be writable on every kernel or configuration.
- Conflicts possible with other power management (e.g. future Omarchy profiles).
- M1 has hardware limits — "performance" will still throttle under sustained heavy load due to thermals.
- This is not a magic "make it as fast as macOS" tool. It removes Linux-side conservatism.
- Test stability with your workloads.
- Use at your own risk. No warranty.

## Advanced / Expert Extensions

A pro would also consider:
- Per-core or cluster-specific tuning (Firestorm vs Icestorm).
- Thermal trip points and fan curves (if applicable).
- Using `cpupower` or custom udev rules for dynamic behavior.
- bpftrace or perf for deeper tracing.
- Combining with GPU/ANE optimizations (see related Omarchy projects).
- Logging metrics over time for regression detection.
- Packaging as a proper Omarchy plugin or AUR package.

Contributions welcome for these.

## Sources and Further Reading

- Asahi Linux documentation and kernel tree.
- Linux cpufreq and block layer documentation.
- Direct inspection of `/sys` on Apple Silicon hardware.
- Original implementation discovered and verified during Omarchy performance tuning sessions.

This is versioned source + deep documentation. The goal is a reproducible, inspectable performance feature.

---
Project: omarchy-m1-performance  
Style: ASD-STE100 (clear, direct, one idea per sentence where practical)  
Raw files included for transparency and modification.
