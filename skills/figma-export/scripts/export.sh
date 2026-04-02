#!/usr/bin/env bash
set -euo pipefail

# export.sh
# 通过 Figma REST API 批量导出 PNG，下载 + 验证 + 转换 + 压缩
#
# 用法：export.sh <fileKey> <nodes-or-manifest.json> <output_dir> [tinify_skill_dir]
#
# nodes.json（推荐）格式：
# {
#   "source": { "fileKey": "abc", "rootNodeId": "1:2" },
#   "nodes": [
#     {
#       "id": "1:23",
#       "name": "Frame",
#       "type": "FRAME",
#       "width": 18,
#       "height": 18,
#       "export": {
#         "selected": true,
#         "fileName": "icon-search",
#         "format": "png",
#         "scale": 2
#       }
#     }
#   ]
# }
#
# 兼容旧 manifest.json 数组格式：
# [
#   { "id": "1:23", "name": "icon-search" },
#   { "id": "4:56", "name": "logo-main" }
# ]
#
# 需要：FIGMA_TOKEN 环境变量、.env 文件或 ~/.config/figma/token

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <fileKey> <nodes-or-manifest.json> <output_dir> [tinify_skill_dir]" >&2
  exit 2
fi

FILE_KEY="$1"
INPUT_JSON="$2"
OUTPUT_DIR="$3"
TINIFY_SKILL_DIR="${4:-}"

if [[ ! -f "$INPUT_JSON" ]]; then
  echo '{"error": "input json not found: '"$INPUT_JSON"'"}' >&2
  exit 2
fi

