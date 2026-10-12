--!strict
-- 从当前聚焦 pane 的目录打开 Tracker。

local KIND = "tracker.list"
local TITLE = "Tracker"
local i18n = require("./i18n")

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

local function open_tracker(cx: WindowCx, mode: string?)
	local cwd = project_cwd(cx)
	if not cwd then
		cx:toast("error", i18n.t("no_project"), i18n.t("no_project_sub"))
		return
	end
	local args = { cwd }
	if mode == "new" or mode == "pull" then
		table.insert(args, mode)
	end
	for _, pane in cx.session:panes() do
		local title = pane.title
		if pane.cwd == cwd and type(title) == "string" and string.sub(title, 1, #TITLE) == TITLE then
			cx.layout:focus(pane.pane)
			if mode == "new" then
				cx.session:event(pane.pane, { ev = "action", act = "compose" })
			elseif mode == "pull" then
				cx.session:event(pane.pane, { ev = "action", act = "pulls" })
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
		cx:toast("error", i18n.t("not_loaded"), i18n.t("not_loaded_sub"))
	end
end

local function refresh_open_blocks(cx: WindowCx)
	for _, pane in cx.session:panes() do
		local title = pane.title
		if type(title) == "string" and string.sub(title, 1, #TITLE) == TITLE then
			cx.session:event(pane.pane, { ev = "action", act = "lang" })
		end
	end
end

local function register_commands()
	tern.command({
		id = "open",
		title = i18n.t("cmd_open"),
		icon = "list",
		keys = { "alt+shift+cmd+i" },
		run = function(cx)
			open_tracker(cx, nil)
		end,
	})
	tern.command({
		id = "pulls",
		title = i18n.t("cmd_pulls"),
		icon = "diff",
		run = function(cx)
			open_tracker(cx, "pull")
		end,
	})
	tern.command({
		id = "create",
		title = i18n.t("cmd_create"),
		icon = "plus",
		run = function(cx)
			open_tracker(cx, "new")
		end,
	})
	tern.command({
		id = "lang",
		title = i18n.t("cmd_lang"),
		icon = "globe",
		run = function(cx)
			i18n.toggle()
			register_commands()
			cx:toast("info", i18n.t("lang_switched"))
			refresh_open_blocks(cx)
		end,
	})
end

register_commands()

-- 右上角图标。Tern 没有工具栏按钮 API，可点击的 chrome 只有状态栏分段。
-- 分段本身在状态栏里，CSS 把它固定到标题栏右侧，点它打开 Tracker。
tern.chrome.status(function(_pane)
	return {
		{
			text = " ",
			icon = "hash",
			command = "plugin.tracker.open",
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
#statusline .sl-plugin[data-plugin="tracker"] {
	position: fixed;
	top: 6px;
	right: 200px;
	z-index: 40;
	width: 28px;
	height: 28px;
	margin: 0;
	padding: 0;
	gap: 0;
	overflow: hidden;
	display: inline-flex;
	align-items: center;
	justify-content: center;
	border-radius: 6px;
	font-size: 0;
	line-height: 0;
	color: var(--t2, currentColor);
	background: transparent;
}
#statusline .sl-plugin[data-plugin="tracker"] .ico {
	width: 15px;
	height: 15px;
	flex: none;
}
#statusline .sl-plugin[data-plugin="tracker"]:hover {
	background: var(--l2, rgba(128, 128, 128, 0.16));
	color: var(--t1, currentColor);
}
]])
