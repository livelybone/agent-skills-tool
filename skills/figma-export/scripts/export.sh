#!/usr/bin/env bash
set -euo pipefail

# export.sh
# 通过 Figma REST API 批量导出 PNG，下载 + 验证 + 转换 + 压缩
#
# 用法：export.sh <fileKey> <manifest.json> <output_dir> [tinify_skill_dir]
#
# manifest.json 格式：
# [
#   { "id": "1:23", "name": "icon-search" },
#   { "id": "4:56", "name": "logo-main" }
# ]
#
# 需要：FIGMA_TOKEN 环境变量、.env 文件或 ~/.config/figma/token

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <fileKey> <manifest.json> <output_dir> [tinify_skill_dir]" >&2
  exit 2
fi

FILE_KEY="$1"
MANIFEST="$2"
OUTPUT_DIR="$3"
TINIFY_SKILL_DIR="${4:-}"

if [[ ! -f "$MANIFEST" ]]; then
  echo '{"error": "manifest not found: '"$MANIFEST"'"}' >&2
  exit 2
fi

# 将 MANIFEST 转为绝对路径
[[ "$MANIFEST" != /* ]] && MANIFEST="$PWD/$MANIFEST"

# 解析 token：环境变量 → .env（向上查找 git root） → ~/.config/figma/token
FIGMA_TOKEN="${FIGMA_TOKEN:-}"
if [[ -z "$FIGMA_TOKEN" ]]; then
  # 查找项目根目录的 .env（通过 git root，而非 cwd）
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
  if [[ -f "$PROJECT_ROOT/.env" ]]; then
    FIGMA_TOKEN=$(grep -E "^FIGMA_TOKEN=" "$PROJECT_ROOT/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
  fi
fi
if [[ -z "$FIGMA_TOKEN" ]] && [[ -f "$HOME/.config/figma/token" ]]; then
  FIGMA_TOKEN=$(tr -d '[:space:]' < "$HOME/.config/figma/token" 2>/dev/null)
fi
if [[ -z "$FIGMA_TOKEN" ]]; then
  echo '{"error": "FIGMA_TOKEN not found. Set env var, add to project .env, or save to ~/.config/figma/token"}' >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# --- Step 1: 解析 manifest（通过 stdin 传递，避免路径注入） ---

PARSED=$(python3 -c "
import json, sys, re

manifest = json.load(sys.stdin)
name_re = re.compile(r'^[a-z0-9][a-z0-9_-]*$')

ids = []
id_to_name = {}
for item in manifest:
    node_id = item['id']
    name = item['name']
    if not name_re.match(name):
        print(json.dumps({'error': f'invalid name: {name} (must be kebab-case: [a-z0-9][a-z0-9_-]*)'}))
        sys.exit(1)
    encoded_id = node_id.replace(':', '%3A')
    ids.append(encoded_id)
    id_to_name[node_id] = name

print(json.dumps({
    'ids': ','.join(ids),
    'total': len(manifest),
    'id_to_name': id_to_name
}))
" < "$MANIFEST") || {
  echo '{"error": "failed to parse manifest"}' >&2
  exit 2
}

# 检查 name 校验是否失败
if echo "$PARSED" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 'error' not in d else 1)" 2>/dev/null; then
  true
else
  echo "$PARSED" >&2
  exit 2
fi

IDS=$(echo "$PARSED" | python3 -c "import json,sys; print(json.load(sys.stdin)['ids'])")
TOTAL=$(echo "$PARSED" | python3 -c "import json,sys; print(json.load(sys.stdin)['total'])")

# --- Step 2: 调用 Figma Images API ---

BODY_FILE=$(mktemp)
HTTP_CODE=$(curl -sL -o "$BODY_FILE" -w '%{http_code}' \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/images/$FILE_KEY?ids=$IDS&format=png&scale=2" 2>/dev/null) || HTTP_CODE="000"
IMAGES_RESPONSE=$(cat "$BODY_FILE")
rm -f "$BODY_FILE"

if [[ "$HTTP_CODE" != "200" ]]; then
  # 提取 API 错误信息
  API_MSG=$(echo "$IMAGES_RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('err', data.get('message', 'unknown')))
except: print('non-JSON response')
" 2>/dev/null || echo "unknown")
  echo "{\"error\": \"Figma API failed (HTTP $HTTP_CODE): $API_MSG\"}" >&2
  exit 1
fi

# 检查 API 级别错误
API_ERR=$(echo "$IMAGES_RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('err', ''))
" 2>/dev/null || echo "")

if [[ -n "$API_ERR" ]]; then
  echo "{\"error\": \"Figma API error: $API_ERR\"}" >&2
  exit 1
fi

# --- Step 3: 解析 URL 并下载（不使用 eval） ---

SAVED=0
FAILED_NAMES=""

# 生成下载任务列表（JSON → TSV: name\turl）
DOWNLOAD_LIST=$(echo "$IMAGES_RESPONSE" | python3 -c "
import json, sys

id_to_name = $( echo "$PARSED" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin)['id_to_name']))" )
images = json.load(sys.stdin).get('images', {})

for node_id, url in images.items():
    name = id_to_name.get(node_id, node_id.replace(':', '-'))
    if url:
        print(f'{name}\t{url}')
    else:
        print(f'{name}\t__NULL__')
" 2>/dev/null)

# 并行下载，跟踪每个任务的 name 和 pid  # cSpell:ignore PIDS
declare -a DL_NAMES=()  # 期望下载的 name 列表
declare -a DL_PIDS=()   # 对应的 pid 列表

while IFS=$'\t' read -r name url; do
  [[ -z "$name" ]] && continue
  if [[ "$url" == "__NULL__" ]]; then
    FAILED_NAMES="$FAILED_NAMES ${name}(no_render_url)"
    continue
  fi
  curl -sL --fail --max-time 60 -o "$OUTPUT_DIR/${name}@2x.png" "$url" &
  DL_NAMES+=("$name")
  DL_PIDS+=($!)
done <<< "$DOWNLOAD_LIST"

# 等待所有下载，逐个检查退出码
for i in "${!DL_PIDS[@]}"; do
  if wait "${DL_PIDS[$i]}" 2>/dev/null; then
    # curl 成功，检查文件是否有效
    OUTFILE="$OUTPUT_DIR/${DL_NAMES[$i]}@2x.png"
    if [[ -s "$OUTFILE" ]]; then
      SAVED=$((SAVED + 1))
    else
      FAILED_NAMES="$FAILED_NAMES ${DL_NAMES[$i]}(empty_file)"
      rm -f "$OUTFILE"
    fi
  else
    # curl 失败（网络错误、HTTP 错误等）
    FAILED_NAMES="$FAILED_NAMES ${DL_NAMES[$i]}(download)"
    rm -f "$OUTPUT_DIR/${DL_NAMES[$i]}@2x.png"
  fi
done

# --- Step 4: 格式验证 + SVG→PNG 转换 ---

CONVERTED=0
for f in "$OUTPUT_DIR"/*@2x.png; do
  [[ -f "$f" ]] || continue

  MAGIC=$(head -c 8 "$f" | xxd -p 2>/dev/null || true)
  [[ "$MAGIC" == "89504e470d0a1a0a" ]] && continue

  if head -c 200 "$f" | grep -q "<svg\|<?xml" 2>/dev/null; then
    SVG_TMP="${f%.png}.tmp.svg"
    mv "$f" "$SVG_TMP"
    DONE=false

    # macOS: qlmanage  # cSpell:ignore qlmanage
    if ! $DONE && command -v qlmanage &>/dev/null; then
      if qlmanage -t -s 512 -o "$OUTPUT_DIR" "$SVG_TMP" &>/dev/null; then
        QLOUT="$OUTPUT_DIR/$(basename "$SVG_TMP").png"  # cSpell:ignore QLOUT
        if [[ -f "$QLOUT" ]]; then
          mv "$QLOUT" "$f"
          CONVERTED=$((CONVERTED + 1))
          DONE=true
        fi
      fi
    fi

    # rsvg-convert  # cSpell:ignore rsvg
    if ! $DONE && command -v rsvg-convert &>/dev/null; then
      if rsvg-convert "$SVG_TMP" -o "$f" 2>/dev/null; then
        CONVERTED=$((CONVERTED + 1))
        DONE=true
      fi
    fi

    if ! $DONE; then
      mv "$SVG_TMP" "${f%.png}.svg"
      NAME=$(basename "$f" @2x.png)
      FAILED_NAMES="$FAILED_NAMES ${NAME}(svg_convert)"
    else
      rm -f "$SVG_TMP"
    fi
  else
    NAME=$(basename "$f" @2x.png)
    FAILED_NAMES="$FAILED_NAMES ${NAME}(unknown_format)"
  fi
done

# --- Step 5: 压缩 ---

COMPRESSED=0
if [[ -n "$TINIFY_SKILL_DIR" ]] && [[ -f "$TINIFY_SKILL_DIR/scripts/compress.py" ]]; then
  TINIFY_KEY="${TINIFY_API_KEY:-}"
  if [[ -z "$TINIFY_KEY" ]]; then
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
      TINIFY_KEY=$(grep -E "^TINIFY_API_KEY=" "$PROJECT_ROOT/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
    fi
  fi

  if [[ -n "$TINIFY_KEY" ]]; then
    export TINIFY_API_KEY="$TINIFY_KEY"
    for f in "$OUTPUT_DIR"/*@2x.png; do
      [[ -f "$f" ]] || continue
      MAGIC=$(head -c 8 "$f" | xxd -p 2>/dev/null || true)
      if [[ "$MAGIC" == "89504e470d0a1a0a" ]]; then
        if python3 "$TINIFY_SKILL_DIR/scripts/compress.py" "$f" "$f" 2>/dev/null; then
          COMPRESSED=$((COMPRESSED + 1))
        fi
      fi
    done
  fi
fi

# --- Step 6: 输出结果（通过 stdin 传参，避免路径注入） ---

FAILED_CLEAN=$(echo "$FAILED_NAMES" | xargs)

python3 -c "
import json, os, glob, sys

args = json.load(sys.stdin)
output_dir = args['output_dir']

files = []
for pattern in [os.path.join(output_dir, '*@2x.png'), os.path.join(output_dir, '*@2x.svg')]:
    for f in sorted(glob.glob(pattern)):
        size = os.path.getsize(f)
        with open(f, 'rb') as fh:
            magic = fh.read(8).hex()
        fmt = 'png' if magic == '89504e470d0a1a0a' else 'svg' if f.endswith('.svg') else 'other'
        files.append({'file': os.path.basename(f), 'path': f, 'size': size, 'format': fmt})

result = {
    'total': args['total'],
    'saved': args['saved'],
    'converted': args['converted'],
    'compressed': args['compressed'],
    'failed': args['failed'],
    'files': files
}
print(json.dumps(result, indent=2))
" <<< "$(printf '{"output_dir":"%s","total":%d,"saved":%d,"converted":%d,"compressed":%d,"failed":"%s"}' \
  "$OUTPUT_DIR" "$TOTAL" "$SAVED" "$CONVERTED" "$COMPRESSED" "$FAILED_CLEAN")"
