#Rasberry Pi Bluetooth audio reciver 

Raspberry Pi Bluetooth Audio Receiver (BlueALSA) for Debian 13 (Trixie).
Turns a Pi into an always-discoverable Bluetooth “speaker” with auto-pair, auto-trust, and automatic A2DP playback to an amplifier via ALSA (3.5mm or USB DAC).
*************************************************************************************************************************************************************************************************************************************************************************
Raspberry Pi Bluetooth Audio Receiver (BlueALSA) — Debian 13 (Trixie)

This project provides a single install script that converts a Raspberry Pi into a Bluetooth audio receiver (“Bluetooth speaker mode”) so you can stream music from phones/laptops to an old amplifier or powered speakers.

It is optimized for Debian 13 (Trixie) on Raspberry Pi, and uses the BlueALSA backend for maximum reliability and minimal complexity (no PipeWire/PulseAudio required).

✅ What the script does

When executed, the script automatically:

Installs the required Bluetooth + audio packages:

bluez, bluez-tools

bluez-alsa-utils

libasound2-plugin-bluez

alsa-utils

Enables and starts the Bluetooth service on boot

Configures the Pi to be:

Always discoverable (visible indefinitely)

Always pairable (can accept pairing at any time)

Advertised as a Bluetooth loudspeaker (helps apps label it correctly)

Creates and enables systemd services to:

Force Bluetooth to be discoverable/pairable at boot

Auto-accept pairing requests (no PIN/keyboard needed)

Auto-trust devices after pairing (so devices can reconnect easily)

Automatically play Bluetooth A2DP audio through ALSA using bluealsa-aplay

Disables Handsfree/Headset profiles (HFP/HSP), forcing music-only A2DP mode

Prevents iOS/Spotify from treating the Pi like a “car kit”

✅ Supported Audio Output

The receiver outputs audio via the Pi’s default ALSA output, which can be:

3.5mm analog headphone jack

USB DAC

Any other ALSA-supported sound device

Tip (analog output):

sudo amixer cset numid=3 1
************************************************************************************************************************************************************************************************************************************************************************
**🚀 Quick Install / Run**

*Recommended (download then run)*

curl -fsSL https://raw.githubusercontent.com/Snowbreez22/pi-bluetooth-receiver/main/setup_bt_receiver.sh -o setup_bt_receiver.sh
chmod +x setup_bt_receiver.sh
sudo ./setup_bt_receiver.sh


*One-liner: Also works*

curl -fsSL https://raw.githubusercontent.com/Snowbreez22/pi-bluetooth-receiver/main/setup_bt_receiver.sh | sudo bash

************************************************************************************************************************************************************************************************************************************************************************
After installation and reboot:

Open Bluetooth on your phone/laptop

Pair with the Pi device (e.g., “Kenwood Speaker”)

Play music — audio will output to the amplifier automatically

🔐 Security Note (Important)

This script intentionally configures the Pi like a public Bluetooth speaker:

Always discoverable + pairable

Auto-accept pairing

Auto-trust paired devices

This is ideal for home use, but it also means anyone nearby could pair and play audio.

If you want a locked-down version (only allow selected devices), you can remove auto-accept/auto-trust or restrict pairing to trusted MAC addresses.

✅ Tested On

Debian GNU/Linux 13 (Trixie) on Raspberry Pi (Pi 3 and later recommended)

✅ 3) “What happens after install?” quick summary (optional)

After the script runs, your Pi becomes a Bluetooth receiver:

It appears in Bluetooth lists like a speaker

Devices can pair without needing the Pi’s keyboard/terminal

New devices are trusted automatically

A2DP audio is piped to your amp automatically via ALSA
