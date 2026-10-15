# M1 CPU Performance Mode Feature

## Introduction

This document describes a feature.

The feature sets the central processing unit (CPU) of M1 chips to performance mode.

It runs on Asahi Linux. Asahi Linux is Arch Linux for Apple Silicon computers.

The feature was built recently. It helps the CPU run at full speed. It reduces power saving.

## What the Feature Does

The feature changes these system settings for best performance:

- Sets the CPU governor to performance on all cores. The CPU stays at high clocks.
- Enables CPU boost. Higher speeds become possible.
- Sets the NVMe disk scheduler to none. This lowers input and output delay.
- Sets the PCIe ASPM policy to performance. Link power saving is reduced.

The feature supports three modes:

- performance: maximum speed and responsiveness.
- balanced: dynamic speed with good balance.
- power-saver: lower speed to save power.

## Main Files

The main script is at this path: /usr/local/bin/set-cpu-performance.sh

The systemd service is at this path: /etc/systemd/system/cpu-performance.service

The service starts the script at boot. It also starts the script after sleep or resume.

## How the Feature Was Built

Workers used direct writes to control files in the /sys file system.

They used pkexec with special flags to handle rights safely in non interactive sessions.

A bash script holds all the logic for the modes.

A systemd oneshot service ensures the settings apply on every boot and wake up.

This method works well on Apple Silicon. Other power tools often lack a performance option.

## How to Use the Feature

The service is enabled and active.

The settings apply on their own at start.

To force the performance mode now, run this command:

pkexec --disable-internal-agent /usr/local/bin/set-cpu-performance.sh performance

Replace performance with balanced or power-saver for other modes.

## Verify the Settings

Use these commands to check the results.

Check the governors:

cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort | uniq -c

You should see many "performance" entries after the change.

Check boost:

cat /sys/devices/system/cpu/cpufreq/boost

The value should be 1 for enabled.

Check the service:

systemctl status cpu-performance.service --no-pager

It should show active (exited) and success.

Check current frequencies (may need elevation):

pkexec --disable-internal-agent cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq | sort | uniq -c

Higher values mean the CPU runs faster.

Note these facts:

The CPU will use more electrical power.

The CPU will generate more heat.

Watch temperatures on laptops.

## Current State Example

At the time of this document:

- Governors showed schedutil in one check.
- Boost was enabled (1).
- The service was active and had run successfully.
- NVMe scheduler showed none as an option.
- Hardware: M1 with Icestorm and Firestorm cores.

Run the apply command to set performance. Then recheck.

## Revert to Default Settings

To return to normal power saving:

Run this command:

pkexec --disable-internal-agent /usr/local/bin/set-cpu-performance.sh balanced

Or power-saver for more savings.

You can also disable the service:

pkexec --disable-internal-agent systemctl disable --now cpu-performance.service

Then set governors back manually if needed.

## Notes and Warnings

This feature targets users who want maximum performance from the M1 CPU.

It works by bypassing some default power management on Asahi Linux.

The M1 chip has efficiency cores (Icestorm) and performance cores (Firestorm).

The script tries to apply settings to all where the system permits writes.

High performance mode increases power draw and heat. Use with care.

Test the settings. Verify after reboots.

The script and service files contain the exact logic.

Read them for full details.

This documentation follows a simple technical style. It aims for clarity.

## Source of the Feature

The feature comes from performance tuning work on Omarchy (Asahi Linux).

It uses patterns from the linux-performance-tuning skill.

The concrete script and service were created and verified in a recent session.

## License and Use

Use this at your own risk.

Changes to CPU and power settings can affect stability, power use, and temperature.

No warranty is given.

For questions, inspect the installed files.

---

README created for the ASD-STE100 project. This is the initial documentation for the M1 CPU performance mode feature.