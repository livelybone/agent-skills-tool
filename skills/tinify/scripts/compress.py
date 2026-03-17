#!/usr/bin/env python3
"""Compress images using the Tinify API.

Supported formats: AVIF, WebP, JPEG, PNG

Usage:
    compress.py <input> [<output>] --api-key <key>
    compress.py <input> [<output>] --api-key <key> --format <fmt>

Arguments:
    input       Path to image file or URL
    output      Output file path (default: <input>_compressed.<ext>)

Options:
    --api-key   Tinify API key (or set TINIFY_API_KEY env var)
    --format    Convert to format: avif, webp, jpeg, png (optional)
"""

import argparse
import base64
import os
import sys
import urllib.request
import urllib.error
import json
from pathlib import Path

SUPPORTED_FORMATS = {".avif", ".webp", ".jpg", ".jpeg", ".png"}
SUPPORTED_CONVERT_FORMATS = {"avif", "webp", "jpeg", "png"}
# Formats that may contain transparency; explicit background needed when converting to JPEG
POTENTIALLY_TRANSPARENT = {".png", ".webp", ".avif"}
API_BASE = "https://api.tinify.com"
REQUEST_TIMEOUT = 30  # seconds


def build_auth_header(api_key: str) -> str:
    credentials = base64.b64encode(f"api:{api_key}".encode()).decode()
    return f"Basic {credentials}"


