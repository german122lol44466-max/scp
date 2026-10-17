--[[
	Общие помощники.
]]

-- Имя персонажа (меняется в лобби), по умолчанию — ник Steam.
local PLAYER = FindMetaTable("Player")

function PLAYER:SCPName()
	local n = self:GetNW2String("scp.name", "")
	if n == "" then return self:Nick() end
	return n
end

-- Состояние игрока: "menu" (главное меню), "lobby" (лобби), "playing" (на задании)
function PLAYER:SCPState()
	return self:GetNW2String("scp.state", "menu")
end

function PLAYER:InGame()
	return self:SCPState() == "playing"
end

function PLAYER:SCPLobby()
	return self:GetNW2Int("scp.lobby", 0)
end

function SCP.Players(state)
	local out = {}
	for _, p in ipairs(player.GetAll()) do
		if not state or p:SCPState() == state then out[#out + 1] = p end
	end
	return out
end

-- Чистит имя: без переносов, лишних пробелов и длиннее 24 символов (UTF-8).
function SCP.CleanName(s)
	s = string.gsub(tostring(s or ""), "[%c]", "")
	s = string.Trim(string.gsub(s, "%s+", " "))
	if utf8.len(s) and utf8.len(s) > 24 then
		s = string.sub(s, 1, utf8.offset(s, 25) - 1)
	end
	return s
end

function SCP.FormatTime(sec)
	sec = math.max(0, math.floor(sec or 0))
	local h, m = math.floor(sec / 3600), math.floor(sec % 3600 / 60)
	if h > 0 then return h .. " ч " .. m .. " мин" end
	return m .. " мин"
end