# 将 INPUT_JSON 转为绝对路径
[[ "$INPUT_JSON" != /* ]] && INPUT_JSON="$PWD/$INPUT_JSON"

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

OUTPUT_SUFFIX='@2x'
BODY_FILE=""
PARSED_FILE=""

cleanup_tmp_files() {
  [[ -n "$BODY_FILE" ]] && rm -f "$BODY_FILE"
  [[ -n "$PARSED_FILE" ]] && rm -f "$PARSED_FILE"
}

trap cleanup_tmp_files EXIT

# --- Step 1: 解析输入文件（通过 stdin 传递，避免路径注入） ---

if ! PARSED=$(python3 -c "
import json, sys, re

name_re = re.compile(r'^[a-z0-9][a-z0-9-]*$')
payload = json.load(sys.stdin)

mode = ''
source_file_key = ''
source_root_node_id = ''
source_version = ''
source_last_modified = ''
entries = []
id_to_name = {}

if isinstance(payload, list):
    mode = 'legacy_manifest'
    for item in payload:
        node_id = item['id']
        file_name = item['name']
        if not name_re.match(file_name):
            print(json.dumps({'error': f'invalid name: {file_name} (must be kebab-case: [a-z0-9][a-z0-9-]*)'}))
            sys.exit(1)
        entries.append({
            'id': node_id,
            'fileName': file_name,
            'format': 'png',
            'scale': 2
        })
        id_to_name[node_id] = file_name
elif isinstance(payload, dict):
    mode = 'nodes_json'
    source = payload.get('source') or {}
    source_file_key = source.get('fileKey', '')
    source_root_node_id = source.get('rootNodeId', '')
    source_version = source.get('version', '')
    source_last_modified = source.get('lastModified', '')

    nodes = payload.get('nodes')
    if not isinstance(nodes, list):
        print(json.dumps({'error': 'nodes json must contain a nodes array'}))
        sys.exit(1)

    for node in nodes:
        export = node.get('export') or {}
        if export.get('selected') is not True:
            continue

        node_id = node['id']
        file_name = export.get('fileName', '')
        if not file_name:
            print(json.dumps({'error': f'missing export.fileName for selected node: {node_id}'}))
            sys.exit(1)
        if not name_re.match(file_name):
            print(json.dumps({'error': f'invalid export.fileName: {file_name} (must be kebab-case: [a-z0-9][a-z0-9-]*)'}))
            sys.exit(1)

        export_format = export.get('format', 'png')
        export_scale = export.get('scale', 2)
        if export_scale != 2:
            print(json.dumps({'error': f'unsupported export.scale: {export_scale} (only scale=2 / @2x is supported)'}))
            sys.exit(1)
        entries.append({
            'id': node_id,
            'fileName': file_name,
            'format': export_format,
            'scale': export_scale
        })
        id_to_name[node_id] = file_name
else:
    print(json.dumps({'error': 'input json must be either a nodes object or a legacy manifest array'}))
    sys.exit(1)

if not entries:
    print(json.dumps({'error': 'no export entries found in input json'}))
    sys.exit(1)

if source_file_key and source_file_key != sys.argv[1]:
    print(json.dumps({'error': f'input source.fileKey ({source_file_key}) does not match CLI fileKey ({sys.argv[1]})'}))
    sys.exit(1)

ids = [entry['id'].replace(':', '%3A') for entry in entries]
formats = {entry['format'] for entry in entries}
scales = {entry['scale'] for entry in entries}
if len(formats) != 1 or len(scales) != 1:
    print(json.dumps({'error': 'all selected nodes must share the same export.format and export.scale in one export run'}))
    sys.exit(1)

export_format = next(iter(formats))
export_scale = next(iter(scales))
if export_format != 'png':
    print(json.dumps({'error': f'unsupported export.format: {export_format} (only png is currently supported)'}))
    sys.exit(1)

print(json.dumps({
    'mode': mode,
    'input': sys.argv[2],
    'source': {
        'fileKey': source_file_key,
        'rootNodeId': source_root_node_id,
        'version': source_version,
        'lastModified': source_last_modified
    },
    'ids': ','.join(ids),
    'total': len(entries),
    'export': {
        'format': export_format,
        'scale': export_scale
    },
    'entries': entries,
    'id_to_name': id_to_name
}))
" "$FILE_KEY" "$INPUT_JSON" < "$INPUT_JSON"); then
  if [[ -n "${PARSED:-}" ]]; then
    echo "$PARSED" >&2
  else
    echo '{"error": "failed to parse input json"}' >&2
  fi
  exit 2
fi

# 检查解析错误
if echo "$PARSED" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(1 if 'error' in d else 0)" 2>/dev/null; then
  true
else
  echo "$PARSED" >&2
  exit 2
fi

IDS=$(echo "$PARSED" | python3 -c "import json,sys; print(json.load(sys.stdin)['ids'])")
TOTAL=$(echo "$PARSED" | python3 -c "import json,sys; print(json.load(sys.stdin)['total'])")
EXPORT_FORMAT=$(echo "$PARSED" | python3 -c "import json,sys; print(json.load(sys.stdin)['export']['format'])")
EXPORT_SCALE=$(echo "$PARSED" | python3 -c "import json,sys; print(json.load(sys.stdin)['export']['scale'])")
ID_TO_NAME_JSON=$(echo "$PARSED" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin)['id_to_name']))")

# --- Step 2: 调用 Figma Images API ---

BODY_FILE=$(mktemp)
HTTP_CODE=$(curl -sL -o "$BODY_FILE" -w '%{http_code}' \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/images/$FILE_KEY?ids=$IDS&format=$EXPORT_FORMAT&scale=$EXPORT_SCALE" 2>/dev/null) || HTTP_CODE="000"
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
err = data.get('err')
print('' if err is None else err)
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

id_to_name = json.loads(sys.argv[1])
images = json.load(sys.stdin).get('images', {})

for node_id, url in images.items():
    name = id_to_name.get(node_id, node_id.replace(':', '-'))
    if url:
        print(f'{name}\t{url}')
    else:
        print(f'{name}\t__NULL__')
" "$ID_TO_NAME_JSON" 2>/dev/null)

# 并行下载，跟踪每个任务的 name 和 pid  # cSpell:ignore PIDS
declare -a DL_NAMES=()  # 期望下载的 name 列表
declare -a DL_PIDS=()   # 对应的 pid 列表

while IFS=$'\t' read -r name url; do
  [[ -z "$name" ]] && continue
  if [[ "$url" == "__NULL__" ]]; then
    FAILED_NAMES="$FAILED_NAMES ${name}(no_render_url)"
    continue
  fi
  curl -sL --fail --max-time 60 -o "$OUTPUT_DIR/${name}${OUTPUT_SUFFIX}.png" "$url" &
  DL_NAMES+=("$name")
  DL_PIDS+=($!)
done <<< "$DOWNLOAD_LIST"

# 等待所有下载，逐个检查退出码
for i in "${!DL_PIDS[@]}"; do
  if wait "${DL_PIDS[$i]}" 2>/dev/null; then
    # curl 成功，检查文件是否有效
    OUTFILE="$OUTPUT_DIR/${DL_NAMES[$i]}${OUTPUT_SUFFIX}.png"
    if [[ -s "$OUTFILE" ]]; then
      SAVED=$((SAVED + 1))
    else
      FAILED_NAMES="$FAILED_NAMES ${DL_NAMES[$i]}(empty_file)"
      rm -f "$OUTFILE"
    fi
  else
    # curl 失败（网络错误、HTTP 错误等）
    FAILED_NAMES="$FAILED_NAMES ${DL_NAMES[$i]}(download)"
    rm -f "$OUTPUT_DIR/${DL_NAMES[$i]}${OUTPUT_SUFFIX}.png"
  fi
done

# --- Step 4: 格式验证 + SVG→PNG 转换 ---

CONVERTED=0
for f in "$OUTPUT_DIR"/*"${OUTPUT_SUFFIX}".png; do
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
      NAME=$(basename "$f" "${OUTPUT_SUFFIX}.png")
      FAILED_NAMES="$FAILED_NAMES ${NAME}(svg_convert)"
    else
      rm -f "$SVG_TMP"
    fi
  else
    NAME=$(basename "$f" "${OUTPUT_SUFFIX}.png")
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
  if [[ -z "$TINIFY_KEY" ]] && [[ -f "$HOME/.config/tinify/token" ]]; then
    TINIFY_KEY=$(tr -d '[:space:]' < "$HOME/.config/tinify/token" 2>/dev/null)
  fi

  if [[ -n "$TINIFY_KEY" ]]; then
    export TINIFY_API_KEY="$TINIFY_KEY"
    for f in "$OUTPUT_DIR"/*"${OUTPUT_SUFFIX}".png; do
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

# --- Step 6: 回写 nodes.json（仅 nodes 模式） ---

MODE=$(echo "$PARSED" | python3 -c "import json,sys; print(json.load(sys.stdin)['mode'])")
TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S%z')
FAILED_CLEAN=$(echo "$FAILED_NAMES" | xargs)

if [[ "$MODE" == "nodes_json" ]]; then
  PARSED_FILE=$(mktemp)
  printf '%s' "$PARSED" > "$PARSED_FILE"
  python3 - "$INPUT_JSON" "$PARSED_FILE" "$OUTPUT_DIR" "$FAILED_CLEAN" "$TIMESTAMP" "$OUTPUT_SUFFIX" <<'PY'
import json
import os
import sys

input_path, parsed_path, output_dir, failed_clean, timestamp, output_suffix = sys.argv[1:]

with open(input_path, 'r', encoding='utf-8') as fh:
    payload = json.load(fh)
with open(parsed_path, 'r', encoding='utf-8') as fh:
    parsed = json.load(fh)

failure_map = {}
for token in failed_clean.split():
    if token.endswith(')') and '(' in token:
        name, reason = token[:-1].rsplit('(', 1)
        failure_map[name] = reason

entries_by_id = {entry['id']: entry for entry in parsed['entries']}

for node in payload.get('nodes', []):
    node_id = node.get('id')
    if node_id not in entries_by_id:
        continue

    entry = entries_by_id[node_id]
    export = node.setdefault('export', {})
    file_name = entry['fileName']
    png_path = os.path.join(output_dir, f'{file_name}{output_suffix}.png')
    svg_path = os.path.join(output_dir, f'{file_name}{output_suffix}.svg')

    export['selected'] = True
    export['fileName'] = file_name
    export['format'] = entry.get('format', 'png')
    export['scale'] = entry.get('scale', 2)
    export['lastExportedAt'] = timestamp

    if os.path.isfile(png_path):
        export['status'] = 'exported'
        export['outputPath'] = png_path
        export['error'] = ''
    elif os.path.isfile(svg_path):
        export['status'] = 'exported'
        export['outputPath'] = svg_path
        export['error'] = ''
    else:
        export['status'] = 'failed'
        export['outputPath'] = ''
        export['error'] = failure_map.get(file_name, 'missing_output')

payload['generatedAt'] = timestamp

with open(input_path, 'w', encoding='utf-8') as fh:
    json.dump(payload, fh, indent=2, ensure_ascii=False)
    fh.write('\n')
PY
fi

# --- Step 7: 输出结果（通过 stdin 传参，避免路径注入） ---

python3 - "$INPUT_JSON" "$MODE" "$OUTPUT_DIR" "$TOTAL" "$SAVED" "$CONVERTED" "$COMPRESSED" "$FAILED_CLEAN" \
  "$OUTPUT_SUFFIX" <<'PY'
import glob
import json
import os
import sys

input_path, mode, output_dir, total, saved, converted, compressed, failed, output_suffix = sys.argv[1:]

files = []
for pattern in [
    os.path.join(output_dir, f'*{output_suffix}.png'),
    os.path.join(output_dir, f'*{output_suffix}.svg'),
]:
    for file_path in sorted(glob.glob(pattern)):
        size = os.path.getsize(file_path)
        with open(file_path, 'rb') as fh:
            magic = fh.read(8).hex()
        fmt = 'png' if magic == '89504e470d0a1a0a' else 'svg' if file_path.endswith('.svg') else 'other'
        files.append({
            'file': os.path.basename(file_path),
            'path': file_path,
            'size': size,
            'format': fmt,
        })

result = {
    'input': {
        'path': input_path,
        'mode': mode,
    },
    'total': int(total),
    'saved': int(saved),
    'converted': int(converted),
    'compressed': int(compressed),
    'failed': failed,
    'files': files,
}
print(json.dumps(result, indent=2))
PY
