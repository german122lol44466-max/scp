--[[
	Настройки игрока (ESC → Настройки). Всё хранится в convar'ах клиента (сохраняются между заходами).
	Громкость голоса: общая (scp_voice_volume) и для каждого игрока отдельно (TAB → ПКМ), применяется
	через Player:SetVoiceVolumeScale.
]]

local Set = {}
SCP.Settings = Set

Set.Vars = {
	voice = CreateClientConVar("scp_voice_volume", "1", true, false, "Громкость голосового чата", 0, 2),
	vo = CreateClientConVar("scp_vo_volume", "1", true, false, "Громкость оповещений", 0, 1.5),
	sfx = CreateClientConVar("scp_ambient_volume", "1", true, false, "Громкость атмосферы комплекса", 0, 1.5),
	hud = CreateClientConVar("scp_hud_style", "minimal", true, false, "Стиль HUD: minimal | cb | sl"),
	vignette = CreateClientConVar("scp_vignette", "1", true, false, "Виньетка"),
	grain = CreateClientConVar("scp_grain", "1", true, false, "Плёночное зерно и цветокоррекция"),
	markers = CreateClientConVar("scp_markers", "1", true, false, "Метки целей и предметов"),
}

function Set.Get(k) return Set.Vars[k] end
function Set.Num(k) return Set.Vars[k]:GetFloat() end
function Set.Bool(k) return Set.Vars[k]:GetBool() end
function Set.Str(k) return Set.Vars[k]:GetString() end

-- Громкость конкретного игрока (множитель 0..2), хранится в cookie по SteamID64
function Set.PlayerVolume(ply)
	return tonumber(cookie.GetString("scp_vol_" .. ply:SteamID64(), "1")) or 1
end
function Set.SetPlayerVolume(ply, v)
	cookie.Set("scp_vol_" .. ply:SteamID64(), tostring(math.Round(v, 2)))
	Set.ApplyVoice()
end

function Set.ApplyVoice()
	local g = Set.Num("voice")
	for _, p in ipairs(player.GetAll()) do
		if p ~= LocalPlayer() and not p:IsBot() then
			p:SetVoiceVolumeScale(math.Clamp(g * Set.PlayerVolume(p), 0, 2))
		end
	end
end

cvars.AddChangeCallback("scp_voice_volume", function() Set.ApplyVoice() end, "scp.settings")
timer.Create("scp.settings.voice", 3, 0, Set.ApplyVoice)
