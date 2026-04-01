---
name: figma-export
description: "从 Figma 设计稿中导出 icon/图片资源为 PNG 并用 Tinify 压缩，保存到项目就近 assets 目录。触发词：切图、导出图片、export assets、Figma 切图、从 Figma 导出 icon、extract images from Figma。当用户提供 Figma URL 并要求导出/切图/提取图片资源时触发。"
---

# Figma Export & Compress

通过 Figma REST API 导出 icon/图片为 PNG，压缩后保存到项目中。全流程脚本化，图片二进制数据不经过 LLM 上下文。

## 前置条件

- **Figma MCP 插件**（必须）：用于节点识别阶段（`get_design_context` / `get_metadata`），提供截图 + 结构化元数据，帮助 agent 准确识别资源节点。
- **Figma Personal Access Token**：用于图片导出阶段（REST API）。脚本按以下顺序查找：
  1. 环境变量 `FIGMA_TOKEN`
  2. 项目 `.env` 文件中的 `FIGMA_TOKEN=<token>`
  3. `~/.config/figma/token` 文件（推荐，一次配置全项目通用）
  4. 都没找到时，agent 应提示用户配置：
     - 进入 Figma → Settings → Personal access tokens → Generate new token
     - 推荐：`mkdir -p ~/.config/figma && echo "<token>" > ~/.config/figma/token`
     - 或添加到项目 `.env`：`FIGMA_TOKEN=<token>`（确认 `.env` 在 `.gitignore` 中）
- **tinify skill**（可选）：提供 PNG 压缩能力。安装位置：项目级 `skills/tinify/`、`.claude/skills/tinify/`、`.codex/skills/tinify/`、`.gemini/skills/tinify/`，或全局 `~/.claude/skills/tinify/`、`$CODEX_HOME/skills/tinify/`、`~/.gemini/skills/tinify/`。

## 流程

### Step 1: 解析 Figma URL

从用户提供的 Figma URL 中解析 `fileKey` 和 `nodeId`：

```
https://www.figma.com/design/<fileKey>/...?node-id=<nodeId>
```

### Step 2: 识别资源

**快速路径**：如果项目里已经存在可复用的 `nodes-<fileKey>-<nodeId>.json` 缓存，或其他流程已经产出了结构化资源清单，直接进入导出步骤，不需要再次调用 MCP 识别节点。

典型场景：
- 上一次切图已经生成过同一节点的 `nodes-<fileKey>-<nodeId>.json`
- agent 在更早步骤已经完成节点识别并产出了结构化清单
- 用户明确指定“切头像、切这几个图标”，且现有 `nodes-<fileKey>-<nodeId>.json` 已能覆盖这些资源

**标准路径**：通过 Figma MCP 插件获取节点信息（有截图辅助 agent 识别）：

1. 调用 `get_design_context` — 获取截图 + 节点结构 + 样式信息
2. 调用 `get_metadata` — 获取完整节点树（id、name、type、尺寸）

Agent 结合截图和节点树识别需要导出的资源：
- 独立图片节点（Image、Ellipse with fill）
- icon 组件（小尺寸的 Frame/Group，含 Vector 子节点）
- logo/mascot（较大的复合节点）
- 复合 icon（如 Google logo 由多个 Vector 组成）：**选择父节点**而非子 Vector

### Step 3: 生成 nodes 缓存

Agent 将识别出的候选节点写入项目内的 `nodes-<fileKey>-<nodeId>.json`，作为**节点分析缓存 + 导出状态文件**。不再单独生成 manifest。

建议命名：

```text
.figma-export/nodes-<fileKey>-<nodeId>.json
```

