# How to Install

This guide shows how to install the M1 CPU Performance Mode feature on Omarchy (Asahi Linux).

The feature sets the CPU to performance, balanced, or power-saver mode. It writes kernel controls. A systemd service applies the performance mode at boot. The service does not apply the mode after sleep.

## Prerequisites

- You run Omarchy or Asahi Linux on an Apple M1 (or similar Apple Silicon).
- You have sudo access for the one-time install.
- You can clone a git repository.
- Optional: sysbench and sensors for verification and monitoring.

## Step 1: Get the files

Clone the repository:

```bash
git clone git@github.com:jaredwerba/omarchy-m1-performance.git
cd omarchy-m1-performance
```

Or download the files from the GitHub page if you prefer.

## Step 2: Install once

This asks for your password one time. It copies the files, enables the service, and adds a sudo rule that lets you switch profiles later with no password.

```bash
chmod +x install.sh
./install.sh
```

The rule only allows `/usr/local/bin/set-cpu-performance.sh`. It does not allow other root commands. The installed script is owned by root so it cannot be swapped for something else.

## Step 3: Enable the service

`install.sh` already enables the service. If you need to do it by hand:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now cpu-performance.service
```

Check that it started:

```bash
systemctl status cpu-performance.service --no-pager
```

You should see "active (exited)" and a success message.

## Step 4: Change profiles with no password

After install, these do not ask for a password:

```bash
cpu-mode performance
cpu-mode balanced
cpu-mode power-saver
cpu-mode performance -v
```

`set-cpu-performance.sh` is the same command.

## Step 5: Verify the installation

Run the verification helper:

```bash
verify.sh performance
```

Or if you copied it to /usr/local/bin:

```bash
/usr/local/bin/verify.sh performance
```

It checks:
- Hardware (M1 detection)
- CPU governors
- Boost setting
- ASPM policy
- NVMe scheduler
- Current frequencies
- A short benchmark
- Temperatures
- Service status

You can also check manually:

```bash
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort | uniq -c
cat /sys/devices/system/cpu/cpufreq/boost
```

Expect eight "performance" governors and boost value 1. Read `cpuinfo_cur_freq` for the hardware clock. On this M1, the performance cores stay at 2988 MHz under load. The 3204 MHz value is a boost label.

## Switch modes later

No password:

```bash
cpu-mode balanced
cpu-mode power-saver
cpu-mode performance
```

## Uninstall

Switch back first, while the passwordless command still exists:

```bash
cpu-mode balanced
```

Then remove the files:

```bash
sudo systemctl disable --now cpu-performance.service
sudo rm /etc/systemd/system/cpu-performance.service
sudo rm /usr/local/bin/set-cpu-performance.sh
sudo rm /usr/local/bin/cpu-mode
sudo rm /usr/local/bin/verify.sh
sudo rm /etc/sudoers.d/cpu-performance
sudo systemctl daemon-reload
```

## Troubleshooting

**Service fails to start**
- Check the path in the service file matches where you copied the script.
- Run: cpu-mode performance
- Look at logs: `journalctl -u cpu-performance.service`

**Settings do not stick after reboot**
- Confirm the service is enabled: `systemctl is-enabled cpu-performance.service`
- Re-run the enable command.

**Still asks for a password**
- Run `./install.sh` once.
- Confirm the rule: `sudo -n -l /usr/local/bin/set-cpu-performance.sh`
- Use `cpu-mode`, not pkexec.

**The clock stays at 2988 MHz**
- This is the hardware clock of the performance cores.
- Read `cpuinfo_cur_freq`. Do not use the 3204 MHz boost label as the clock.
- Performance mode does not raise a full-load CPU benchmark.
- A long job on this Air can still slow down from heat. The machine has no fan.

**Want to see what changed**
- Use the `-v` flag on the script.
- Compare before and after with `verify.sh`.

## Notes

- Performance mode uses more power and generates more heat. Monitor temperatures.
- The script detects Apple M1 hardware (T8103).
- Test on your own machine. Results vary by workload and cooling.
- This is not a full replacement for macOS power management.

For more details, see the README.md in this repository.
