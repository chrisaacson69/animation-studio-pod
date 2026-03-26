# ─────────────────────────────────────────────────────────────
#  Animation Studio Pod — Custom RunPod Image
#  Base: RunPod PyTorch (includes nginx, SSH, JupyterLab)
#  Adds: ComfyUI deps, custom nodes, manim, Claude Code, etc.
# ─────────────────────────────────────────────────────────────
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# ── System packages ──────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libcairo2-dev \
    libpango1.0-dev \
    pkg-config \
    texlive-base \
    texlive-latex-extra \
    texlive-fonts-recommended \
    texlive-latex-recommended \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# ── ComfyUI Python dependencies ─────────────────────────────
# Pinned from ComfyUI v0.18.1 requirements.txt
# torch/torchvision/torchaudio already in base image
RUN pip install --no-cache-dir \
    comfyui-frontend-package==1.42.8 \
    comfyui-workflow-templates==0.9.26 \
    comfyui-embedded-docs==0.4.3 \
    torchsde \
    "numpy>=1.25.0" \
    einops \
    "transformers>=4.50.3" \
    "tokenizers>=0.13.3" \
    sentencepiece \
    "safetensors>=0.4.2" \
    "aiohttp>=3.11.8" \
    "yarl>=1.18.0" \
    pyyaml \
    Pillow \
    scipy \
    tqdm \
    psutil \
    alembic \
    SQLAlchemy \
    filelock \
    "av>=14.2.0" \
    "comfy-kitchen>=0.2.8" \
    "comfy-aimdo>=0.2.12" \
    requests \
    "simpleeval>=1.0.0" \
    blake3 \
    "kornia>=0.7.1" \
    spandrel \
    "pydantic~=2.0" \
    "pydantic-settings~=2.0" \
    soundfile

# ── ComfyUI custom node dependencies ────────────────────────
# Impact-Pack
RUN pip install --no-cache-dir \
    segment-anything \
    ultralytics \
    opencv-python-headless

# AnimateDiff-Evolved + VideoHelperSuite
RUN pip install --no-cache-dir \
    imageio-ffmpeg

# ── Animation studio packages ───────────────────────────────
RUN pip install --no-cache-dir \
    manim \
    moviepy \
    pytest \
    pytest-aiohttp \
    pytest-asyncio \
    websocket-client

# ── Fish Speech TTS (character voiceovers) ───────────────────
RUN pip install --no-cache-dir fish-speech

# ── Node.js + Claude Code ───────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g @anthropic-ai/claude-code \
    && rm -rf /var/lib/apt/lists/*

# ── GitHub CLI ──────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# ── Rhubarb Lip Sync ────────────────────────────────────────
RUN cd /tmp \
    && wget -q https://github.com/DanielSWolf/rhubarb-lip-sync/releases/download/v1.13.0/Rhubarb-Lip-Sync-1.13.0-Linux.zip \
    && unzip -q Rhubarb-Lip-Sync-1.13.0-Linux.zip -d /opt/rhubarb \
    && chmod +x /opt/rhubarb/Rhubarb-Lip-Sync-1.13.0-Linux/rhubarb \
    && ln -s /opt/rhubarb/Rhubarb-Lip-Sync-1.13.0-Linux/rhubarb /usr/local/bin/rhubarb \
    && rm Rhubarb-Lip-Sync-1.13.0-Linux.zip

# ── Media server ─────────────────────────────────────────────
COPY scripts/media-server.py /opt/studio/media-server.py

# ── post_start.sh (runs on every pod boot) ──────────────────
COPY scripts/post_start.sh /post_start.sh
RUN chmod +x /post_start.sh
