# M1 CPU Performance Mode for Omarchy (Asahi Linux)

## Purpose

This project sets three CPU modes on an Apple M1 under Omarchy (Asahi Linux). The modes are performance, balanced, and power-saver.

Each mode writes four kernel controls. The controls are the CPU governor, the boost flag, the PCIe ASPM policy, and the NVMe scheduler.

Performance mode holds the clock request at the top of the table when the CPU is idle. Balanced mode and power-saver mode let the clocks fall. Under a full CPU load, the hardware clock is the same in all three modes.

The systemd service applies the performance mode at boot. The service does not apply the mode after sleep.

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
- Linux shows two cpufreq policies. policy0 is cpu0–cpu3. policy4 is cpu4–cpu7.
- Hardware clock: 2064 MHz on the efficiency cores. 2988 MHz on the performance cores.
- The boost list also has 3096 MHz, 3144 MHz, and 3204 MHz. The hardware clock does not rise to those values.
- The four performance cores share one clock. An idle core in policy4 does not raise the clock of a busy core.
- Core capacity: 493 on an efficiency core. 1024 on a performance core.

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
- `cpu-performance.service` — systemd oneshot. It runs at boot. It does not run after sleep.
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
set-cpu-performance.sh performance     # hold the top clock request
set-cpu-performance.sh balanced -v     # schedutil, boost on
set-cpu-performance.sh power-saver     # schedutil, boost off
```

## Verification

Apply the mode first. Then run the helper:

```
cpu-mode performance
verify.sh
```

`verify.sh` does not apply the mode that you pass. It measures the active mode.

It reports:
- Hardware identification
- All key sysfs settings
- Current frequencies
- Quick sysbench CPU benchmark
- Thermals
- Service status

## Measured results

Test date: 2026-10-15. The machine is an Apple MacBook Air (M1, 2020). The model is j313. The SoC is t8103. The kernel is 7.1.12-2-7-ARCH. The driver is apple-cpufreq. The supply is AC power. The desktop stayed on.

Read `cpuinfo_cur_freq` during the load. The hardware clock is the same in each mode.

- Efficiency cores: 2064 MHz
- Performance cores: 2988 MHz

The load test is `sysbench cpu --cpu-max-prime=20000 --threads=8 --time=5`. Each mode ran three times. The order rotated.

| Mode | Events per second |
| --- | --- |
| power-saver | 17822.50, 17637.53, 17690.34 |
| balanced | 17778.28, 16818.42, 16775.88 |
| performance | 17442.03, 17422.31, 17563.41 |

The scores overlap. Power-saver has the highest three results. Performance mode does not increase the score under this load.

Idle power comes from the macsmc sensor "Total System Power".

| Mode | Idle power |
| --- | --- |
| performance | 13.3 W to 14.6 W |
| balanced | 9.7 W |
| power-saver | 10.2 W |

Performance mode costs about 4 W when the CPU is idle. The clocks stay at the top request. Balanced mode and power-saver mode let the clocks fall.

The 3204 MHz value is a boost label. It is not a higher hardware clock.

- In performance mode, `scaling_cur_freq` shows 3204 MHz.
- `cpuinfo_cur_freq` stays at 2988 MHz.
- One thread on cpu4 scores 3752.33 events per second with boost on.
- The same thread scores 3747.24 events per second with boost off.

The efficiency-core boost list is empty. The boost flag for policy0 stays 0. The script can still log `Boost=1`.

Balanced mode and power-saver mode both set the schedutil governor. The powersave governor is available. The script does not select it. Under this load, schedutil already uses the 2988 MHz bin. Boost off does not move the hardware clock.

You cannot set a frequency above this table. This is not an overclock. The fused table is the limit.

NAND temperature stayed near 43°C. The battery hotspot stayed near 32°C. These short tests do not show a thermal limit.

The test did not measure disk latency. The test did not measure PCIe latency. ASPM and the NVMe scheduler do change. Their speed effect is unknown.

A failed sysfs write does not stop the script. The script still prints "Applied".

Put a heavy thread on cpu4, cpu5, cpu6, or cpu7. An efficiency core has capacity 493. A performance core has capacity 1024. Use `taskset -c 4-7` for that work.

## Thermals and Power Monitoring

Performance mode increases idle power by about 4 W. It does not increase the full-load CPU score above.

Monitor with:
```
sensors
watch -n 1 'sensors | grep -E "NAND|Hotspot"'
```

Short tests on this M1, on AC power:
- NAND Flash: near 43°C
- Battery Hotspot: near 32°C
- A long job can still get hotter. This Air has no fan.

**Warnings:**
- Watch temperatures on laptops.
- Throttling can still occur due to hardware thermal limits.
- Performance mode uses more power when the CPU is idle.
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

On this Omarchy M1 (kernel 7.1.12-2-7-ARCH):
- The service is enabled. It applies the performance mode at boot.
- The governor and the boost flag change when you switch modes.
- NVMe and ASPM change when you switch modes.
- `cpuinfo_cur_freq` stays at 2988 MHz on the performance cores during load.
- `scaling_cur_freq` can show 3204 MHz. That value is the boost label.

Re-apply the mode after a kernel update if the governor returns to schedutil.

## Notes and Limitations

- The three mode names do not give three CPU speeds.
- The hardware clock under load is 2064 MHz and 2988 MHz.
- There is no overclock above the apple-cpufreq table.
- The service does not run after sleep.
- `verify.sh` does not change the mode.
- A failed write can still print "Applied".
- M1 has physical thermal and power limits.
- Some interfaces can differ on another kernel.
- Test stability on your machine.
- These changes affect power, heat, and battery life.

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
