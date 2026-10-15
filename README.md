# M1 CPU Performance Mode for Omarchy (Asahi Linux)

## Purpose

This project provides a reliable, inspectable way to control Apple M1 CPU modes (performance, balanced, power-saver) on Omarchy (Asahi Linux).

Default Asahi power management prioritizes efficiency. This gives explicit control for workloads needing sustained high clocks, lower latency, or better responsiveness.

Changes are applied directly to kernel sysfs interfaces and persist via systemd across boots and sleep/wake.

**How to install:** See the full guide in [INSTALL.md](INSTALL.md).

## Deeper Approach

A top Linux performance engineer working on Apple Silicon would go beyond basic "set governor" instructions. They start from hardware and raw kernel interfaces, measure real effects with data, use proper tools for validation, and document interactions and limits.

This project follows that:

- Raw materials first (sysfs, device tree, M1 specifics).
- Objective evidence (frequencies, benchmarks, temps).
- Reproducible verification.
- Versioned source code included.
- Notes on thermals, power, and Omarchy integration.

## Hardware

- Apple M1 (T8103 / j313)
- 8 cores: 4× Icestorm (efficiency) + 4× Firestorm (performance)
- Exposed in Linux with separate cpufreq policies
- Max observed: ~2064 MHz (E-cores) / ~2988 MHz (P-cores) under performance

## Raw Materials (What Experts Use)

Direct sysfs and kernel interfaces:

- CPU: `/sys/devices/system/cpu/cpu*/cpufreq/`
  - `scaling_governor` (performance, schedutil, etc.)
  - `cpuinfo_cur_freq`, `scaling_cur_freq`
  - Boost: `/sys/devices/system/cpu/cpufreq/boost` and `policy*/boost`
- Storage I/O: `/sys/block/nvme*/queue/scheduler` (`none` for lowest latency)
- PCIe power: `/sys/module/pcie_aspm/parameters/policy` (`performance`)
- Hardware ID: `/sys/firmware/devicetree/base/compatible` (`apple,t8103`, `apple,j313`)
- Sensors: macsmc_hwmon, `sensors` command for NAND/Battery temps

These are the ground truth. The scripts are a safe, repeatable wrapper.

## Raw Interfaces Reference (Expanded)

Key paths and what they control:

- `/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor` — frequency policy per core
- `/sys/devices/system/cpu/cpufreq/boost` — global boost enable (1=on)
- `/sys/block/nvme*/queue/scheduler` — I/O scheduler (none = minimal overhead)
- `/sys/module/pcie_aspm/parameters/policy` — link power management
- `/sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq` — current frequency (read-only, often needs root)
- Device tree for silicon identification

Additional places experts check:
- `lscpu`, `/proc/cpuinfo`
- `dmesg | grep -i apple|freq|aspm`
- Thermal zones if available
- Asahi kernel patches for cpufreq and power

## Implementation

The project includes:

- `set-cpu-performance.sh` (v2.0-enhanced) — main logic with hardware detection, logging, verbose before/after, help
- `cpu-performance.service` — systemd oneshot for boot + resume
- `verify.sh` — report generator with checks + quick benchmark

### Enhanced Script Features

- Automatic Apple M1 detection (T8103/j313)
- Timestamped logging
- `-v / --verbose`: shows before/after states
- `--help` and `--version`
- Clear mode handling
- Comments explaining each sysfs write

Full source is in the repo files.

## Installation

See the full step-by-step guide in [INSTALL.md](INSTALL.md).

Quick summary:

1. Clone the repo.
2. Copy the script and service files to the system.
3. Enable the systemd service.
4. Apply a profile with `cpu-mode`. No password after install.
5. Run `verify.sh` to confirm.

The guide also covers switching modes, uninstall, and troubleshooting.

## Usage

```
set-cpu-performance.sh performance     # max performance (recommended)
set-cpu-performance.sh balanced -v     # dynamic with details
set-cpu-performance.sh power-saver
```

