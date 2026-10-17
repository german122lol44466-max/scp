--[[
	Отдача контента клиентам по FastDL. Если аддон контента залит в Workshop —
	укажите его ID в scp_workshop_id, тогда клиенты скачают его подпиской.
]]

local function addDir(dir)
	local files, dirs = file.Find(dir .. "/*", "GAME")
	for _, f in ipairs(files or {}) do resource.AddSingleFile(dir .. "/" .. f) end
	for _, d in ipairs(dirs or {}) do addDir(dir .. "/" .. d) end
end

local ws = CreateConVar("scp_workshop_id", "", FCVAR_ARCHIVE, "ID аддона контента в Workshop (пусто — FastDL)")

hook.Add("Initialize", "scp.resources", function()
	if ws:GetString() ~= "" then
		resource.AddWorkshop(ws:GetString())
		return
	end
	for _, dir in ipairs({ "materials/scpsite", "sound/scpsite" }) do addDir(dir) end
	for _, mask in ipairs({ "Manrope_*.ttf", "Oswald_*.ttf", "JetBrainsMono_*.ttf" }) do
		for _, f in ipairs(file.Find("resource/fonts/" .. mask, "GAME") or {}) do
			resource.AddSingleFile("resource/fonts/" .. f)
		end
	end
end)