最小结构：

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-04-01T20:00:00+0800",
  "source": {
    "fileKey": "ocg7X11AMN1RP4VXjdfS1a",
    "rootNodeId": "859:3392",
    "version": "optional",
    "lastModified": "optional"
  },
  "analysis": {
    "tool": "figma-mcp",
    "status": "completed"
  },
  "nodes": [
    {
      "id": "859:3578",
      "name": "Frame",
      "type": "FRAME",
      "width": 18,
      "height": 18,
      "export": {
        "selected": true,
        "reason": "workspace icon",
        "fileName": "icon-workspace",
        "format": "png",
        "scale": 2,
        "status": "pending",
        "outputPath": "",
        "lastExportedAt": "",
        "error": ""
      }
    }
  ]
}
```

规则：
- `nodes` 只存**候选可导出节点**，不要缓存 Figma 原始整包响应
- `export.selected=true` 表示本次要切图
- `export.fileName` 必须是 kebab-case（仅小写字母、数字、连字符 `-`），脚本自动追加 `@2x.png`
- `export.format` 当前仅支持 `png`，`export.scale` 当前仅支持 `2`
- 后续补切、重切、改输出目录时，直接复用同一份 `nodes-<fileKey>-<nodeId>.json`

### Step 4: 导出 + 保存 + 验证 + 压缩（一次脚本调用）

一次脚本调用完成所有工作：

```bash
"$SKILL_DIR/scripts/export.sh" <fileKey> nodes.json "<output_dir>" [tinify_skill_dir]
```

脚本自动完成：
1. 调用 Figma REST API `GET /v1/images/:fileKey?ids=...&format=png&scale=2` 批量获取下载 URL（`format=png` 确保服务端渲染为 PNG，当前固定 `scale=2`，对应 `@2x`）
2. 并行下载所有 PNG 到 `<output_dir>`
3. PNG 魔数验证；SVG 内容自动转换为 PNG（macOS 自带 `qlmanage` 或系统已安装的 `rsvg-convert`）
4. Tinify 压缩（如提供了 tinify_skill_dir 且有 API Key）
5. 将导出结果回写到 `nodes.json` 里的 `nodes[].export`
6. 输出 JSON 结果汇总

结果 JSON 会包含输入文件路径和模式（`nodes_json` 或 `legacy_manifest`）。推荐始终使用 `nodes_json`。

**放置规则**：`<output_dir>` 就近放到使用该资源的组件/页面的 `assets/` 子目录。若无法定位消费方，回退到项目根目录下的 `assets/` 或 `public/assets/`。

兼容性：
- 旧数组格式 manifest 仍可作为输入，但仅用于兼容旧流程
- 旧 manifest 输入不会回写导出状态；推荐尽快迁移到 `nodes-<fileKey>-<nodeId>.json`

### Step 5: 验证（可选）

脚本已完成格式校验。如需视觉确认，用 Read 工具抽检 1-2 张图片即可。不需要逐张检查。

## 路径解析

- `$SKILL_DIR`：本 skill 的安装目录（包含此 `SKILL.md` 的目录）
- `$TINIFY_SKILL_DIR`：tinify skill 的安装目录。留空则跳过压缩
- `FIGMA_TOKEN`：解析顺序：环境变量 → `.env` 文件 → `~/.config/figma/token` → 提示用户配置
- SVG 回退转换依赖：优先使用 macOS `qlmanage`；若不可用，可安装 `rsvg-convert`

## 错误处理

| 步骤 | 失败场景 | 处理方式 |
|------|---------|---------|
| Step 1 | Figma URL 格式不合法 | 提示用户检查 URL |
| Step 2 | MCP `get_design_context` / `get_metadata` 失败 | 检查 Figma MCP 插件是否已连接，提示用户排查 |
| Step 2 | 未识别到可导出的资源节点 | 告知用户，请求手动指定 node ID |
| Step 4 | `FIGMA_TOKEN` 缺失 | 引导用户生成 PAT 并添加到 `.env`（见前置条件） |
| Step 4 | `export.sh` 部分节点导出失败 | 脚本记录失败项（`failed` 字段），其余正常处理，agent 汇总报告 |
| Step 4 | `export.format` 不是 `png` 或 `export.scale` 不是 `2` | 当前脚本直接报错；如需其他格式/倍率，先改脚本契约 |
| Step 4 | SVG 转 PNG 失败 | 保留 `.svg` 文件，报告给用户 |
| Step 4 | Tinify API Key 缺失 | 自动跳过压缩，保留未压缩文件 |
