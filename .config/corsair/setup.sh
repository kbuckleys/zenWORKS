#!/bin/sh
# Deploy corsair-headset-fix — one command to set up everything
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

# Symlink to ~/.local/bin (for manual invocation)
mkdir -p "$HOME/.local/bin"
ln -sf "$DIR/corsair-headset-fix" "$HOME/.local/bin/corsair-headset-fix"
echo "  → ~/.local/bin/corsair-headset-fix"

# Symlink to systemd user units
mkdir -p "$HOME/.config/systemd/user"
ln -sf "$DIR/corsair-headset-fix.service" "$HOME/.config/systemd/user/corsair-headset-fix.service"
echo "  → ~/.config/systemd/user/corsair-headset-fix.service"

# Enable and start the service
systemctl --user daemon-reload
systemctl --user enable --now corsair-headset-fix.service
echo "  → service enabled & started"

echo ""
echo "Done. corsair-headset-fix is now active."
