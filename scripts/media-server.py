"""
Studio Media Server
====================
Serves rendered videos, images, and assets with a clean browsable UI.
Run from anywhere — paths are absolute.

Usage:
    python3 /workspace/studio/tools/media-server.py [--port 8080]

Then open in browser:
    Local:  http://localhost:8080
    RunPod: https://{pod-id}-8080.proxy.runpod.net
"""

import http.server
import html
import os
import sys
import urllib.parse
from pathlib import Path

PORT = 8080
if "--port" in sys.argv:
    PORT = int(sys.argv[sys.argv.index("--port") + 1])

# Directories to serve — label: absolute path
MEDIA_ROOTS = {
    "Manim Renders": "/workspace/media/videos",
    "Manim Images": "/workspace/media/images",
    "Episodes": "/workspace/studio/episodes",
    "Character Assets": "/workspace/studio/assets/characters",
    "Backgrounds": "/workspace/studio/assets/backgrounds",
    "Frame Captures": "/workspace/frames",
}

# File extensions and their MIME types for inline viewing
VIEWABLE = {
    ".mp4": "video/mp4",
    ".webm": "video/webm",
    ".mov": "video/quicktime",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".wav": "audio/wav",
    ".mp3": "audio/mpeg",
}

STYLE = """
<style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, system-ui, sans-serif; background: #1a1a2e; color: #e0e0e0; padding: 2rem; }
    h1 { color: #f39c12; margin-bottom: 1.5rem; font-size: 1.8rem; }
    h2 { color: #4a90d9; margin: 1.5rem 0 0.8rem; font-size: 1.3rem; }
    a { color: #2ecc71; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .section { background: #16213e; border-radius: 8px; padding: 1rem 1.5rem; margin-bottom: 1rem; }
    .file-list { list-style: none; }
    .file-list li { padding: 0.3rem 0; }
    .file-list .size { color: #888; font-size: 0.85rem; margin-left: 0.5rem; }
    .file-list .dir { color: #4a90d9; }
    .empty { color: #666; font-style: italic; }
    .breadcrumb { color: #888; margin-bottom: 1rem; font-size: 0.9rem; }
    .breadcrumb a { color: #f39c12; }
    video, img.preview { max-width: 100%; max-height: 70vh; border-radius: 4px; margin: 1rem 0; background: #000; }
    audio { margin: 1rem 0; }
    .back { display: inline-block; margin-bottom: 1rem; color: #f39c12; }
</style>
"""


def human_size(size_bytes):
    for unit in ["B", "KB", "MB", "GB"]:
        if size_bytes < 1024:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024
    return f"{size_bytes:.1f} TB"


def render_index():
    sections = []
    for label, root in MEDIA_ROOTS.items():
        if not os.path.isdir(root):
            sections.append(f'<div class="section"><h2>{html.escape(label)}</h2><p class="empty">Not found: {html.escape(root)}</p></div>')
            continue

        files = []
        for entry in sorted(os.scandir(root), key=lambda e: (not e.is_dir(), e.name.lower())):
            name = entry.name
            if name.startswith("."):
                continue
            encoded = urllib.parse.quote(label) + "/" + urllib.parse.quote(name)
            if entry.is_dir():
                files.append(f'<li><a class="dir" href="/browse/{encoded}/">{html.escape(name)}/</a></li>')
            else:
                size = human_size(entry.stat().st_size)
                files.append(f'<li><a href="/browse/{encoded}">{html.escape(name)}</a><span class="size">{size}</span></li>')

        body = f'<ul class="file-list">{"".join(files)}</ul>' if files else '<p class="empty">Empty</p>'
        sections.append(f'<div class="section"><h2>{html.escape(label)}</h2>{body}</div>')

    return f"<html><head><title>Studio</title>{STYLE}</head><body><h1>Studio Media Server</h1>{''.join(sections)}</body></html>"


def render_directory(label, rel_path, abs_path):
    crumbs = f'<div class="breadcrumb"><a href="/">Home</a> / <a href="/browse/{urllib.parse.quote(label)}/">{html.escape(label)}</a>'
    parts = Path(rel_path).parts
    for i, part in enumerate(parts):
        partial = "/".join(parts[:i+1])
        crumbs += f' / <a href="/browse/{urllib.parse.quote(label)}/{urllib.parse.quote(partial)}/">{html.escape(part)}</a>'
    crumbs += '</div>'

    files = []
    for entry in sorted(os.scandir(abs_path), key=lambda e: (not e.is_dir(), e.name.lower())):
        name = entry.name
        if name.startswith("."):
            continue
        sub = f"{rel_path}/{name}" if rel_path else name
        encoded = urllib.parse.quote(label) + "/" + urllib.parse.quote(sub, safe="/")
        if entry.is_dir():
            files.append(f'<li><a class="dir" href="/browse/{encoded}/">{html.escape(name)}/</a></li>')
        else:
            size = human_size(entry.stat().st_size)
            files.append(f'<li><a href="/browse/{encoded}">{html.escape(name)}</a><span class="size">{size}</span></li>')

    body = f'<ul class="file-list">{"".join(files)}</ul>' if files else '<p class="empty">Empty</p>'
    title = f"{label} / {rel_path}" if rel_path else label
    return f"<html><head><title>{html.escape(title)}</title>{STYLE}</head><body>{crumbs}<h1>{html.escape(title)}</h1><div class='section'>{body}</div></body></html>"


