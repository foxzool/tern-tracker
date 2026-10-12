--!strict
-- 从当前聚焦 pane 的目录打开 issue 列表。

local KIND = "gh-issues.list"

local function project_cwd(cx: WindowCx): string?
	local id = cx.session:focused()
	if not id then
		return nil
	end
	local pane = cx.session:pane(id)
	if pane and type(pane.cwd) == "string" and pane.cwd ~= "" then
		return pane.cwd
	end
	return nil
end

local function open_issues(cx: WindowCx, compose: boolean?)
	local cwd = project_cwd(cx)
	if not cwd then
		cx:toast("error", "没有当前项目", "先聚焦一个位于项目目录的 pane。")
		return
	end
	local args = { cwd }
	if compose then
		table.insert(args, "new")
	end
	for _, pane in cx.session:panes() do
		local title = pane.title
		if pane.cwd == cwd and type(title) == "string" and string.sub(title, 1, 6) == "Issues" then
			cx.layout:focus(pane.pane)
			if compose then
				cx.session:event(pane.pane, { ev = "action", act = "compose" })
			end
			return
		end
	end
	local focused = cx.session:focused()
	if focused then
		local opened = cx.layout:split(focused, "right", {
			block = KIND,
			args = args,
			cwd = cwd,
		})
		if opened then
			return
		end
	end
	if cx:new_block(KIND, args, "beside") == nil then
		cx:toast("error", "GitHub Issues 未在此 host 加载", "在运行 pane 的机器上安装这个插件。")
	end
end

tern.command({
	id = "open",
	title = "查看当前项目的 Issues",
	icon = "list",
	keys = { "alt+shift+cmd+i" },
	run = function(cx)
		open_issues(cx, false)
	end,
})

tern.command({
	id = "create",
	title = "新建当前项目的 Issue",
	icon = "plus",
	run = function(cx)
		open_issues(cx, true)
	end,
})

-- 右上角图标。Tern 没有工具栏按钮 API，可点击的 chrome 只有状态栏分段。
-- 分段本身在状态栏里，CSS 把它固定到标题栏右侧，点它打开 issue 列表。
tern.chrome.status(function(_pane)
	return {
		{
			text = "Issues",
			icon = "hash",
			command = "plugin.gh-issues.open",
		},
	}
end)

tern.on("window_start", function(cx)
	if cx.settings:get("status_bar") ~= true then
		cx.settings:set("status_bar", true)
	end
end)
tern.timer(0, function(cx)
	if cx and cx.settings:get("status_bar") ~= true then
		cx.settings:set("status_bar", true)
	end
end)

tern.css("toolbar", [[
#statusline .sl-plugin[data-plugin="gh-issues"] {
	position: fixed;
	top: 6px;
	right: 200px;
	z-index: 40;
	width: 28px;
	height: 28px;
	margin: 0;
	padding: 0;
	display: inline-flex;
	align-items: center;
	justify-content: center;
	border-radius: 6px;
	font-size: 0;
	line-height: 0;
	color: var(--t2, currentColor);
	background: transparent;
}
#statusline .sl-plugin[data-plugin="gh-issues"] svg {
	width: 15px;
	height: 15px;
}
#statusline .sl-plugin[data-plugin="gh-issues"]:hover {
	background: var(--l2, rgba(128, 128, 128, 0.16));
	color: var(--t1, currentColor);
}
]])
