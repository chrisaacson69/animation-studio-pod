#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  post_start.sh — Lightweight runtime setup (runs every boot)
#  Heavy installs are baked into the Docker image.
#  This script only handles workspace-specific setup.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

WORKSPACE="/workspace"

echo "══════════════════════════════════════════════"
echo "  Animation Studio — Post-Start Setup"
echo "══════════════════════════════════════════════"

# ── 0. Restore persistent auth from network volume ───────────
# Auth directories are stored on /workspace so they survive pod
# restarts. First login: run `claude login` and `gh auth login`
# manually — they'll be saved automatically for next time.
echo "[0/6] Restoring auth credentials..."

AUTH_DIRS=(
    ".claude"       # Claude Code auth
    ".config/gh"    # GitHub CLI auth
    ".ssh"          # SSH keys
)

for dir in "${AUTH_DIRS[@]}"; do
    src="$WORKSPACE/.auth/$dir"
    dest="$HOME/$dir"
    if [ -d "$src" ]; then
        mkdir -p "$(dirname "$dest")"
        # Remove existing (ephemeral) dir and symlink to persistent copy
        rm -rf "$dest"
        ln -sf "$src" "$dest"
        echo "  $dir — restored from network volume"
    else
        echo "  $dir — not yet saved (run setup once, it will persist)"
    fi
done

# Ensure SSH key permissions are correct
[ -d "$HOME/.ssh" ] && chmod 700 "$HOME/.ssh" && chmod 600 "$HOME/.ssh/"* 2>/dev/null || true

# ── 1. Clone ComfyUI if not on network volume ───────────────
if [ ! -d "$WORKSPACE/ComfyUI" ]; then
    echo "[1/6] Cloning ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "$WORKSPACE/ComfyUI"
else
    echo "[1/6] ComfyUI — already present"
fi

# ── 2. Install custom nodes if missing ──────────────────────
echo "[2/6] Checking custom nodes..."
CUSTOM_NODES_DIR="$WORKSPACE/ComfyUI/custom_nodes"
mkdir -p "$CUSTOM_NODES_DIR"

declare -A NODES=(
    ["ComfyUI-Manager"]="https://github.com/ltdrdata/ComfyUI-Manager.git"
    ["ComfyUI-Impact-Pack"]="https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
    ["ComfyUI-AnimateDiff-Evolved"]="https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved.git"
    ["ComfyUI-VideoHelperSuite"]="https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
)

for node in "${!NODES[@]}"; do
    if [ ! -d "$CUSTOM_NODES_DIR/$node" ]; then
        echo "  Cloning $node..."
        git clone --quiet "${NODES[$node]}" "$CUSTOM_NODES_DIR/$node"
    else
        echo "  $node — present"
    fi
done

# ── 3. Ensure output directories ────────────────────────────
echo "[3/6] Ensuring output directories..."
mkdir -p "$WORKSPACE/media/videos" \
         "$WORKSPACE/media/images" \
         "$WORKSPACE/media/texts" \
         "$WORKSPACE/frames" \
         "$WORKSPACE/studio/episodes" \
         "$WORKSPACE/studio/assets/backgrounds" \
         "$WORKSPACE/studio/assets/characters" \
         "$WORKSPACE/studio/assets/fonts" \
         "$WORKSPACE/studio/assets/music"

# ── 4. Set up PATH persistently ─────────────────────────────
echo "[4/6] Configuring PATH..."
PATHS_TO_ADD=(
    "/opt/rhubarb/Rhubarb-Lip-Sync-1.13.0-Linux"
    "$WORKSPACE"
)

for P in "${PATHS_TO_ADD[@]}"; do
    if ! grep -qF "$P" "$HOME/.bashrc" 2>/dev/null; then
        echo "export PATH=\"$P:\$PATH\"" >> "$HOME/.bashrc"
        echo "  Added to PATH: $P"
    fi
done

# ── 5. Make workspace binaries executable ────────────────────
echo "[5/6] Setting permissions..."
[ -f "$WORKSPACE/youtubeuploader" ] && chmod +x "$WORKSPACE/youtubeuploader"

# ── 6. Install save-auth helper ──────────────────────────────
echo "[6/6] Installing save-auth helper..."
cat > /usr/local/bin/save-auth <<'SCRIPT'
#!/usr/bin/env bash
# Copies current auth state to the network volume so it persists.
# Run this ONCE after logging into claude and gh on a new pod.
set -euo pipefail
WORKSPACE="/workspace"
mkdir -p "$WORKSPACE/.auth"

for dir in .claude .config/gh .ssh; do
    src="$HOME/$dir"
    dest="$WORKSPACE/.auth/$dir"
    if [ -d "$src" ] && [ ! -L "$src" ]; then
        mkdir -p "$(dirname "$dest")"
        cp -a "$src" "$dest"
        echo "Saved $dir → $dest"
    elif [ -L "$src" ]; then
        echo "$dir — already a symlink (already persisted)"
    else
        echo "$dir — not found, skipping"
    fi
done
echo "Done! Auth will be restored automatically on next boot."
SCRIPT
chmod +x /usr/local/bin/save-auth

echo ""
echo "══════════════════════════════════════════════"
echo "  Post-start complete!"
echo "══════════════════════════════════════════════"
echo ""
echo "Ready to use:"
echo "  python3 $WORKSPACE/ComfyUI/main.py --listen  # Start ComfyUI"
echo "  claude                                         # Claude Code"
echo "  rhubarb --version                              # Lip sync"
echo ""
echo "First-time setup (only once per pod):"
echo "  claude login          # Auth with your Claude subscription"
echo "  gh auth login         # Auth with GitHub"
echo "  save-auth             # Persist credentials to network volume"
echo ""