def render_file_view(label, rel_path, abs_path):
    ext = Path(abs_path).suffix.lower()
    mime = VIEWABLE.get(ext)
    name = Path(abs_path).name
    file_url = f"/raw/{urllib.parse.quote(label)}/{urllib.parse.quote(rel_path, safe='/')}"

    parent_rel = str(Path(rel_path).parent)
    if parent_rel == ".":
        back_url = f"/browse/{urllib.parse.quote(label)}/"
    else:
        back_url = f"/browse/{urllib.parse.quote(label)}/{urllib.parse.quote(parent_rel, safe='/')}/"

    crumbs = f'<a class="back" href="{back_url}">&larr; Back</a>'

    if mime and mime.startswith("video/"):
        player = f'<video controls autoplay><source src="{file_url}" type="{mime}">Download: <a href="{file_url}">{html.escape(name)}</a></video>'
    elif mime and mime.startswith("image/"):
        player = f'<img class="preview" src="{file_url}" alt="{html.escape(name)}">'
    elif mime and mime.startswith("audio/"):
        player = f'<audio controls><source src="{file_url}" type="{mime}"></audio>'
    else:
        player = f'<p><a href="{file_url}">Download {html.escape(name)}</a></p>'

    size = human_size(os.path.getsize(abs_path))
    return f"<html><head><title>{html.escape(name)}</title>{STYLE}</head><body>{crumbs}<h1>{html.escape(name)}</h1><p class='empty'>{size}</p>{player}</body></html>"


def resolve_browse_path(path_str):
    """Parse /browse/Label/sub/path into (label, rel_path, abs_path)."""
    parts = path_str.split("/", 1)
    label = urllib.parse.unquote(parts[0])
    rel = urllib.parse.unquote(parts[1]).strip("/") if len(parts) > 1 else ""

    if label not in MEDIA_ROOTS:
        return None, None, None

    root = MEDIA_ROOTS[label]
    abs_path = os.path.normpath(os.path.join(root, rel)) if rel else root

    # Security: ensure we don't escape the root
    if not abs_path.startswith(os.path.normpath(root)):
        return None, None, None

    return label, rel, abs_path


class StudioHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = urllib.parse.unquote(parsed.path).rstrip("/")

        # Index
        if path in ("", "/"):
            self.send_html(render_index())
            return

        # Browse — directory listing or file view page
        if path.startswith("/browse/"):
            remainder = path[len("/browse/"):]
            label, rel, abs_path = resolve_browse_path(remainder)
            if not label or not os.path.exists(abs_path):
                self.send_error(404)
                return
            if os.path.isdir(abs_path):
                self.send_html(render_directory(label, rel, abs_path))
            else:
                self.send_html(render_file_view(label, rel, abs_path))
            return

        # Raw file serving (for video/image src tags)
        if path.startswith("/raw/"):
            remainder = path[len("/raw/"):]
            label, rel, abs_path = resolve_browse_path(remainder)
            if not label or not os.path.isfile(abs_path):
                self.send_error(404)
                return
            self.serve_file(abs_path)
            return

        self.send_error(404)

    def send_html(self, content):
        data = content.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def serve_file(self, abs_path):
        ext = Path(abs_path).suffix.lower()
        mime = VIEWABLE.get(ext, "application/octet-stream")
        size = os.path.getsize(abs_path)

        # Support range requests for video seeking
        range_header = self.headers.get("Range")
        if range_header and range_header.startswith("bytes="):
            ranges = range_header[6:].split("-")
            start = int(ranges[0]) if ranges[0] else 0
            end = int(ranges[1]) if ranges[1] else size - 1
            length = end - start + 1

            self.send_response(206)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
            self.send_header("Content-Length", str(length))
            self.send_header("Accept-Ranges", "bytes")
            self.end_headers()

            with open(abs_path, "rb") as f:
                f.seek(start)
                self.wfile.write(f.read(length))
        else:
            self.send_response(200)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(size))
            self.send_header("Accept-Ranges", "bytes")
            self.end_headers()

            with open(abs_path, "rb") as f:
                while chunk := f.read(1024 * 1024):
                    self.wfile.write(chunk)

    def log_message(self, format, *args):
        # Quieter logging — just method and path
        print(f"  {args[0]}")


if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", PORT), StudioHandler)
    print(f"Studio Media Server running on port {PORT}")
    print(f"  Local:  http://localhost:{PORT}")
    print(f"  RunPod: https://{{pod-id}}-{PORT}.proxy.runpod.net")
    print(f"\nServing:")
    for label, root in MEDIA_ROOTS.items():
        exists = "OK" if os.path.isdir(root) else "MISSING"
        print(f"  [{exists}] {label}: {root}")
    print()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()
