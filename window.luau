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
			if mode == "new" then
				cx.layout:focus(pane.pane)
				cx.session:event(pane.pane, { ev = "action", act = "compose" })
			elseif mode == "pull" then
				cx.layout:focus(pane.pane)
				cx.session:event(pane.pane, { ev = "action", act = "pulls" })
			elseif pane.focused then
				cx.layout:close(pane.pane)
			else
				cx.layout:focus(pane.pane)
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

-- `#` 固定在标题栏右上角，紧挨 tab bar 右侧那排按钮的左边。
-- Stencil 把 footer 的子元素裁在 footer 自己的框里。只写 position:fixed 时，
-- 布局在 y=6，但画不出来。把 footer 拉成全窗透明层，行仍贴底，# 才能画在标题栏上。
-- z-index 31 比 #tabbar 的 30 高一层，避免被标题栏盖住。right: 224px 让 28px 的盒子落在工具按钮左边。
tern.chrome.status(function(_pane)
	return {
		{
			text = " ",
			icon = "hash",
			command = "plugin.tracker.open",
		},
	}
end)

tern.css("toolbar", [[
footer#widgetbar {
	z-index: 31 !important;
	top: 0 !important;
	height: 100% !important;
	background: transparent !important;
	align-items: flex-end !important;
}
#widgetbar .wg-seg[data-plugin="tracker"] {
	position: fixed;
	pointer-events: auto;
	top: 6px;
	right: 224px;
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
	border-radius: 8px;
	color: var(--t2, currentColor);
	background: transparent;
}
#widgetbar .wg-seg[data-plugin="tracker"] .wg-status-text {
	display: none;
}
#widgetbar .wg-seg[data-plugin="tracker"] svg.ico {
	width: 15px;
	height: 15px;
	flex: none;
}
#widgetbar .wg-seg[data-plugin="tracker"]:hover {
	background: var(--l2, rgba(128, 128, 128, 0.16));
	color: var(--t1, currentColor);
}
]])
