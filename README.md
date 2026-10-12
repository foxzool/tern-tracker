# GitHub Issues

查看当前项目的 GitHub issue。

插件读取聚焦 pane 的目录，用 `gh repo view` 识别 `owner/repo`，再列出这个仓库的 issue。

## 准备

在运行 pane 的机器上安装 [GitHub CLI](https://cli.github.com)，并执行 `gh auth login`。

## 安装

在插件目录执行：

```sh
tern plugin link .
```

## 打开

聚焦一个位于 Git 仓库里的 pane，然后：

- 命令面板：`查看当前项目的 Issues`
- 快捷键：⌥⇧⌘I
- 标题栏右侧的 `#` 图标

已有同一目录的 Issues pane 时，命令会聚焦它，而不是再开一个。

## 按键

新建：

| 键 | 作用 |
| --- | --- |
| n | 打开新建表单 |
| tab | 在标题和正文之间切换 |
| ⌘⏎ | 创建 |
| esc | 取消 |

命令面板里的「新建当前项目的 Issue」也打开这个表单。标题必填，正文可空。创建成功后打开新 issue。

列表：

| 键 | 作用 |
| --- | --- |
| ↑↓ 或 k j | 移动 |
| ⏎ 或 o | 查看正文和评论 |
| b | 在浏览器打开 |
| y | 复制链接 |
| r | 刷新 |
| s | 切换 打开 / 已关闭 / 全部 |

正文里按 esc 返回。列表每两分钟刷新一次，最多显示 100 条。
