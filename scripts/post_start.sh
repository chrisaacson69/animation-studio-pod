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

# ── 1. Clone ComfyUI if not on network volume ───────────────
if [ ! -d "$WORKSPACE/ComfyUI" ]; then
    echo "[1/5] Cloning ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "$WORKSPACE/ComfyUI"
else
    echo "[1/5] ComfyUI — already present"
fi

# ── 2. Install custom nodes if missing ──────────────────────
echo "[2/5] Checking custom nodes..."
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
echo "[3/5] Ensuring output directories..."
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
echo "[4/5] Configuring PATH..."
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
echo "[5/5] Setting permissions..."
[ -f "$WORKSPACE/youtubeuploader" ] && chmod +x "$WORKSPACE/youtubeuploader"

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
