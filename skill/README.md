# flutter-miuix-skill

**中文 | [English](#english)**

给 AI 编码工具（Claude Code 等支持 [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills) 的助手）用的 [flutter_miuix](https://github.com/ChuxinNeko/flutter_miuix) 组件库使用指南。

一条命令即可把指南装进你的 Flutter 项目，之后 AI 用 flutter_miuix 搭界面时会自动获得
正确的组件用法、主题接线、组合范式与避坑要点（含原组件及 **12 项 OS4 组件**的中英双语参考）。

OS4 为按需启用的 `MiuixGlass*` API，不替换旧界面。更新 skill 不等于升级 Flutter 依赖或发布新版本；
AI 会先核对项目实际解析包的导出，再决定能否使用 OS4。

## 使用

在你的 Flutter 项目根目录运行：

```bash
npx flutter-miuix-skill
```

装到 `.claude/skills/flutter-miuix/`。然后重启你的 AI 编码工具即可。

### 选项

```bash
npx flutter-miuix-skill --path <dir>   # 指定项目目录（默认当前目录）
npx flutter-miuix-skill --force        # 覆盖已存在的安装
npx flutter-miuix-skill --help         # 帮助
```

## 装了什么

```
.claude/skills/flutter-miuix/
  SKILL.md            # 快速上手 + 组件索引 + 组合范式 + 避坑（中文主）
  references/         # 原组件与 OS4 的 API 参考（中英双语，按分类分文件）
    110_os4.zh.md     # OS4 关键参数、完整接线、锚点/生命周期与旧菜单接入
    110_os4.en.md     # 同主题英文参考
```

- `SKILL.md`：安装、主题接线、`MiuixScaffold` 心智模型、可折叠顶栏 / 底部导航 /
  设置页 / 弹层等组合片段，以及 OS4 选型、版本核对和常见坑。
- `references/NN_分类.{zh,en}.md`：分组件参数、默认值和颜色配置。OS4 参考提供常用签名与
  可独立编译的完整示例；AI 按任务/语言只读相关文件，不一次加载全部。
- OS4 内容包括玻璃材质与采样、顶栏/两类标签/导航、普通/变形/二级/下拉弹窗、对话框、
  旧菜单 `surfaceBuilder`，以及 `MiuixIcons.os4` 的 176 个五字重图标。
- 明确不编造 `MiuixGlassSearchBar` / `MiuixGlassBottomSheet`，并区分 `show` / `visible`、
  `child` / `content`、`onPressed` / `onClick` 和 `items` / `children`。

内容从 flutter_miuix 仓库的 `doc/.api_frag/` 单一真源同步（`npm run sync`）；
用 `npm run check-sync` 检查载荷副本，勿手改 `payload/flutter-miuix/references/`。

## 从本地更新后的源码安装

尚未发布到 npm 的改动，可在 flutter_miuix 仓库根目录安装到指定测试项目，不必等新包发布：

```bash
node skill/scripts/sync-references.mjs
node skill/scripts/sync-references.mjs --check
node skill/bin/cli.mjs --path <目标项目目录> --force
```

`--force` 会覆盖目标项目已有的这份 skill，先保留自己的定制内容。以上只安装 skill，
不修改目标项目的 Flutter 依赖，也不会发布 npm/pub 包。

## 提交进仓库共享

`.claude/skills/` 默认可能被 gitignore 忽略。想让团队共享这份指南，把该目录纳入版本控制即可。

---

## English

An AI coding-assistant skill (Claude Code / [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills))
for the [flutter_miuix](https://github.com/ChuxinNeko/flutter_miuix) component library (HyperOS / MIUI-style
Flutter widgets).

One command installs the guide into your Flutter project, so AI gets correct component usage, theming setup,
composition patterns, and gotchas, with bilingual references for the original components and **12 OS4 components**.

The skill treats `MiuixGlass*` as opt-in and checks the resolved Flutter package exports before using them.
Updating this skill neither upgrades the app dependency nor guarantees that OS4 has been released on pub.dev.

### Usage

Run in your Flutter project root:

```bash
npx flutter-miuix-skill
```

Installs into `.claude/skills/flutter-miuix/`. Restart your AI coding tool afterward.

```bash
npx flutter-miuix-skill --path <dir>   # target project dir (default: cwd)
npx flutter-miuix-skill --force        # overwrite existing install
npx flutter-miuix-skill --help
```

The primary guide (`SKILL.md`) is written in Chinese; the bundled `references/` include both English
(`.en.md`) and Chinese (`.zh.md`) API docs.

`110_os4` covers API differences, a complete compilable example, backdrop sampling, popup anchors/lifecycle,
legacy surface builders and 176 OS4 symbols in five weights. It explicitly distinguishes `show`/`visible`,
`child`/`content`, `onPressed`/`onClick`, and `items`/`children`; it does not invent a Glass search-bar or bottom-sheet API.

To use unpublished changes, run the local sync/check commands above, then
`node skill/bin/cli.mjs --path <target-project> --force` from this repository. The flag replaces that skill
installation, so preserve local customizations first. No Flutter dependency change or package publication is performed.

## License

Apache-2.0 © ChuxinNeko