## Verification

Run the helper after applying a mode:

```
verify.sh performance
```

It reports:
- Hardware identification
- All key sysfs settings
- Current frequencies
- Quick sysbench CPU benchmark
- Thermals
- Service status

## Benchmark Results (Example on this M1)

**Hardware:** Apple M1 (T8103), 8 cores (4 Icestorm + 4 Firestorm)

**Performance mode (confirmed governors=performance, boost=1):**
- Frequencies sustained: 4× 2064 MHz, 4× 2988 MHz
- Sysbench CPU (5s, 8 threads, max-prime=20000): ~16799 – 17048 events per second
- Temps (light load): NAND ~38-39.5°C, Battery hotspot ~27-28°C

**Settings applied:**
- Governor: performance
- Boost: 1
- ASPM: performance
- NVMe scheduler: none

**Service:** active (exited), runs on boot and after sleep.

**Note on comparison:** Switch to balanced (`set-cpu-performance.sh balanced`) and re-run `verify.sh` to compare events/sec and frequency distribution. Performance mode keeps higher sustained clocks.

These are real captured outputs. Reproduce on your hardware for your baseline.

## Thermals and Power Monitoring

Performance mode increases power draw and heat.

Monitor with:
```
sensors
watch -n 1 'sensors | grep -E "NAND|Hotspot"'
```

Typical observations (M1, light-moderate load):
- NAND Flash: 36-42°C
- Battery Hotspot: ~25-30°C
- Higher under sustained CPU load

**Warnings:**
- Watch temperatures on laptops.
- Throttling can still occur due to hardware thermal limits.
- Increased power consumption in performance mode.
- Test with your specific workloads and ambient conditions.

For long sessions, combine with monitoring tools and consider balanced for mixed use.

## Omarchy Integration

This fits well with Omarchy's customization focus.

Ideas for deeper integration:
- Add to Omarchy menu / quick actions (fuzzel or similar).
- Create Omarchy plugin for mode switching.
- Tie into existing performance scripts or services.
- Use in combination with other Omarchy-mlx, video decode, or tuning projects.
- The install script adds a scoped passwordless sudo rule for profile switches.
- Log applies to journal for auditing.

Check `/usr/share/omarchy/bin/` and Omarchy docs for menu/plugin patterns.

## Current State Example

On this Omarchy M1 installation (kernel ~7.1.12 asahi):
- Service enabled and recently successful.
- All controls writable.
- Frequencies reach the higher bins in performance mode.
- NVMe and ASPM respond to the settings.

Re-apply after major updates if governors reset to schedutil.

## Notes and Limitations

- This removes conservative Linux defaults; it is not a full macOS parity tool.
- M1 has physical thermal and power limits.
- Some interfaces may vary by exact kernel or configuration.
- Always test stability.
- Use at your own risk. Changes affect power, heat, and potentially battery life.

## Advanced / Expert Extensions

Professionals would also explore:
- Cluster-aware tuning (differentiate E vs P cores)
- Custom udev rules or cgroups
- `perf`, `bpftrace`, or `powertop` for deeper profiling
- Thermal trip points and fan control (where exposed)
- Packaging as Omarchy plugin or AUR package
- Long-term metrics collection
- GPU/ANE + CPU co-optimization (see related projects)

Contributions and improvements welcome.

## Sources

- Direct system inspection on Apple M1 running Omarchy/Asahi.
- Linux cpufreq, block, and pcie_aspm documentation.
- Asahi Linux kernel and device tree.
- Captured tool output from real hardware.

## Files in This Repo

- README.md (this file)
- set-cpu-performance.sh (enhanced v2)
- cpu-performance.service
- verify.sh (benchmark + report helper)

This is a living, versioned project with real source and measurable data.

---
Style: ASD-STE100 (clear, direct language).  
Goal: Depth and reproducibility over superficial description.
