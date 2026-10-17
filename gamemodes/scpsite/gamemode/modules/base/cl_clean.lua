--[[
	Чистый экран: HUD других аддонов не рисуется (хуки HUDPaint/HUDPaintBackground и т.п. чужих аддонов
	снимаются при входе и периодически). Остаются хуки режима (scp.*) и белый список scp_hud_whitelist
	(по умолчанию — прицел TFA). Встроенный HUD оружия TFA выключается — патроны рисует режим.
	Сообщения аддонов в чат (chat.AddText) уходят только в консоль.
	Выключить: scp_clean_hud 0.
]]

local enabled = CreateClientConVar("scp_clean_hud", "1", true, false, "Скрывать HUD других аддонов")
local white = CreateClientConVar("scp_hud_whitelist", "tfa_crosshair,tfa_drawcrosshair", true, false,
	"Части имён хуков, которые не трогать (через запятую)")

local HOOKS = { "HUDPaint", "HUDPaintBackground", "HUDDrawTargetID", "HUDDrawScoreBoard", "DrawDeathNotice", "PostDrawHUD" }
SCP.RemovedHUD = SCP.RemovedHUD or {}

local function allowed(id)
	if not isstring(id) then return true end -- хуки-объекты (ENT/таблицы) не трогаем
	local low = string.lower(id)
	if string.StartWith(low, "scp.") then return true end
	for w in string.gmatch(string.lower(white:GetString()), "[^,%s]+") do
		if string.find(low, w, 1, true) then return true end
	end
	return false
end

local function sweep()
	if not enabled:GetBool() then return end
	local tbl = hook.GetTable()
	for _, name in ipairs(HOOKS) do
		for id in pairs(tbl[name] or {}) do
			if not allowed(id) then
				hook.Remove(name, id)
				SCP.RemovedHUD[name .. "/" .. tostring(id)] = true
			end
		end
	end
end

hook.Add("InitPostEntity", "scp.clean", function()
	sweep()
	timer.Simple(3, sweep)
	timer.Simple(15, sweep)
	-- встроенный HUD оружия TFA и его подсказки
	for cv, v in pairs({ cl_tfa_hud_enabled = "0", cl_tfa_hud_hitmarker_enabled = "0", cl_tfa_inspection_old = "0" }) do
		if ConVarExists(cv) then RunConsoleCommand(cv, v) end
	end
end)
timer.Create("scp.clean", 20, 0, sweep)

concommand.Add("scp_hud_removed", function()
	for k in SortedPairs(SCP.RemovedHUD) do print(k) end
end)
