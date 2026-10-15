#!/bin/bash
# One-time install. Asks for your password once.
# After this, changing power profiles does not ask again.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  TARGET_USER="$SUDO_USER"
elif [[ -n "${PKEXEC_UID:-}" ]]; then
  TARGET_USER="$(id -nu "$PKEXEC_UID")"
else
  TARGET_USER="${1:-jkw}"
fi
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
  echo "Run as your normal user: ./install.sh" >&2
  echo "Or: sudo ./install.sh your-username" >&2
  exit 1
fi

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_DST="/usr/local/bin/set-cpu-performance.sh"
VERIFY_DST="/usr/local/bin/verify.sh"
LINK_DST="/usr/local/bin/cpu-mode"
SERVICE_DST="/etc/systemd/system/cpu-performance.service"
SUDOERS_DST="/etc/sudoers.d/cpu-performance"
SUDOERS_TMP="$(mktemp)"

install -m 755 -o root -g root "$SRC_DIR/set-cpu-performance.sh" "$SCRIPT_DST"
install -m 755 -o root -g root "$SRC_DIR/verify.sh" "$VERIFY_DST"
ln -sfn "$SCRIPT_DST" "$LINK_DST"
install -m 644 -o root -g root "$SRC_DIR/cpu-performance.service" "$SERVICE_DST"

cat > "$SUDOERS_TMP" << EOF
# Allow ${TARGET_USER} to switch CPU power profiles without a password.
# Only this root-owned script is allowed. No other commands.
${TARGET_USER} ALL=(root) NOPASSWD: ${SCRIPT_DST}
EOF
chmod 440 "$SUDOERS_TMP"
if ! visudo -cf "$SUDOERS_TMP"; then
  echo "Refusing to install a bad sudoers rule." >&2
  rm -f "$SUDOERS_TMP"
  exit 1
fi
install -m 440 -o root -g root "$SUDOERS_TMP" "$SUDOERS_DST"
rm -f "$SUDOERS_TMP"

systemctl daemon-reload
systemctl enable cpu-performance.service >/dev/null

echo "Installed for ${TARGET_USER}."
echo "Passwordless command: cpu-mode performance"
echo "Also: cpu-mode balanced"
echo "Also: cpu-mode power-saver"
echo "The script is root-owned. Do not replace ${SCRIPT_DST} with a user-writable copy."
