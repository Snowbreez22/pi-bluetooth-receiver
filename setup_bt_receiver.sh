#!/usr/bin/env bash
set -e

echo "=== Bluetooth Audio Receiver Setup (BlueALSA) for Debian 13 (trixie) ==="

# --- Must be run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root (use: sudo bash <this_script>)"
  exit 1
fi

USER_NAME="${SUDO_USER:-pi}"

echo "[1/10] Updating package lists..."
apt update

echo "[2/10] Installing required packages..."
apt install -y \
  bluez \
  bluez-tools \
  bluez-alsa-utils \
  libasound2-plugin-bluez \
  alsa-utils

echo "[3/10] Enabling Bluetooth service..."
systemctl enable --now bluetooth

echo "[4/10] Configuring Bluetooth for always discoverable/pairable + loudspeaker class..."
CONF="/etc/bluetooth/main.conf"

# Backup main.conf
cp -a "$CONF" "${CONF}.bak.$(date +%Y%m%d%H%M%S)" || true

# Ensure [General] section exists
grep -q "^\[General\]" "$CONF" || echo -e "\n[General]" >> "$CONF"

# Helper: set or add key under [General]
set_conf_key() {
  local key="$1"
  local value="$2"
  if grep -Eq "^[#[:space:]]*${key}[[:space:]]*=" "$CONF"; then
    sed -i -E "s|^[#[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|g" "$CONF"
  else
    awk -v k="$key" -v v="$value" '
      BEGIN{added=0}
      /^\[General\]/{print; if(!added){print k " = " v; added=1; next}}
      {print}
      END{if(!added){print "\n[General]\n" k " = " v}}
    ' "$CONF" > "${CONF}.tmp" && mv "${CONF}.tmp" "$CONF"
  fi
}

# Always visible & pairable, auto-enable adapter
set_conf_key "DiscoverableTimeout" "0"
set_conf_key "PairableTimeout" "0"
set_conf_key "AutoEnable" "true"

# Bluetooth speaker name (uses hostname by default, but this sets explicit name too)
set_conf_key "Name" "Kenwood Speaker"

# Loudspeaker class (helps iOS/Spotify see as speaker, not car)
set_conf_key "Class" "0x240414"

echo "[5/10] Creating systemd service: make Bluetooth discoverable/pairable at boot..."
cat > /etc/systemd/system/bt-discoverable.service <<'EOF'
[Unit]
Description=Make Bluetooth discoverable & pairable at boot
After=bluetooth.service
Requires=bluetooth.service

[Service]
Type=oneshot
ExecStart=/usr/bin/bluetoothctl power on
ExecStart=/usr/bin/bluetoothctl pairable on
ExecStart=/usr/bin/bluetoothctl discoverable on
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now bt-discoverable.service

echo "[6/10] Creating systemd service: auto-accept pairing requests..."
cat > /etc/systemd/system/bt-agent.service <<'EOF'
[Unit]
Description=Bluetooth Agent to auto-accept pairing
After=bluetooth.service
Requires=bluetooth.service

[Service]
ExecStart=/usr/bin/bt-agent -c NoInputNoOutput
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now bt-agent.service

echo "[7/10] Creating systemd service: AUTO-TRUST newly paired devices..."
cat > /usr/local/bin/bt-autotrust.sh <<'EOF'
#!/usr/bin/env bash
set -e

# Make sure controller is on
bluetoothctl power on >/dev/null 2>&1 || true
bluetoothctl agent on >/dev/null 2>&1 || true
bluetoothctl default-agent >/dev/null 2>&1 || true

# Watch bluetoothctl events and trust/connect devices that pair
bluetoothctl monitor | while read -r line; do
  # Example lines may contain: "Device XX:XX:XX:XX:XX:XX Paired: yes"
  if echo "$line" | grep -q "Paired: yes"; then
    mac="$(echo "$line" | grep -oE '([0-9A-F]{2}:){5}[0-9A-F]{2}' | head -n1)"
    if [ -n "$mac" ]; then
      echo "[bt-autotrust] Trusting $mac"
      bluetoothctl trust "$mac" >/dev/null 2>&1 || true
      # Optional: try to connect immediately for convenience
      bluetoothctl connect "$mac" >/dev/null 2>&1 || true
    fi
  fi
done
EOF

chmod +x /usr/local/bin/bt-autotrust.sh

cat > /etc/systemd/system/bt-autotrust.service <<'EOF'
[Unit]
Description=Auto-trust Bluetooth devices after pairing
After=bluetooth.service
Requires=bluetooth.service

[Service]
Type=simple
ExecStart=/usr/local/bin/bt-autotrust.sh
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now bt-autotrust.service

echo "[8/10] Creating systemd service: play Bluetooth A2DP audio to default ALSA output..."
cat > /etc/systemd/system/bluealsa-aplay.service <<'EOF'
[Unit]
Description=Play Bluetooth audio through ALSA via BlueALSA
After=bluetooth.service sound.target
Requires=bluetooth.service

[Service]
Type=simple
ExecStart=/usr/bin/bluealsa-aplay --profile-a2dp --pcm=default
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now bluealsa-aplay.service

echo "[9/10] Disabling Handsfree/Headset profiles (A2DP music-only, avoids 'car kit' behavior)..."
# Detect bluetoothd path on this system
BTD_PATH="$(command -v bluetoothd || true)"
if [ -z "$BTD_PATH" ]; then
  if [ -x /usr/libexec/bluetooth/bluetoothd ]; then
    BTD_PATH="/usr/libexec/bluetooth/bluetoothd"
  elif [ -x /usr/lib/bluetooth/bluetoothd ]; then
    BTD_PATH="/usr/lib/bluetooth/bluetoothd"
  elif [ -x /usr/sbin/bluetoothd ]; then
    BTD_PATH="/usr/sbin/bluetoothd"
  else
    echo "Could not find bluetoothd binary; skipping HFP/HSP disable."
    BTD_PATH=""
  fi
fi

if [ -n "$BTD_PATH" ]; then
  mkdir -p /etc/systemd/system/bluetooth.service.d
  cat > /etc/systemd/system/bluetooth.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=${BTD_PATH} --noplugin=headset,handsfree
EOF
  systemctl daemon-reload
fi

echo "[10/10] Restarting Bluetooth + services..."
systemctl restart bluetooth
systemctl restart bt-discoverable.service bt-agent.service bt-autotrust.service bluealsa-aplay.service || true

echo ""
echo "=== DONE ==="
echo "Your Pi should now appear as: 'Kenwood Speaker' in Bluetooth."
echo "Anyone can pair; newly paired devices will be auto-trusted."
echo "Audio plays out via ALSA default (3.5mm or USB DAC)."
echo ""
echo "TIP (Pi analog output): sudo amixer cset numid=3 1"
echo "TIP (volume):          amixer set PCM 90%"
echo ""
read -p "Reboot now? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  reboot
else
  echo "You can reboot later with: sudo reboot"
fi
