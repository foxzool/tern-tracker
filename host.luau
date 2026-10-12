--!strict
-- 当前项目的 Tracker。现在只接 GitHub issue。
-- 目录来自启动参数，否则用 block 自己的 cwd。
-- `gh repo view` 识别 owner/repo，`gh issue list` 拉列表。
--
-- 列表：↑↓ 或 k/j 移动，⏎ 或 o 看正文，b 浏览器，y 复制，r 刷新，s 切换状态。
-- 正文：esc 返回，b 或 ⏎ 浏览器，y 复制，r 重载。

local ui = tern.ui
local i18n = require("./i18n")
local cache = require("./cache")
local t = i18n.t
local tf = i18n.tf

local POLL_MS = 2 * 60 * 1000
local GH_TIMEOUT_MS = 30 * 1000
local INSTALL_URL = "https://cli.github.com"
local LIST_LIMIT = 100
local COMMENT_LIMIT = 30
local LIST_ID = "main.queue."

local LIST_FIELDS = "number,title,url,author,createdAt,updatedAt,labels,state"
local VIEW_FIELDS = "number,title,body,url,author,state,labels,comments,createdAt,updatedAt"

local GH = {
	"gh",
	"/opt/homebrew/bin/gh",
	"/usr/local/bin/gh",
	"/home/linuxbrew/.linuxbrew/bin/gh",
	"/usr/bin/gh",
}

local GH_ENV = {
	GH_PROMPT_DISABLED = "1",
	GH_NO_UPDATE_NOTIFIER = "1",
	NO_COLOR = "1",
}

type Issue = {
	key: string,
	number: number,
	title: string,
	url: string,
	author: string,
	created: number,
	updated: number,
	state: string,
	labels: { string },
}

type Comment = {
	author: string,
	body: string,
	created: number,
}

type Detail = {
	number: number,
	title: string,
	body: string,
	url: string,
	author: string,
	state: string,
	created: number,
	updated: number,
	labels: { string },
	comments: { Comment },
}

type Problem = { kind: string, text: string, detail: string?, key: string? }

type State = {
	cx: BlockCx,
	cwd: string?,
	repo: string?,
	repo_url: string?,
	repo_ok: boolean,
	confirm_gen: number,
	issues: { Issue }?,
	shown: { Issue },
	cursor: string?,
	kind: string,
	filter: string,
	loading: boolean,
	fetched: number?,
	problem: Problem?,
	timer: TimerHandle?,
	gen: number,
	viewing: number?,
	detail: Detail?,
	detail_problem: Problem?,
	composing: boolean,
	draft_title: string,
	draft_body: string,
	draft_field: string,
	focus_field: string?,
	creating: boolean,
	create_problem: Problem?,
	want_compose: boolean,
}
local running: { [number]: State } = {}

local FILTER_NEXT = { open = "closed", closed = "all", all = "open" }
local PULL_FILTER_NEXT = { open = "merged", merged = "closed", closed = "all", all = "open" }

local function filter_allowed(kind: string, filter: string): boolean
	if filter == "open" or filter == "closed" or filter == "all" then
		return true
	end
	return kind == "pull" and filter == "merged"
end

local function filters_of(kind: string): { string }
	if kind == "pull" then
		return { "open", "merged", "closed", "all" }
	end
	return { "open", "closed", "all" }
end

local function gh_noun(kind: string): string
	return if kind == "pull" then "pr" else "issue"
end

local function filter_word(id: string): string
	return t("filter_" .. id)
end

local function problem_text(problem: Problem): string
	if problem.key then
		return t(problem.key)
	end
	return problem.text
end

local function retire(state: State)
	if running[state.cx.pane] == state then
		running[state.cx.pane] = nil
	end
	if state.timer then
		state.timer:cancel()
		state.timer = nil
	end
	state.loading = false
	state.issues = nil
	state.shown = {}
	state.cursor = nil
	state.problem = nil
	state.fetched = nil
	state.viewing = nil
	state.detail = nil
	state.detail_problem = nil
	state.composing = false
	state.draft_title = ""
	state.draft_body = ""
	state.creating = false
	state.create_problem = nil
	state.want_compose = false
	state.repo_ok = false
	state.focus_field = nil
end

local function alive(state: State): boolean
	if running[state.cx.pane] ~= state then
		return false
	end
	for _, pane in tern.pane.list() do
		if pane.pane == state.cx.pane then
			return true
		end
	end
	retire(state)
	return false
end

