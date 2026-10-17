--[[
	SCP — Объект 19. Сюжетный кооперативный режим для Garry's Mod.
	shared.lua: метаданные и загрузчик ядра/модулей (sh_ / sv_ / cl_ по префиксу).
]]

DeriveGamemode("sandbox")

GM.Name = "SCP — Объект 19"
GM.Author = "SCP Site-19 Team"
GM.Website = ""
GM.Version = "0.1.0"

SCP = SCP or {}
SCP.Version = GM.Version
SCP.Root = GM.FolderName .. "/gamemode/"

-- Общие таблицы создаём заранее: файлы делают «local L = SCP.Lobby» при загрузке, порядок не важен.
for _, ns in ipairs({ "UI", "Config", "Points", "Lobby", "Menu", "Story", "Inv", "Items", "Stats", "Chat",
	"Voice", "Camera", "Stamina", "Phrases", "HUD", "Data" }) do
	SCP[ns] = SCP[ns] or {}
end

function SCP.Include(path, realm)
	local name = string.GetFileFromFilename(path)
	realm = realm
		or (string.StartWith(name, "sv_") and "server")
		or (string.StartWith(name, "cl_") and "client")
		or "shared"

	if realm == "server" then
		if SERVER then return include(path) end
	elseif realm == "client" then
		if SERVER then AddCSLuaFile(path) else return include(path) end
	else
		if SERVER then AddCSLuaFile(path) end
		return include(path)
	end
end

-- Все .lua в папке: sh_ → sv_ → cl_, внутри группы сначала first, потом по алфавиту.
function SCP.IncludeDir(dir, first)
	local base = SCP.Root .. dir .. "/"
	local files = file.Find(base .. "*.lua", "LUA")
	local rank = {}
	for i, f in ipairs(first or {}) do rank[f] = i end
	table.sort(files, function(a, b)
		local ra, rb = rank[a] or math.huge, rank[b] or math.huge
		if ra ~= rb then return ra < rb end
		return a < b
	end)
	for _, prefix in ipairs({ "sh_", "sv_", "cl_" }) do
		for _, f in ipairs(files) do
			if string.StartWith(f, prefix) then SCP.Include(base .. f) end
		end
	end
end

SCP.ModuleOrder = { "items", "lobby" }

function SCP.LoadModules()
	local _, dirs = file.Find(SCP.Root .. "modules/*", "LUA")
	local loaded = {}
	for _, dir in ipairs(SCP.ModuleOrder) do
		if table.HasValue(dirs, dir) then
			SCP.IncludeDir("modules/" .. dir)
			loaded[dir] = true
		end
	end
	for _, dir in ipairs(dirs) do
		if not loaded[dir] then SCP.IncludeDir("modules/" .. dir) end
	end
end

SCP.IncludeDir("core", { "sh_config.lua", "sh_util.lua", "sh_net.lua", "cl_ui.lua", "cl_fonts.lua", "cl_elements.lua" })
SCP.LoadModules()
