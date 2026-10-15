# How to Install

This guide shows how to install the M1 CPU Performance Mode feature on Omarchy (Asahi Linux).

The feature sets the CPU to performance, balanced, or power-saver mode. It uses direct writes to system files. A systemd service keeps the settings across boots and sleep.

## Prerequisites

- You run Omarchy or Asahi Linux on an Apple M1 (or similar Apple Silicon).
- You have sudo or pkexec access.
- You can clone a git repository.
- Optional: sysbench and sensors for verification and monitoring.

## Step 1: Get the files

Clone the repository:

```bash
git clone git@github.com:jaredwerba/omarchy-m1-performance.git
cd omarchy-m1-performance
```

Or download the files from the GitHub page if you prefer.

## Step 2: Install the script and service

Copy the files to the system locations:

```bash
sudo cp set-cpu-performance.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/set-cpu-performance.sh

sudo cp cpu-performance.service /etc/systemd/system/
sudo cp verify.sh /usr/local/bin/   # optional but useful
sudo chmod +x /usr/local/bin/verify.sh
```

## Step 3: Enable the service

The service applies performance mode at boot and after resume from sleep.

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now cpu-performance.service
```

Check that it started:

```bash
systemctl status cpu-performance.service --no-pager
```

You should see "active (exited)" and a success message.

## Step 4: Apply performance mode now

If you want to set it immediately without waiting for reboot:

```bash
pkexec --disable-internal-agent /usr/local/bin/set-cpu-performance.sh performance
```

For verbose output (shows before and after):

```bash
pkexec --disable-internal-agent /usr/local/bin/set-cpu-performance.sh performance -v
```

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

Expect "performance" governors and boost value 1.

## Switch modes later

```bash
pkexec --disable-internal-agent /usr/local/bin/set-cpu-performance.sh balanced
pkexec --disable-internal-agent /usr/local/bin/set-cpu-performance.sh power-saver
pkexec --disable-internal-agent /usr/local/bin/set-cpu-performance.sh performance
```

Add `-v` for details.

## Uninstall

To remove the feature:

```bash
sudo systemctl disable --now cpu-performance.service
sudo rm /etc/systemd/system/cpu-performance.service
sudo rm /usr/local/bin/set-cpu-performance.sh
sudo rm /usr/local/bin/verify.sh   # if installed
sudo systemctl daemon-reload
```

Then set governors back if needed:

```bash
pkexec --disable-internal-agent bash -c 'echo schedutil > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
```

## Troubleshooting

**Service fails to start**
- Check the path in the service file matches where you copied the script.
- Run the script manually with pkexec to see errors.
- Look at logs: `journalctl -u cpu-performance.service`

**Settings do not stick after reboot**
- Confirm the service is enabled: `systemctl is-enabled cpu-performance.service`
- Re-run the enable command.

**Permission denied on sysfs writes**
- Use pkexec or sudo. Some files need elevated rights.

**Frequencies do not rise**
- Run `verify.sh` and check the governor output.
- Re-apply the performance mode.
- Note that hardware thermal limits can still throttle the CPU.

**Want to see what changed**
- Use the `-v` flag on the script.
- Compare before and after with `verify.sh`.

## Notes

- Performance mode uses more power and generates more heat. Monitor temperatures.
- The script detects Apple M1 hardware (T8103).
- Test on your own machine. Results vary by workload and cooling.
- This is not a full replacement for macOS power management.

For more details, see the README.md in this repository.
