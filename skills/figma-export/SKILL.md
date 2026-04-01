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

**快速路径**：如果用户已明确给出 node ID 列表或资源清单，直接跳到 Step 3 生成 manifest，不需要调用 MCP。

**标准路径**：通过 Figma MCP 插件获取节点信息（有截图辅助 agent 识别）：

1. 调用 `get_design_context` — 获取截图 + 节点结构 + 样式信息
2. 调用 `get_metadata` — 获取完整节点树（id、name、type、尺寸）

Agent 结合截图和节点树识别需要导出的资源：
- 独立图片节点（Image、Ellipse with fill）
- icon 组件（小尺寸的 Frame/Group，含 Vector 子节点）
- logo/mascot（较大的复合节点）
- 复合 icon（如 Google logo 由多个 Vector 组成）：**选择父节点**而非子 Vector

### Step 3: 导出 + 保存 + 验证 + 压缩（一次脚本调用）

Agent 将需要导出的节点 ID 和名称写入 `manifest.json`：

```json
[
  { "id": "1:23", "name": "icon-search" },
  { "id": "4:56", "name": "icon-settings" },
  { "id": "7:89", "name": "logo-main" }
]
```

- `id`：Figma 节点 ID
- `name`：kebab-case 文件名（脚本自动追加 `@2x.png`）

然后一次脚本调用完成所有工作：

```bash
"$SKILL_DIR/scripts/export.sh" <fileKey> manifest.json "<output_dir>" [tinify_skill_dir]
```

脚本自动完成：
1. 调用 Figma REST API `GET /v1/images/:fileKey?ids=...&format=png&scale=2` 批量获取下载 URL（`format=png` 确保服务端渲染为 PNG，`scale=2` 对应 @2x）
2. 并行下载所有 PNG 到 `<output_dir>`
3. PNG 魔数验证；SVG 内容自动转换为 PNG（macOS `qlmanage` / `rsvg-convert`）
4. Tinify 压缩（如提供了 tinify_skill_dir 且有 API Key）
5. 输出 JSON 结果汇总

**放置规则**：`<output_dir>` 就近放到使用该资源的组件/页面的 `assets/` 子目录。若无法定位消费方，回退到项目根目录下的 `assets/` 或 `public/assets/`。

### Step 4: 验证（可选）

脚本已完成格式校验。如需视觉确认，用 Read 工具抽检 1-2 张图片即可。不需要逐张检查。

## 路径解析

- `$SKILL_DIR`：本 skill 的安装目录（包含此 `SKILL.md` 的目录）
- `$TINIFY_SKILL_DIR`：tinify skill 的安装目录。留空则跳过压缩
- `FIGMA_TOKEN`：解析顺序：环境变量 → `.env` 文件 → `~/.config/figma/token` → 提示用户配置

## 错误处理

| 步骤 | 失败场景 | 处理方式 |
|------|---------|---------|
| Step 1 | Figma URL 格式不合法 | 提示用户检查 URL |
| Step 2 | MCP `get_design_context` / `get_metadata` 失败 | 检查 Figma MCP 插件是否已连接，提示用户排查 |
| Step 2 | 未识别到可导出的资源节点 | 告知用户，请求手动指定 node ID |
| Step 3 | `FIGMA_TOKEN` 缺失 | 引导用户生成 PAT 并添加到 `.env`（见前置条件） |
| Step 3 | `export.sh` 部分节点导出失败 | 脚本记录失败项（`failed` 字段），其余正常处理，agent 汇总报告 |
| Step 3 | SVG 转 PNG 失败 | 保留 `.svg` 文件，报告给用户 |
| Step 3 | Tinify API Key 缺失 | 自动跳过压缩，保留未压缩文件 |