def compress_image(source: str, api_key: str) -> tuple[str, int]:
    """Upload image or URL to Tinify and return (output_url, compression_count)."""
    auth = build_auth_header(api_key)

    is_url = source.startswith("http://") or source.startswith("https://")
    if is_url:
        payload = json.dumps({"source": {"url": source}}).encode()
        req = urllib.request.Request(
            f"{API_BASE}/shrink",
            data=payload,
            headers={
                "Authorization": auth,
                "Content-Type": "application/json",
            },
        )
    else:
        try:
            with open(source, "rb") as f:
                data = f.read()
        except FileNotFoundError:
            print(f"Error: file not found: {source}", file=sys.stderr)
            sys.exit(1)
        except OSError as e:
            print(f"Error reading file: {e}", file=sys.stderr)
            sys.exit(1)
        req = urllib.request.Request(
            f"{API_BASE}/shrink",
            data=data,
            headers={
                "Authorization": auth,
                "Content-Type": "application/octet-stream",
            },
        )

    try:
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            output_url = resp.headers.get("Location")
            if not output_url:
                print("Error: Tinify response missing Location header", file=sys.stderr)
                sys.exit(1)
            compression_count = int(resp.headers.get("Compression-Count", 0))
            return output_url, compression_count
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            err = json.loads(body)
            print(f"API error ({e.code}): {err.get('message', body)}", file=sys.stderr)
        except json.JSONDecodeError:
            print(f"API error ({e.code}): {body}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"Network error: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except TimeoutError:
        print(f"Request timed out after {REQUEST_TIMEOUT}s", file=sys.stderr)
        sys.exit(1)


def download_output(
    output_url: str,
    api_key: str,
    convert_format: str | None = None,
    with_background: bool = False,
) -> bytes:
    """Download compressed image, optionally converting format."""
    auth = build_auth_header(api_key)

    if convert_format:
        convert_body: dict = {"type": f"image/{convert_format}"}
        if with_background:
            # Required by Tinify when converting transparent formats (PNG/WebP/AVIF) to JPEG
            convert_body["background"] = {"color": "#ffffff"}
        payload = json.dumps({"convert": convert_body}).encode()
        req = urllib.request.Request(
            output_url,
            data=payload,
            headers={
                "Authorization": auth,
                "Content-Type": "application/json",
            },
            method="POST",
        )
    else:
        req = urllib.request.Request(
            output_url,
            headers={"Authorization": auth},
        )

    try:
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            err = json.loads(body)
            print(f"Download error ({e.code}): {err.get('message', body)}", file=sys.stderr)
        except json.JSONDecodeError:
            print(f"Download error ({e.code}): {body}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"Network error during download: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except TimeoutError:
        print(f"Download timed out after {REQUEST_TIMEOUT}s", file=sys.stderr)
        sys.exit(1)


def resolve_output_path(input_path: str, output_arg: str | None, convert_format: str | None) -> str:
    """Determine output file path."""
    if output_arg:
        return output_arg

    is_url = input_path.startswith("http://") or input_path.startswith("https://")
    if is_url:
        # Derive filename from the URL's last path segment (strip query string and fragment first)
        url_path = input_path.split("?")[0].split("#")[0].rstrip("/")
        filename = url_path.split("/")[-1]
        original_ext = Path(filename).suffix.lower()
        stem = Path(filename).stem or "image"
        if convert_format:
            ext = ".jpg" if convert_format == "jpeg" else f".{convert_format}"
        else:
            ext = original_ext or ".png"
        return f"{stem}_compressed{ext}"

    p = Path(input_path)
    if convert_format:
        ext = ".jpg" if convert_format == "jpeg" else f".{convert_format}"
    else:
        ext = p.suffix.lower() or ".png"

    return str(p.parent / f"{p.stem}_compressed{ext}")


def needs_background_fill(input_path: str, convert_format: str | None, is_url: bool) -> bool:
    """Return True when converting a potentially-transparent format to JPEG."""
    if convert_format != "jpeg":
        return False
    if is_url:
        # Can't reliably detect source format from URL; always supply background for safety
        return True
    return Path(input_path).suffix.lower() in POTENTIALLY_TRANSPARENT


def main():
    parser = argparse.ArgumentParser(description="Compress images via Tinify API")
    parser.add_argument("input", help="Image file path or URL")
    parser.add_argument("output", nargs="?", help="Output file path")
    parser.add_argument("--api-key", help="Tinify API key (or TINIFY_API_KEY env var)")
    parser.add_argument(
        "--format",
        choices=sorted(SUPPORTED_CONVERT_FORMATS),
        help="Convert to target format",
    )
    args = parser.parse_args()

    api_key = args.api_key or os.environ.get("TINIFY_API_KEY")
    if not api_key:
        print("Error: provide --api-key or set TINIFY_API_KEY env var", file=sys.stderr)
        sys.exit(1)

    is_url = args.input.startswith("http://") or args.input.startswith("https://")
    if not is_url:
        suffix = Path(args.input).suffix.lower()
        if suffix not in SUPPORTED_FORMATS:
            print(
                f"Unsupported format '{suffix}'. Supported: {', '.join(sorted(SUPPORTED_FORMATS))}",
                file=sys.stderr,
            )
            sys.exit(1)

    with_bg = needs_background_fill(args.input, args.format, is_url)
    if with_bg:
        print(
            "Note: converting to JPEG — transparent areas will be filled with white (#ffffff).",
            file=sys.stderr,
        )

    print(f"Compressing: {args.input}")
    output_url, compression_count = compress_image(args.input, api_key)
    print(f"Compression count this month: {compression_count}")

    image_data = download_output(output_url, api_key, args.format, with_background=with_bg)

    output_path = resolve_output_path(args.input, args.output, args.format)
    try:
        with open(output_path, "wb") as f:
            f.write(image_data)
    except OSError as e:
        print(f"Error writing output: {e}", file=sys.stderr)
        sys.exit(1)

    output_size = len(image_data)
    if not is_url:
        try:
            input_size = os.path.getsize(args.input)
            reduction = (1 - output_size / input_size) * 100
            print(f"Saved to: {output_path}")
            print(f"Size: {input_size:,} → {output_size:,} bytes ({reduction:.1f}% reduction)")
        except OSError:
            print(f"Saved to: {output_path} ({output_size:,} bytes)")
    else:
        print(f"Saved to: {output_path} ({output_size:,} bytes)")


if __name__ == "__main__":
    main()
