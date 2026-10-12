# GitHub Issues

View GitHub issues for the current project.

The plugin reads the focused pane's directory, identifies `owner/repo` with `gh repo view`, and lists that repository's issues.

[中文](README.zh.md)

## Requirements

Install the [GitHub CLI](https://cli.github.com) on the machine that runs your panes, then run `gh auth login`.

## Install

From the plugin directory:

```sh
tern plugin link .
```

## Open

Focus a pane inside a Git repository, then:

- Command palette: `View issues for this project`
- Shortcut: ⌥⇧⌘I
- The `#` icon in the top-right of the title bar. It has no text.

If an Issues pane for that directory is already open, the command focuses it instead of opening another.

## Language

The interface follows `LANG` / `LC_ALL` until you choose a language. Chinese locales (`zh*`) use Chinese. Anything else uses English.

Switch from the command palette:

- `使用中文` when the interface is English
- `Use English` when the interface is Chinese

The choice is saved and shared by every window.

## Keys

New issue:

| Key | Action |
| --- | --- |
| n | Open the new-issue form |
| tab | Move between title and body |
| ⌘⏎ | Create |
| esc | Cancel |

`New issue for this project` in the command palette opens the same form. A title is required. The body may be empty. After a successful create, the new issue opens.

List:

| Key | Action |
| --- | --- |
| ↑↓ or k j | Move |
| ⏎ or o | View the body and comments |
| b | Open in the browser |
| y | Copy the link |
| r | Refresh |
| s | Cycle Open / Closed / All |

Press esc in the detail view to go back. The list refreshes every two minutes and shows at most 100 issues. Reopening a project shows the last list and issue body immediately, then refreshes them in the background.
