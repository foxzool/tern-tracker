--!strict
-- 仓库、列表和详情的磁盘缓存。打开 block 时先画出上次的结果，再后台刷新。

local PATH = tern.plugin.data .. "/issues-cache.json"
local MAX_DETAILS = 40

type RepoHit = { repo: string, url: string?, at: number }
type ListHit = { issues: { any }, at: number }
type DetailHit = { detail: any, at: number }

local repos: { [string]: RepoHit } = {}
local lists: { [string]: ListHit } = {}
local details: { [string]: DetailHit } = {}
local loaded = false

local function list_key(repo: string, filter: string): string
	return repo .. "|" .. filter
end

local function detail_key(repo: string, number: number): string
	return repo .. "#" .. tostring(number)
end

local function load()
	if loaded then
		return
	end
	loaded = true
	if not tern.fs.exists(PATH) then
		return
	end
	local ok, text = pcall(tern.fs.read, PATH)
	if not ok or type(text) ~= "string" or text == "" then
		return
	end
	local decoded, data = pcall(tern.json.decode, text)
	if not decoded or type(data) ~= "table" then
		return
	end
	if type(data.repos) == "table" then
		repos = data.repos
	end
	if type(data.lists) == "table" then
		lists = data.lists
	end
	if type(data.details) == "table" then
		details = data.details
	end
end

local function save()
	pcall(function()
		tern.fs.mkdir(tern.plugin.data)
		tern.fs.write(PATH, tern.json.encode({
			repos = repos,
			lists = lists,
			details = details,
		}))
	end)
end

local function trim_details()
	local keys: { string } = {}
	for key, _ in details do
		table.insert(keys, key)
	end
	if #keys <= MAX_DETAILS then
		return
	end
	table.sort(keys, function(a, b)
		local left = details[a]
		local right = details[b]
		local at_a = if type(left) == "table" and type(left.at) == "number" then left.at else 0
		local at_b = if type(right) == "table" and type(right.at) == "number" then right.at else 0
		return at_a < at_b
	end)
	local extra = #keys - MAX_DETAILS
	for i = 1, extra do
		details[keys[i]] = nil
	end
end

local function repo_get(cwd: string?): RepoHit?
	if not cwd or cwd == "" then
		return nil
	end
	load()
	local hit = repos[cwd]
	if type(hit) ~= "table" or type(hit.repo) ~= "string" or hit.repo == "" then
		return nil
	end
	return hit
end

local function repo_put(cwd: string, repo: string, url: string?)
	load()
	repos[cwd] = { repo = repo, url = url, at = os.time() }
	save()
end

local function list_get(repo: string, filter: string): ListHit?
	load()
	local hit = lists[list_key(repo, filter)]
	if type(hit) ~= "table" or type(hit.issues) ~= "table" then
		return nil
	end
	return hit
end

local function list_put(repo: string, filter: string, issues: { any })
	load()
	lists[list_key(repo, filter)] = { issues = issues, at = os.time() }
	save()
end

local function detail_get(repo: string, number: number): DetailHit?
	load()
	local hit = details[detail_key(repo, number)]
	if type(hit) ~= "table" or type(hit.detail) ~= "table" then
		return nil
	end
	return hit
end

local function detail_put(repo: string, number: number, detail: any)
	load()
	details[detail_key(repo, number)] = { detail = detail, at = os.time() }
	trim_details()
	save()
end

return {
	repo_get = repo_get,
	repo_put = repo_put,
	list_get = list_get,
	list_put = list_put,
	detail_get = detail_get,
	detail_put = detail_put,
}
