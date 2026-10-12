# Tracker

查看当前项目的 Tracker。

插件读取聚焦 pane 的目录，用 `gh repo view` 识别 GitHub 仓库，再列出这个仓库的 issue。现在只接 GitHub issue。

[English](README.md)

## 准备

在运行 pane 的机器上安装 [GitHub CLI](https://cli.github.com)，并执行 `gh auth login`。

## 安装

在插件目录执行：

```sh
tern plugin link .
```

## 打开

聚焦一个位于 Git 仓库里的 pane，然后：

- 命令面板：`打开当前项目的 Tracker`
- 快捷键：⌥⇧⌘I
- 标题栏右上角的 `#` 图标，没有文字

已有同一目录的 Tracker pane 时，命令会聚焦它，而不是再开一个。

## 语言

未选择语言时，界面跟随 `LANG` / `LC_ALL`。中文环境（`zh*`）用中文，其他用英文。

在命令面板切换：

- 英文界面下是 `使用中文`
- 中文界面下是 `Use English`

选择会保存，所有窗口共用。

## 按键

新建：

| 键 | 作用 |
| --- | --- |
| n | 打开新建表单 |
| tab | 在标题和正文之间切换 |
| ⌘⏎ | 创建 |
| esc | 取消 |

命令面板里的「新建当前项目的 Issue」也打开这个表单。如果当前是 pull request 列表，会先切回 issue，包括从已合并切回打开。标题必填，正文可空。创建成功后打开新 issue。

列表：

| 键 | 作用 |
| --- | --- |
| ↑↓ 或 k j | 移动 |
| ⏎ 或 o | 查看正文和评论 |
| b | 在浏览器打开 |
| y | 复制链接 |
| r | 刷新 |
| s | 切换状态。Issue 是打开 / 已关闭 / 全部。Pull request 是打开 / 已合并 / 已关闭 / 全部 |
| p | 在 issue 和 pull request 之间切换 |

命令面板里的「打开当前项目的 Pull requests」在同一个 pane 里显示 pull request。`n` 只创建 issue，不创建 pull request。

正文里按 esc 返回。列表每两分钟刷新一次，最多显示 100 条。再次打开同一项目时，先显示上次的列表和正文，再在后台刷新。