local function epoch(iso: string): number?
	local y, m, d, hh, mm, ss = string.match(iso, "^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
	if not (y and m and d and hh and mm and ss) then
		return nil
	end
	local year, month, day = tonumber(y) :: number, tonumber(m) :: number, tonumber(d) :: number
	if month <= 2 then
		year -= 1
	end
	local era = year // 400
	local yoe = year - era * 400
	local doy = (153 * (if month > 2 then month - 3 else month + 9) + 2) // 5 + day - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	local days = era * 146097 + doe - 719468
	return days * 86400 + (tonumber(hh) :: number) * 3600 + (tonumber(mm) :: number) * 60 + (tonumber(ss) :: number)
end

local function age(timestamp: number): string
	local s = math.max(0, os.time() - timestamp)
	if s < 60 then
		return t("age_now")
	elseif s < 3600 then
		return tf("age_min", s // 60)
	elseif s < 86400 then
		return tf("age_hour", s // 3600)
	end
	return tf("age_day", s // 86400)
end

local function first_lines(text: string, n: number): string
	local out = {}
	for line in string.gmatch(text, "[^\n]+") do
		table.insert(out, line)
		if #out == n then
			break
		end
	end
	return table.concat(out, "\n")
end

local function clamp(n: number, lo: number, hi: number): number
	if n < lo then
		return lo
	end
	if n > hi then
		return hi
	end
	return n
end

local function basename(path: string): string
	return string.match(path, "([^/]+)$") or path
end

local function labels_of(raw: any): { string }
	local names: { string } = {}
	if type(raw) ~= "table" then
		return names
	end
	for _, lab in raw do
		if type(lab) == "table" and type(lab.name) == "string" and lab.name ~= "" then
			table.insert(names, lab.name)
		end
	end
	return names
end

local function author_of(raw: any): string
	if type(raw) == "table" and type(raw.login) == "string" and raw.login ~= "" then
		return raw.login
	end
	return "?"
end

local function repo_flag(name: string, url: string?): string
	if not url then
		return name
	end
	local host = string.match(url, "^https?://([^/]+)/")
	if host and host ~= "github.com" and host ~= "www.github.com" then
		return host .. "/" .. name
	end
	return name
end

local function parse_repo(stdout: string): (string?, string?)
	local ok, data = pcall(tern.json.decode, stdout)
	if not ok or type(data) ~= "table" then
		return nil, nil
	end
	if type(data.nameWithOwner) ~= "string" or data.nameWithOwner == "" then
		return nil, nil
	end
	local url = if type(data.url) == "string" then data.url else nil
	return data.nameWithOwner, url
end

local function parse_issues(stdout: string): { Issue }?
	local ok, data = pcall(tern.json.decode, stdout)
	if not ok or type(data) ~= "table" then
		return nil
	end
	if data[1] == nil and next(data) ~= nil then
		return nil
	end
	local issues: { Issue } = {}
	for _, item in data do
		if type(item) == "table" then
			local number = tonumber(item.number)
			if number and type(item.url) == "string" then
				local created = epoch(tostring(item.createdAt or "")) or os.time()
				local updated = epoch(tostring(item.updatedAt or "")) or created
				table.insert(issues, {
					key = tostring(number),
					number = number,
					title = tostring(item.title or ""),
					url = item.url,
					author = author_of(item.author),
					created = created,
					updated = updated,
					state = tostring(item.state or "OPEN"),
					labels = labels_of(item.labels),
				})
			end
		end
	end
	return issues
end

local function parse_detail(stdout: string): Detail?
	local ok, data = pcall(tern.json.decode, stdout)
	if not ok or type(data) ~= "table" or type(data.url) ~= "string" then
		return nil
	end
	local number = tonumber(data.number)
	if not number then
		return nil
	end
	local comments: { Comment } = {}
	if type(data.comments) == "table" then
		for _, item in data.comments do
			if type(item) == "table" then
				table.insert(comments, {
					author = author_of(item.author),
					body = tostring(item.body or ""),
					created = epoch(tostring(item.createdAt or "")) or os.time(),
				})
			end
		end
	end
	local created = epoch(tostring(data.createdAt or "")) or os.time()
	return {
		number = number,
		title = tostring(data.title or ""),
		body = if type(data.body) == "string" then data.body else "",
		url = data.url,
		author = author_of(data.author),
		state = tostring(data.state or "OPEN"),
		created = created,
		updated = epoch(tostring(data.updatedAt or "")) or created,
		labels = labels_of(data.labels),
		comments = comments,
	}
end

local function auth_error(result: ProcessResult): boolean
	local err = result.stderr
	return result.status == 4
		or string.find(err, "gh auth login", 1, true) ~= nil
		or string.find(err, "GH_TOKEN", 1, true) ~= nil
		or string.find(err, "HTTP 401", 1, true) ~= nil
end

local function problem_of(result: ProcessResult, fallback_key: string): Problem
	if result.timed_out then
		return { kind = "failed", text = "", key = "gh_timeout" }
	end
	if auth_error(result) then
		return { kind = "auth", text = "", key = "gh_auth", detail = first_lines(result.stderr, 3) }
	end
	local err = result.stderr
	if string.find(err, "not a git repository", 1, true) then
		return { kind = "norepo", text = "", key = "not_git", detail = first_lines(err, 3) }
	end
	if string.find(err, "no git remotes", 1, true) or string.find(err, "known GitHub host", 1, true) then
		return { kind = "notgithub", text = "", key = "not_github", detail = first_lines(err, 4) }
	end
	return {
		kind = "failed",
		text = "",
		key = fallback_key,
		detail = first_lines(if err ~= "" then err else result.stdout, 8),
	}
end

local function run_gh(args: { string }, cwd: string?, done: (ProcessResult) -> ()): string?
	local last = t("gh_missing")
	for _, gh in GH do
		if gh == "gh" or tern.fs.exists(gh) then
			local argv: { string } = { gh }
			for _, arg in args do
				table.insert(argv, arg)
			end
			local opts: ProcessOptions = {
				cwd = cwd,
				timeout_ms = GH_TIMEOUT_MS,
				env = GH_ENV,
			}
			local ok, err = pcall(function()
				tern.process.run(argv, opts, function(result: ProcessResult, _)
					done(result)
				end)
			end)
			if ok then
				return nil
			end
			last = tostring(err)
		end
	end
	return last
end

local function resort(state: State)
	local shown = state.issues or {}
	table.sort(shown, function(a, b)
		if a.updated ~= b.updated then
			return a.updated > b.updated
		end
		return a.number > b.number
	end)
	state.shown = shown
	local found = false
	for _, issue in shown do
		found = found or issue.key == state.cursor
	end
	if not found then
		state.cursor = if shown[1] then shown[1].key else nil
	end
end

local function index_of(state: State): number
	for i, issue in state.shown do
		if issue.key == state.cursor then
			return i
		end
	end
	return 0
end

local function selected(state: State): Issue?
	return state.shown[index_of(state)]
end

local refresh: (State) -> ()
local poll: (State) -> ()
local load_detail: (State, number) -> ()

local function apply_list_cache(state: State)
	if not state.repo then
		return
	end
	local hit = cache.list_get(state.repo, state.kind, state.filter)
	if not hit then
		return
	end
	state.issues = hit.issues
	state.fetched = hit.at
	state.problem = nil
	resort(state)
end

local function resolve(state: State)
	if not alive(state) or state.loading then
		return
	end
	local cwd = state.cwd
	if not cwd or cwd == "" then
		state.problem = {
			kind = "norepo",
			text = "",
			key = "no_cwd",
			detail = "",
		}
		return
	end
	local known = cache.repo_get(cwd)
	state.repo_ok = false
	state.confirm_gen += 1
	local confirm_gen = state.confirm_gen
	if known then
		-- 缓存只用于展示。确认完成前不能拿这个 slug 去创建。
		state.repo = known.repo
		state.repo_url = known.url
		apply_list_cache(state)
	else
		state.loading = true
	end
	local spawn_error = run_gh({ "repo", "view", "--json", "nameWithOwner,url" }, cwd, function(result)
		if not alive(state) or state.confirm_gen ~= confirm_gen then
			return
		end
		state.loading = false
		if result.status == 0 then
			local name, url = parse_repo(result.stdout)
			if name then
				local repo = repo_flag(name, url)
				local changed = state.repo ~= nil and state.repo ~= repo
				state.repo = repo
				state.repo_url = url
				state.repo_ok = true
				cache.repo_put(cwd, repo, url)
				state.problem = nil
				state.loading = false
				if state.want_compose then
					state.want_compose = false
					state.composing = true
					state.draft_title = ""
					state.draft_body = ""
					state.draft_field = "title"
					state.focus_field = "title"
					state.creating = false
					state.create_problem = nil
					state.viewing = nil
				end
				if changed then
					state.gen += 1
					state.loading = false
					state.issues = nil
					state.shown = {}
					state.cursor = nil
					state.viewing = nil
					state.detail = nil
					state.detail_problem = nil
					apply_list_cache(state)
				elseif state.viewing then
					load_detail(state, state.viewing)
				end
				refresh(state)
				poll(state)
				state.cx:render()
				return
			end
			state.problem = {
				kind = "failed",
				text = "",
				key = "gh_no_name",
				detail = first_lines(result.stdout, 4),
			}
		else
			state.problem = problem_of(result, "cannot_identify")
			if state.problem.kind == "norepo" then
				state.problem.detail = cwd
			end
		end
		state.cx:render()
	end)
	if spawn_error then
		state.loading = false
		state.problem = { kind = "missing", text = "", key = "cannot_start_gh", detail = spawn_error }
	end
end

refresh = function(state: State)
	if not alive(state) or state.loading or not state.repo or not state.repo_ok then
		return
	end
	state.loading = true
	local gen = state.gen
	local kind = state.kind
	local repo = state.repo :: string
	local filter = state.filter
	local spawn_error = run_gh({
		gh_noun(kind),
		"list",
		"--repo",
		repo,
		"--state",
		filter,
		"--limit",
		tostring(LIST_LIMIT),
		"--json",
		LIST_FIELDS,
	}, state.cwd, function(result)
		local parsed = if result.status == 0 then parse_issues(result.stdout) else nil
		if parsed then
			cache.list_put(repo, kind, filter, parsed)
		end
		if not alive(state) or state.gen ~= gen or state.kind ~= kind then
			return
		end
		state.loading = false
		if result.status ~= 0 then
			state.problem = problem_of(result, "cannot_load")
		elseif parsed then
			state.issues = parsed
			state.problem = nil
			state.fetched = os.time()
			resort(state)
		else
			state.problem = {
				kind = "failed",
				text = "",
				key = "not_a_list",
				detail = first_lines(result.stdout, 4),
			}
		end
		state.cx:render()
	end)
	if spawn_error then
		state.loading = false
		state.problem = { kind = "missing", text = "", key = "cannot_start_gh", detail = spawn_error }
	end
end

poll = function(state: State)
	if not alive(state) or state.timer then
		return
	end
	state.timer = tern.timer(POLL_MS, function()
		if not alive(state) then
			return
		end
		state.timer = nil
		refresh(state)
		poll(state)
	end)
end

load_detail = function(state: State, number: number)
	if not state.repo then
		return
	end
	local repo = state.repo :: string
	local kind = state.kind
	local cached = cache.detail_get(repo, kind, number)
	if not state.repo_ok then
		if not cached then
			state.cx:toast("info", t("repo_unconfirmed"))
			return
		end
		state.viewing = number
		state.detail = cached.detail
		state.detail_problem = nil
		return
	end
	local gen = state.gen
	state.viewing = number
	state.detail_problem = nil
	state.detail = if cached then cached.detail else nil
	local spawn_error = run_gh({
		gh_noun(kind),
		"view",
		tostring(number),
		"--repo",
		repo,
		"--json",
		VIEW_FIELDS,
	}, state.cwd, function(result)
		local detail = if result.status == 0 then parse_detail(result.stdout) else nil
		if detail then
			cache.detail_put(repo, kind, number, detail)
		end
		if not alive(state) or state.gen ~= gen or state.kind ~= kind or state.viewing ~= number then
			return
		end
		if result.status ~= 0 then
			state.detail_problem = problem_of(result, "cannot_load_one")
		elseif detail then
			state.detail = detail
			state.detail_problem = nil
		else
			state.detail_problem = {
				kind = "failed",
				text = "",
				key = "not_one_issue",
				detail = first_lines(result.stdout, 4),
			}
		end
		state.cx:render()
	end)
	if spawn_error then
		state.detail_problem = { kind = "missing", text = "", key = "cannot_start_gh", detail = spawn_error }
	end
end

local function button(label: string, act: string, tone: string): Node
	local node = ui.badge(label, tone)
	local props: { [string]: any } = node.p or {}
	props.actions = { click = act }
	node.p = props
	return node
end

local function problem_view(problem: Problem, cwd: string?): Node
	local heads = {
		missing = t("head_missing"),
		auth = t("head_auth"),
		norepo = t("head_norepo"),
		notgithub = t("head_notgithub"),
		failed = t("head_failed"),
	}
	local help = {
		missing = t("help_missing"),
		auth = t("help_auth"),
		norepo = t("help_norepo"),
		notgithub = t("help_notgithub"),
		failed = t("help_failed"),
	}
	local children: { Node } = { ui.md((help[problem.kind] or "") .. "\n\n" .. problem_text(problem)) }
	local where = problem.detail
	if problem.key == "no_cwd" then
		where = t("no_cwd_detail")
	end
	if (not where or where == "") and cwd then
		where = cwd
	end
	if where and where ~= "" then
		table.insert(children, ui.code(where))
	end
	local buttons: { Node } = { button(t("retry"), "retry", "accent") }
	if problem.kind == "missing" then
		table.insert(buttons, button(t("install"), "install", "neutral"))
	end
	table.insert(children, ui.row(buttons))
	local card = ui.card(heads[problem.kind] or "Tracker", children)
	local props: { [string]: any } = card.p or {}
	props.tone = "error"
	card.p = props
	return card
end

local function list_lines(cx: BlockCx): number
	return math.max(4, math.floor((cx.rows - 6) * 0.72))
end

local function filter_row(state: State): Node
	local badges: { Node } = {}
	for _, id in { "issue", "pull" } do
		local tone = if id == state.kind then "accent" else "neutral"
		local node = ui.badge(t("kind_" .. id), tone)
		local props: { [string]: any } = node.p or {}
		props.actions = { click = "kind=" .. id }
		props.key = "kind-" .. id
		node.p = props
		table.insert(badges, node)
	end
	for _, id in filters_of(state.kind) do
		local tone = if id == state.filter then "accent" else "neutral"
		local node = ui.badge(filter_word(id), tone)
		local props: { [string]: any } = node.p or {}
		props.actions = { click = "filter=" .. id }
		props.key = id
		node.p = props
		table.insert(badges, node)
	end
	if state.repo then
		local repo = state.repo :: string
		local section = if state.kind == "pull" then "/pulls" else "/issues"
		local href = if state.repo_url then state.repo_url .. section else "https://github.com/" .. repo .. section
		table.insert(badges, ui.text({ ui.link(repo, href, "muted") }))
	end
	return ui.row(badges)
end

local function list_view(state: State): Node
	local items: { Item } = {}
	for _, issue in state.shown do
		local label: { Span } = {
			ui.span("#" .. issue.number .. "  ", "muted num"),
			ui.span(issue.title),
		}
		local value: { Span } = {
			ui.span("@" .. issue.author .. "  ", "muted"),
			ui.span(age(issue.updated), "muted"),
		}
		local detail: { Span } = {}
		for i, name in issue.labels do
			if i > 3 then
				table.insert(detail, ui.span(" +" .. (#issue.labels - 3), "muted"))
				break
			end
			if i > 1 then
				table.insert(detail, ui.span(" "))
			end
			table.insert(detail, ui.span(name, "code"))
		end
		table.insert(items, {
			label = label,
			detail = if #detail > 0 then detail else nil,
			value = value,
			icon = if issue.state == "CLOSED" or issue.state == "MERGED" then "check" else "hash",
			tone = if issue.state == "CLOSED" or issue.state == "MERGED" then "muted" else nil,
		})
	end
	local list = ui.list(items)
	local kids = list.c or {}
	for i, issue in state.shown do
		local props: { [string]: any } = kids[i].p or {}
		props.key = issue.key
		kids[i].p = props
	end
	local empty_key = if state.kind == "pull"
		then if state.filter == "merged"
			then "empty_merged"
			elseif state.filter == "closed" then "empty_closed_pull"
			elseif state.filter == "all" then "empty_all_pull"
			else "empty_open_pull"
		elseif state.filter == "closed" then "empty_closed"
		elseif state.filter == "all" then "empty_all"
		else "empty_open"
	local empty = t(empty_key)
	local props: { [string]: any } = list.p or {}
	props.key = "queue"
	props.selected = if state.cursor then LIST_ID .. state.cursor else nil
	props.empty = { ui.span(empty, "muted") }
	props.max = { lines = list_lines(state.cx) }
	list.p = props
	return list
end

local function dock_view(state: State): Node
	if state.viewing then
		return ui.col({
			ui.text({
				ui.span(t("dock_detail"), "dim"),
			}),
		})
	end
	local status: { Span } = {}
	if state.issues then
		local count_key = if state.filter == "merged"
			then "count_merged"
			elseif state.filter == "closed" then "count_closed"
			elseif state.filter == "all" then "count_all"
			else "count_open"
		table.insert(status, ui.span(tf(count_key, #state.shown), "strong"))
		if #state.shown == LIST_LIMIT then
			table.insert(status, ui.span(tf("limit_note", LIST_LIMIT), "muted"))
		end
	end
	if state.loading then
		table.insert(status, ui.span(t("refreshing"), "muted"))
	elseif state.fetched then
		table.insert(status, ui.span(tf("updated_at", os.date("%H:%M", state.fetched)), "muted"))
	end
	local lines: { Node } = {}
	if #status > 0 then
		table.insert(lines, ui.text(status))
	end
	local problem = state.problem
	if problem and state.issues then
		table.insert(lines, ui.text({ ui.span(problem_text(problem), "warning"), ui.span(t("showing_last"), "muted") }))
	end
	table.insert(lines, ui.text({ ui.span(t("dock_list"), "dim") }))
	return ui.col({ ui.lines(lines) })
end

local function detail_view(state: State): Node
	local detail = state.detail
	if not detail then
		if state.detail_problem then
			return problem_view(state.detail_problem, state.cwd)
		end
		return ui.progress(nil, tf("loading_one", tostring(state.viewing)))
	end
	local merged = detail.state == "MERGED"
	local closed = detail.state == "CLOSED" or merged
	local head: { Span } = {
		ui.span("#" .. detail.number .. "  ", "muted num"),
		ui.span(detail.title, "strong"),
	}
	local badges: { Node } = {
		ui.badge(
			if merged then t("badge_merged") elseif closed then t("badge_closed") else t("badge_open"),
			if merged then "accent" elseif closed then "muted" else "success"
		),
	}
	for i, name in detail.labels do
		if i > 6 then
			break
		end
		table.insert(badges, ui.badge(name, "neutral"))
	end
	local children: { Node } = {
		ui.row(badges),
		ui.kv({
			{ t("author"), "@" .. detail.author },
			{ t("updated"), age(detail.updated) },
			{ t("comments"), tostring(#detail.comments) },
		}),
	}
	if detail.body ~= "" then
		table.insert(children, ui.md(detail.body))
	else
		table.insert(children, ui.text({ ui.span(t("no_body"), "muted") }))
	end
	local shown = math.min(#detail.comments, COMMENT_LIMIT)
	if shown > 0 then
		local notes: { Node } = {}
		for i = 1, shown do
			local comment = detail.comments[i]
			table.insert(notes, ui.text({
				ui.span("@" .. comment.author .. "  ", "strong"),
				ui.span(age(comment.created), "muted"),
			}))
			if comment.body ~= "" then
				table.insert(notes, ui.md(comment.body))
			end
		end
		if #detail.comments > shown then
			table.insert(notes, ui.text({ ui.span(tf("more_comments", #detail.comments - shown), "muted") }))
		end
		local section = ui.section(t("comments_section"), notes)
		local props: { [string]: any } = section.p or {}
		props.collapsible = true
		section.p = props
		table.insert(children, section)
	end
	table.insert(children, ui.row({
		button(t("open_browser"), "browser", "accent"),
		button(t("copy_link"), "copy", "neutral"),
		button(t("back"), "back", "neutral"),
	}))
	return ui.card(head, children)
end

local function list_main(state: State): Node
	return ui.col({ filter_row(state), list_view(state) })
end

local function open_url(cx: BlockCx, url: string?)
	if url then
		cx:open(url)
	end
end

local function copy_url(cx: BlockCx, url: string?)
	if url then
		cx:copy(url)
		cx:toast("info", t("copied"))
	end
end

local function current_url(state: State): string?
	if state.detail and state.viewing == state.detail.number then
		return state.detail.url
	end
	local issue = selected(state)
	if issue then
		return issue.url
	end
	return nil
end

local function move(state: State, to: number)
	local issue = state.shown[clamp(to, 1, math.max(1, #state.shown))]
	if issue then
		state.cursor = issue.key
	end
end

local function set_filter(state: State, filter: string)
	if not filter_allowed(state.kind, filter) or filter == state.filter then
		return
	end
	state.filter = filter
	-- 仓库还没确认时，s 只切换已缓存的列表，不递增 confirm_gen，也不发请求。
	if not state.repo_ok then
		state.issues = nil
		state.shown = {}
		state.cursor = nil
		state.problem = nil
		apply_list_cache(state)
		return
	end
	state.gen += 1
	state.loading = false
	state.issues = nil
	state.shown = {}
	state.cursor = nil
	state.problem = nil
	apply_list_cache(state)
	refresh(state)
end

local function set_kind(state: State, kind: string)
	if kind ~= "issue" and kind ~= "pull" then
		return
	end
	if state.kind == kind then
		return
	end
	state.kind = kind
	if not filter_allowed(kind, state.filter) then
		state.filter = "open"
	end
	state.gen += 1
	state.loading = false
	state.issues = nil
	state.shown = {}
	state.cursor = nil
	state.viewing = nil
	state.detail = nil
	state.detail_problem = nil
	state.composing = false
	state.problem = nil
	apply_list_cache(state)
	if state.repo_ok then
		refresh(state)
	end
	state.cx:render()
end

local function retry(state: State)
	state.gen += 1
	state.loading = false
	state.problem = nil
	if state.repo_ok then
		refresh(state)
	else
		resolve(state)
	end
end

local function utf16_len(s: string): number
	local n = 0
	for _, cp in utf8.codes(s) do
		n += if cp > 0xFFFF then 2 else 1
	end
	return n
end

local function pop_char(s: string): string
	if s == "" then
		return s
	end
	local at = utf8.offset(s, -1)
	if not at or at <= 1 then
		return ""
	end
	return string.sub(s, 1, at - 1)
end

local function begin_compose(state: State)
	if state.creating or not state.repo_ok then
		return
	end
	if state.kind ~= "issue" then
		set_kind(state, "issue")
	end
	state.composing = true
	state.viewing = nil
	state.detail = nil
	state.detail_problem = nil
	state.draft_title = ""
	state.draft_body = ""
	state.draft_field = "title"
	state.focus_field = "title"
	state.creating = false
	state.create_problem = nil
	state.cx:render()
end
local function cancel_compose(state: State)
	if state.creating then
		return
	end
	state.composing = false
	state.creating = false
	state.create_problem = nil
	state.draft_title = ""
	state.draft_body = ""
	state.focus_field = nil
end

local function issue_number_from(stdout: string): number?
	local url = string.match(stdout, "https://%S+")
	if not url then
		return nil
	end
	local n = string.match(url, "/issues/(%d+)")
	return if n then tonumber(n) else nil
end

local function create_issue(state: State)
	if state.creating or not state.repo or not state.repo_ok then
		if not state.repo_ok then
			state.create_problem = { kind = "failed", text = "", key = "repo_unconfirmed" }
		end
		return
	end
	local title = string.gsub(state.draft_title, "^%s+", "")
	title = string.gsub(title, "%s+$", "")
	if title == "" then
		state.create_problem = { kind = "failed", text = "", key = "title_required" }
		return
	end
	state.creating = true
	state.create_problem = nil
	local gen = state.gen
	local repo = state.repo :: string
	local body = state.draft_body
	local spawn_error = run_gh({
		"issue",
		"create",
		"--repo",
		repo,
		"--title",
		title,
		"--body",
		body,
	}, state.cwd, function(result)
		if not alive(state) or state.gen ~= gen or not state.composing then
			return
		end
		state.creating = false
		if result.status ~= 0 then
			state.create_problem = problem_of(result, "cannot_create")
			state.cx:render()
			return
		end
		local number = issue_number_from(result.stdout)
		cancel_compose(state)
		if state.filter == "closed" then
			state.filter = "open"
			state.issues = nil
			state.shown = {}
			state.cursor = nil
		end
		state.gen += 1
		state.loading = false
		refresh(state)
		if number then
			load_detail(state, number)
			state.cx:toast("info", tf("created_num", tostring(number)))
		else
			state.cx:toast("info", t("created"))
		end
		state.cx:render()
	end)
	if spawn_error then
		state.creating = false
		state.create_problem = { kind = "missing", text = "", key = "cannot_start_gh", detail = spawn_error }
	end
end

local function compose_view(state: State, cx: BlockCx): Node
	if state.focus_field then
		local id = "main." .. state.focus_field
		state.focus_field = nil
		cx:frame({ { "focus", id } })
	end
	local title = ui.node("input", {
		key = "title",
		text = state.draft_title,
		cursor = utf16_len(state.draft_title),
		placeholder = t("title_ph"),
	})
	local body = ui.node("editor", {
		key = "body",
		text = state.draft_body,
		cursor = utf16_len(state.draft_body),
		placeholder = t("body_ph"),
		maxLines = 10,
	})
	local children: { Node } = {
		ui.text({
			ui.span(t("new_issue"), "strong"),
			ui.span("  " .. (state.repo or ""), "muted"),
		}),
		title,
		body,
	}
	local problem = state.create_problem
	if problem then
		table.insert(children, ui.text({ ui.span(problem_text(problem), "error") }))
		if problem.detail and problem.detail ~= "" then
			table.insert(children, ui.code(problem.detail))
		end
	end
	local submit = if state.creating then t("creating") else t("create")
	table.insert(children, ui.row({
		button(submit, "create", "accent"),
		button(t("cancel"), "cancel", "neutral"),
	}))
	return ui.col(children)
end

local function compose_key(state: State, key: Key, cx: BlockCx): boolean?
	if state.creating then
		return true
	end
	if (key.meta or key.ctrl) and key.name == "enter" then
		create_issue(state)
		return true
	end
	if key.ctrl or key.alt or key.meta then
		return false
	end
	if key.name == "escape" then
		cancel_compose(state)
		return true
	end
	if key.name == "tab" then
		state.draft_field = if state.draft_field == "title" then "body" else "title"
		state.focus_field = state.draft_field
		return true
	end
	local field = state.draft_field
	if key.name == "enter" then
		if field == "title" then
			state.draft_field = "body"
			state.focus_field = "body"
		else
			state.draft_body ..= "\n"
		end
		return true
	end
	if key.name == "backspace" then
		if field == "body" then
			state.draft_body = pop_char(state.draft_body)
		else
			state.draft_title = pop_char(state.draft_title)
		end
		return true
	end
	if key.text and key.text ~= "" then
		if field == "body" then
			state.draft_body ..= key.text
		else
			state.draft_title ..= key.text
		end
		return true
	end
	return false
end

local function retry_action(state: State)
	if state.viewing then
		load_detail(state, state.viewing)
		return
	end
	retry(state)
end


tern.block.define("list", {
	init = function(cx: BlockCx, args: { string }, saved: any): State
		local previous = running[cx.pane]
		if previous then
			retire(previous)
		end
		local cwd = if type(args[1]) == "string" and args[1] ~= "" then args[1] else cx.cwd
		local kind = "issue"
		if args[2] == "pull" then
			kind = "pull"
		elseif type(saved) == "table" and (saved.kind == "issue" or saved.kind == "pull") then
			kind = saved.kind
		end
		local filter = "open"
		if type(saved) == "table" and type(saved.filter) == "string" and filter_allowed(kind, saved.filter) then
			filter = saved.filter
		end
		local state: State = {
			cx = cx,
			cwd = cwd,
			repo = nil,
			repo_url = nil,
			issues = nil,
			shown = {},
			cursor = nil,
			kind = kind,
			filter = filter,
			loading = false,
			fetched = nil,
			problem = nil,
			timer = nil,
			gen = 1,
			viewing = nil,
			detail = nil,
			detail_problem = nil,
			composing = false,
			draft_title = "",
			draft_body = "",
			draft_field = "title",
			focus_field = nil,
			creating = false,
			create_problem = nil,
			want_compose = args[2] == "new",
			repo_ok = false,
			confirm_gen = 0,
		}
		running[cx.pane] = state
		resolve(state)
		return state
	end,

	title = function(state: State): string?
		if state.viewing then
			if state.detail then
				return "Tracker · #" .. state.detail.number
			end
			return "Tracker · #" .. state.viewing
		end
		if state.repo then
			if state.issues then
				return "Tracker · " .. state.repo .. " (" .. #state.shown .. ")"
			end
			return "Tracker · " .. state.repo
		end
		if state.cwd then
			return "Tracker · " .. basename(state.cwd)
		end
		return "Tracker"
	end,

	view = function(state: State, cx: BlockCx): BlockView
		if state.composing then
			return {
				main = compose_view(state, cx),
				dock = ui.col({ ui.text({ ui.span(t("compose_dock"), "dim") }) }),
			}
		end
		local dock = if state.issues or state.viewing or state.repo then dock_view(state) else nil
		-- 区域根节点本身不画。列表这一支直接用带 key=queue 的列当根，
		-- 行 id 才是 main.queue.<number>。再包一层列会变成 main.0.queue.<number>，
		-- selected 和点击事件都对不上。
		if state.issues and not state.viewing then
			return { main = list_main(state), dock = dock }
		end
		local main: Node
		if state.viewing then
			main = detail_view(state)
		elseif state.problem then
			main = problem_view(state.problem, state.cwd)
		else
			local where = if state.repo then state.repo elseif state.cwd then basename(state.cwd) else t("current_project")
			local word = filter_word(state.filter)
			local label = if state.repo
				then tf(if state.kind == "pull" then "loading_pulls" else "loading_issues", where, word)
				else tf("identifying", where, word)
			main = ui.progress(nil, label)
		end
		return { main = ui.col({ main }), dock = dock }
	end,

	key = function(state: State, key: Key, cx: BlockCx): boolean?
		if state.composing then
			return compose_key(state, key, cx)
		end
		if key.ctrl or key.alt or key.meta then
			return false
		end
		local name = key.text or key.name
		if state.viewing then
			if key.name == "escape" or key.name == "backspace" then
				state.viewing = nil
				state.detail = nil
				state.detail_problem = nil
			elseif name == "b" or name == "o" or key.name == "enter" then
				open_url(cx, current_url(state))
			elseif name == "y" then
				copy_url(cx, current_url(state))
			elseif name == "r" and state.viewing then
				load_detail(state, state.viewing)
			else
				return false
			end
			return true
		end
		local i = index_of(state)
		if key.name == "up" or name == "k" then
			move(state, i - 1)
		elseif key.name == "down" or name == "j" then
			move(state, i + 1)
		elseif key.name == "page_up" then
			move(state, i - 10)
		elseif key.name == "page_down" then
			move(state, i + 10)
		elseif key.name == "home" or name == "g" then
			move(state, 1)
		elseif key.name == "end" or name == "G" then
			move(state, #state.shown)
		elseif key.name == "enter" or name == "o" then
			local issue = selected(state)
			if issue then
				load_detail(state, issue.number)
			end
		elseif name == "b" then
			open_url(cx, current_url(state))
		elseif name == "y" then
			copy_url(cx, current_url(state))
		elseif name == "r" then
			retry(state)
		elseif name == "s" then
			local cycle = if state.kind == "pull" then PULL_FILTER_NEXT else FILTER_NEXT
			set_filter(state, cycle[state.filter] or "open")
		elseif name == "p" then
			set_kind(state, if state.kind == "pull" then "issue" else "pull")
		elseif name == "n" then
			if state.kind == "pull" then
				cx:toast("info", t("pull_no_create"))
			elseif not state.repo_ok then
				cx:toast("info", t("repo_unconfirmed"))
			elseif state.repo then
				begin_compose(state)
			end
		else
			return false
		end
		return true
	end,

	event = function(state: State, ev: UiEvent, cx: BlockCx)
		if ev.ev == "action" and ev.act == "retry" then
			retry_action(state)
		elseif ev.ev == "action" and ev.act == "create" then
			create_issue(state)
		elseif ev.ev == "action" and ev.act == "cancel" then
			cancel_compose(state)
		elseif ev.ev == "action" and ev.act == "compose" and state.repo then
			begin_compose(state)
		elseif ev.ev == "focus" and type(ev.id) == "string" and (ev.id == "main.title" or ev.id == "main.body") then
			state.draft_field = if ev.id == "main.title" then "title" else "body"
			cx:frame({ { "focus", ev.id } })
		elseif ev.ev == "action" and ev.act == "install" then
			cx:open(INSTALL_URL)
		elseif ev.ev == "action" and ev.act == "back" then
			state.viewing = nil
			state.detail = nil
			state.detail_problem = nil
		elseif ev.ev == "action" and ev.act == "browser" then
			open_url(cx, current_url(state))
		elseif ev.ev == "action" and ev.act == "copy" then
			copy_url(cx, current_url(state))
		elseif ev.ev == "action" and ev.act == "filter" and type(ev.value) == "string" then
			set_filter(state, ev.value)
		elseif ev.ev == "action" and ev.act == "kind" and type(ev.value) == "string" then
			set_kind(state, ev.value)
		elseif ev.ev == "action" and ev.act == "pulls" then
			set_kind(state, "pull")
		elseif (ev.ev == "select" or ev.ev == "activate") and type(ev.item) == "string" then
			if string.sub(ev.item, 1, #LIST_ID) == LIST_ID then
				state.cursor = string.sub(ev.item, #LIST_ID + 1)
				if ev.ev == "activate" then
					local issue = selected(state)
					if issue then
						load_detail(state, issue.number)
					end
				end
			end
		end
	end,

	save = function(state: State): any
		return { filter = state.filter, kind = state.kind }
	end,
})
