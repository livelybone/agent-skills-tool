---
name: tinify
description: "Compress images using the Tinify (TinyPNG/TinyJPG) API. Use when the user wants to compress, optimize, or shrink images. Supported formats: AVIF, WebP, JPEG, PNG. Triggers: compress image, tinify, optimize image, shrink image, reduce image size, or when working with image files (.avif, .webp, .jpg, .jpeg, .png) and the user mentions size reduction."
---

# Tinify Image Compression

Compress images via the [Tinify API](https://api.tinify.com) (TinyPNG/TinyJPG). Supports AVIF, WebP, JPEG, PNG.

## Prerequisites

- API key: script resolves `TINIFY_API_KEY` in this order:
  1. shell environment variable `TINIFY_API_KEY`
  2. project `.env` at git root
  3. `~/.config/tinify/token`
  4. `--api-key` as compatibility fallback only
- Python 3.10+ (stdlib only, no extra packages needed)

## API Key Resolution (for Claude)

Before running any script, resolve the API key in this order — **never ask the user to paste it in chat**:

1. Check if `TINIFY_API_KEY` is already set in the shell environment.
2. Look for `TINIFY_API_KEY` in the project `.env` at git root.
3. If still not found, read `~/.config/tinify/token` (recommended shared setup).
4. Only if needed for compatibility, allow `--api-key`; do not recommend it.
5. If still not found, tell the user to configure one of:
   - `export TINIFY_API_KEY=<your_key>`
   - project `.env`: `TINIFY_API_KEY=<your_key>`
   - `mkdir -p ~/.config/tinify && echo "<your_key>" > ~/.config/tinify/token`
   Then link them to https://tinify.com/developers for a free key.

Preferred invocation:

```bash
python3 scripts/compress.py <input>
```

Avoid `--api-key` in normal usage; it exposes the secret in shell history.

## Quick Start

```bash
# Compress a single image (output: image_compressed.png)
python3 scripts/compress.py photo.png

# Specify output path
python3 scripts/compress.py photo.jpg output.jpg

# Compress from URL
python3 scripts/compress.py https://example.com/image.png

# Convert format while compressing
python3 scripts/compress.py photo.png --format webp
```

## Batch Compression

For multiple files, run the script in a loop:

```bash
for f in *.jpg; do
  python3 scripts/compress.py "$f"
done
```

Or use `find` for recursive compression:

```bash
find . -name "*.png" | while read f; do
  python3 scripts/compress.py "$f"
done
```

## Supported Formats

| Input | Convert to (`--format`) |
|-------|------------------------|
| .png  | png, jpeg*, webp, avif  |
| .jpg / .jpeg | png, jpeg, webp, avif |
| .webp | png, jpeg*, webp, avif  |
| .avif | png, jpeg*, webp, avif  |

> **\* Transparency**: When converting PNG/WebP/AVIF to JPEG, the script automatically adds `"background": {"color": "#ffffff"}` to the Tinify request (required by the API) and prints a note. Transparent areas become white.

## Output

The script prints:
- Monthly compression count (Tinify tracks usage)
- Input → output size with % reduction
- Output file path

Default output: `<name>_compressed.<ext>` in the same directory as input.

## API Key

Get a free API key at https://tinify.com/developers — free tier allows 500 compressions/month.

Store it securely:
```bash
export TINIFY_API_KEY="your_key_here"
```

Or save it once for all projects:
```bash
mkdir -p ~/.config/tinify
echo "your_key_here" > ~/.config/tinify/token
```
