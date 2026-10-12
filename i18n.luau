--!strict
-- 界面语言。未设置时看 LANG / LC_ALL，中文环境用 zh，否则 en。
-- 命令面板的切换写入 tern.kv，host 和 window 读同一份。

local STR = {
	en = {
		cmd_open = "Open tracker for this project",
		cmd_create = "New issue for this project",
		cmd_pulls = "Open pull requests for this project",
		cmd_lang = "使用中文",
		lang_switched = "Language: English",
		no_project = "No current project",
		no_project_sub = "Focus a pane inside a project directory.",
		not_loaded = "Tracker is not loaded on this host",
		not_loaded_sub = "Install the plugin on the machine that runs your panes.",
		filter_open = "Open",
		filter_closed = "Closed",
		filter_all = "All",
		age_now = "just now",
		age_min = "%d minutes ago",
		age_hour = "%d hours ago",
		age_day = "%d days ago",
		gh_timeout = "gh did not answer within 30 seconds.",
		gh_auth = "The GitHub CLI is not signed in.",
		not_git = "This directory is not a Git repository.",
		not_github = "This repository has no GitHub remote.",
		gh_no_name = "gh did not return a repository name.",
		cannot_identify = "Could not identify this project's GitHub repository.",
		cannot_start_gh = "Tern could not start the GitHub CLI.",
		gh_missing = "gh is not on this machine's PATH",
		no_cwd = "No project directory.",
		no_cwd_detail = "Open this block from a pane inside a project directory.",
		cannot_load = "Could not load issues.",
		not_a_list = "gh did not return a list of issues.",
		cannot_load_one = "Could not load this issue.",
		not_one_issue = "gh did not return an issue.",
		title_required = "A title is required.",
		cannot_create = "Could not create the issue.",
		created = "Issue created",
		created_num = "Created #%s",
		repo_unconfirmed = "The repository is still being confirmed. Creating an issue is disabled.",
		copied = "Link copied",
		head_missing = "GitHub CLI not found",
		head_auth = "GitHub CLI not signed in",
		head_norepo = "Not a Git repository",
		head_notgithub = "No GitHub remote",
		head_failed = "Could not load issues",
		help_missing = "This block runs `gh` on the machine that runs your panes. Install the GitHub CLI, then press **r**.",
		help_auth = "Run `gh auth login` in a shell on this machine, then press **r**.",
		help_norepo = "Focus a pane inside a Git repository, then open this block from the command palette.",
		help_notgithub = "Add a GitHub remote, or open the block from a GitHub repository.",
		help_failed = "Press **r** to try again.",
		retry = "Retry",
		install = "Install guide",
		empty_closed = "No closed issues.",
		empty_all = "This repository has no issues.",
		empty_open = "No open issues.",
		empty_open_pull = "No open pull requests.",
		empty_closed_pull = "No closed pull requests.",
		empty_merged = "No merged pull requests.",
		empty_all_pull = "This repository has no pull requests.",
		pull_no_create = "Pull requests are not created here.",
		kind_issue = "Issues",
		kind_pull = "Pull requests",
		filter_merged = "Merged",
		badge_merged = "Merged",
		count_merged = "%d merged",
		dock_detail = "esc back   b browser   y copy   r reload",
		dock_list = "↑↓ move   ⏎ view   n new   p pulls   b browser   y copy   r refresh   s state",
		count_open = "%d open",
		count_closed = "%d closed",
		count_all = "%d",
		limit_note = "  showing the first %d",
		refreshing = "  refreshing…",
		updated_at = "  updated %s",
		showing_last = "  showing the last list",
		loading_one = "Loading #%s…",
		badge_closed = "Closed",
		badge_open = "Open",
		author = "Author",
		updated = "Updated",
		comments = "Comments",
		no_body = "This issue has no body.",
		more_comments = "%d more comments are not shown.",
		comments_section = "Comments",
		open_browser = "Open in browser",
		copy_link = "Copy link",
		back = "Back",
		new_issue = "New issue",
		creating = "Creating…",
		create = "Create",
		cancel = "Cancel",
		title_ph = "Title",
		body_ph = "Body, optional",
		compose_dock = "esc cancel   tab switch   ⌘⏎ create",
		current_project = "this project",
		loading_issues = "Loading %s %s issues…",
		loading_pulls = "Loading %s %s pull requests…",
	},
	zh = {
		cmd_open = "打开当前项目的 Tracker",
		cmd_create = "新建当前项目的 Issue",
		cmd_pulls = "打开当前项目的 Pull requests",
		cmd_lang = "Use English",
		lang_switched = "语言：中文",
		no_project = "没有当前项目",
		no_project_sub = "先聚焦一个位于项目目录的 pane。",
		not_loaded = "Tracker 未在此 host 加载",
		not_loaded_sub = "在运行 pane 的机器上安装这个插件。",
		filter_open = "打开",
		filter_closed = "已关闭",
		filter_all = "全部",
		filter_merged = "已合并",
		age_now = "刚刚",
		age_min = "%d 分钟前",
		age_hour = "%d 小时前",
		age_day = "%d 天前",
		gh_timeout = "gh 在 30 秒内没有返回。",
		gh_auth = "GitHub CLI 未登录。",
		not_git = "当前目录不是 Git 仓库。",
		not_github = "这个仓库没有 GitHub 远程。",
		gh_no_name = "gh 没有返回仓库名。",
		cannot_identify = "无法识别当前项目的 GitHub 仓库。",
		cannot_start_gh = "Tern 无法启动 GitHub CLI。",
		gh_missing = "这台机器的 PATH 上没有 gh",
		no_cwd = "没有项目目录。",
		no_cwd_detail = "从项目目录里的 pane 打开。",
		cannot_load = "无法加载 issue。",
		not_a_list = "gh 返回的不是 issue 列表。",
		cannot_load_one = "无法加载这条 issue。",
		not_one_issue = "gh 返回的不是一条 issue。",
		title_required = "标题不能为空。",
		cannot_create = "无法创建 issue。",
		created = "已创建 issue",
		created_num = "已创建 #%s",
		repo_unconfirmed = "仓库还在确认，暂时不能创建 issue。",
		copied = "已复制链接",
		head_missing = "找不到 GitHub CLI",
		head_auth = "GitHub CLI 未登录",
		head_norepo = "不是 Git 仓库",
		head_notgithub = "没有 GitHub 远程",
		head_failed = "无法加载 issue",
		help_missing = "这个 block 在运行 pane 的机器上执行 `gh`。装好 GitHub CLI 后按 **r**。",
		help_auth = "在这台机器的 shell 里运行 `gh auth login`，然后按 **r**。",
		help_norepo = "聚焦一个 Git 仓库里的 pane，再从命令面板打开。",
		help_notgithub = "给仓库加上 GitHub remote，或在 GitHub 仓库目录里打开。",
		help_failed = "按 **r** 再试一次。",
		retry = "重试",
		install = "安装说明",
		empty_closed = "没有已关闭的 issue。",
		empty_all = "这个仓库没有 issue。",
		empty_open = "没有打开的 issue。",
		empty_open_pull = "没有打开的 pull request。",
		empty_closed_pull = "没有已关闭的 pull request。",
		empty_merged = "没有已合并的 pull request。",
		empty_all_pull = "这个仓库没有 pull request。",
		pull_no_create = "这里不能创建 pull request。",
		kind_issue = "Issues",
		kind_pull = "Pull requests",
		badge_merged = "已合并",
		count_merged = "%d 条已合并",
		dock_detail = "esc 返回   b 浏览器   y 复制   r 重载",
		dock_list = "↑↓ 移动   ⏎ 查看   n 新建   p 切换   b 浏览器   y 复制   r 刷新   s 切换状态",
		count_open = "%d 条打开",
		count_closed = "%d 条已关闭",
		count_all = "%d 条全部",
		limit_note = "  只显示前 %d 条",
		refreshing = "  刷新中…",
		updated_at = "  更新于 %s",
		showing_last = "  仍显示上次的列表",
		loading_one = "正在加载 #%s…",
		badge_closed = "已关闭",
		badge_open = "打开",
		author = "作者",
		updated = "更新",
		comments = "评论",
		no_body = "这条 issue 没有正文。",
		more_comments = "还有 %d 条评论未显示。",
		comments_section = "评论",
		open_browser = "浏览器打开",
		copy_link = "复制链接",
		back = "返回",
		new_issue = "新建 issue",
		creating = "正在创建…",
		create = "创建",
		cancel = "取消",
		title_ph = "标题",
		body_ph = "正文，可留空",
		compose_dock = "esc 取消   tab 切换   ⌘⏎ 创建",
		current_project = "当前项目",
		loading_issues = "正在加载 %s 的%s issue…",
		loading_pulls = "正在加载 %s 的%s pull request…",
	},
}

local function detect(): string
	local saved = tern.kv.get("lang")
	if saved == "en" or saved == "zh" then
		return saved
	end
	local env = string.lower(tern.getenv("LANG") or tern.getenv("LC_ALL") or "")
	if string.sub(env, 1, 2) == "zh" then
		return "zh"
	end
	return "en"
end

local function t(key: string): string
	local pack = STR[detect()]
	local text = if pack then pack[key] else nil
	if text then
		return text
	end
	return STR.en[key] or key
end

local function tf(key: string, ...: any): string
	return string.format(t(key), ...)
end

local function set(lang: string)
	if lang == "en" or lang == "zh" then
		tern.kv.set("lang", lang)
	end
end

local function toggle(): string
	local next_lang = if detect() == "zh" then "en" else "zh"
	set(next_lang)
	return next_lang
end

return {
	t = t,
	tf = tf,
	lang = detect,
	set = set,
	toggle = toggle,
}
