--[[
	Окно диалога снизу по центру: слева значок говорящего, имя и роль, текст печатается по буквам.
	Реплики идут очередью (не больше 3 на экране), старые уезжают вверх и гаснут.
]]

local UI = SCP.UI
local DG = SCP.Dialog
local queue = {}

local function push(d)
	d.born = RealTime()
	d.dur = math.max(3.5, utf8.len(d.text) / 15 + 1.5)
	queue[#queue + 1] = d
	while #queue > 3 do table.remove(queue, 1) end
end

-- Озвученная реплика Командования (файл vo/cmd_<CRC32 текста>.mp3, собирается tools/build_content.py)
function DG.PlayVoice(text)
	local path = "sound/scpsite/vo/cmd_" .. util.CRC(text) .. ".mp3"
	if not file.Exists(path, "GAME") then return end
	local vol = GetConVar("scp_vo_volume"):GetFloat()
	sound.PlayFile(path, "noblock", function(ch) if IsValid(ch) then ch:SetVolume(math.min(vol, 1)) ch:Play() end end)
end

function DG.Show(who, speaker, text, snd)
	local r = DG.Roles[who]
	local d = { text = text, who = who }
	if who == "player" and IsValid(speaker) then
		local _, idx, fac = SCP.Lobby.ModelOf(speaker)
		d.name = speaker:SCPName()
		d.role = string.upper((fac.short or "") .. " · " .. (fac.modelNames[idx] or ""))
		d.col = fac.color or UI.Col.text
		d.icon = "user"
		d.me = speaker == LocalPlayer()
	elseif r then
		d.name, d.role, d.col, d.icon = r.name, r.role, r.col, r.icon
	else
		return
	end
	if who == "command" then
		surface.PlaySound("scpsite/fx/radio_squelch.mp3")
		timer.Simple(0.15, function() DG.PlayVoice(text) end)
	end
	if snd and snd ~= "" then surface.PlaySound(snd) end
	push(d)
	-- в чат — для истории
	if SCP.Chat.Add then
		SCP.Chat.Add({ kind = who == "command" and "radio" or (who == "pa" and "system" or "say"), name = d.name, text = text, nolog = true })
	end
end

net.Receive("scp.dialog", function()
	local who, speaker, text, snd = net.ReadString(), net.ReadEntity(), net.ReadString(), net.ReadString()
	DG.Show(who, speaker, text, snd)
end)

hook.Add("HUDPaint", "scp.dialog", function()
	if SCP.MyState() ~= "playing" or #queue == 0 then return end
	local now = RealTime()
	local w = UI.S(700)
	local x = ScrW() / 2 - w / 2
	local y = ScrH() - UI.S(168)
	for i = #queue, 1, -1 do
		local d = queue[i]
		local t = now - d.born
		if t > d.dur + 0.6 then
			table.remove(queue, i)
		else
			local a = math.min(t / 0.25, 1) * math.min((d.dur + 0.6 - t) / 0.6, 1)
			local font = SCP.Font("medium", 17)
			-- печать по буквам
			local total = utf8.len(d.text)
			local shown = math.min(total, math.floor(t * 55))
			local txt = shown >= total and d.text or string.sub(d.text, 1, (utf8.offset(d.text, shown + 1) or (#d.text + 1)) - 1)
			local lines = UI.Wrap(d.text, font, w - UI.S(110))
			local h = UI.S(48) + #lines * UI.S(23)
			d.y = d.y and UI.Approach(d.y, y - h, 10) or (y - h + UI.S(14))
			surface.SetAlphaMultiplier(a)
			UI.BlurRect(x, d.y, w, h, 3)
			surface.SetDrawColor(8, 9, 11, 215)
			surface.DrawRect(x, d.y, w, h)
			surface.SetDrawColor(255, 255, 255, 14)
			surface.DrawOutlinedRect(x, d.y, w, h, 1)
			surface.SetDrawColor(d.col)
			surface.DrawRect(x, d.y, UI.S(3), h)
			-- значок
			local ix, iy = x + UI.S(40), d.y + UI.S(34)
			UI.Circle(ix, iy, UI.S(20), Color(d.col.r, d.col.g, d.col.b, 30))
			UI.Ring(ix, iy, UI.S(20), Color(d.col.r, d.col.g, d.col.b, 160))
			UI.DrawIcon(d.icon, ix, iy, UI.S(18), d.col)
			if d.who == "command" then
				-- «эквалайзер» рации
				for k = 0, 3 do
					local hh = UI.S(3) + UI.S(9) * math.abs(math.sin(now * 11 + k * 1.3)) * (shown < total and 1 or 0.2)
					surface.SetDrawColor(d.col)
					surface.DrawRect(ix - UI.S(9) + k * UI.S(5), iy + UI.S(28) - hh, UI.S(3), hh)
				end
			end
			draw.SimpleText(d.name, SCP.Font("semibold", 16), x + UI.S(78), d.y + UI.S(20), d.me and UI.Col.text or d.col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			if d.role ~= "" then
				local nw = UI.TextSize(d.name, SCP.Font("semibold", 16))
				draw.SimpleText(d.role, SCP.Font("mono", 11), x + UI.S(90) + nw, d.y + UI.S(21), UI.Col.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			-- текст: печатаем по готовым строкам
			local left = utf8.len(txt)
			for li, l in ipairs(lines) do
				local ll = utf8.len(l) + 1
				local part = left >= ll - 1 and l or string.sub(l, 1, (utf8.offset(l, math.max(left, 0) + 1) or (#l + 1)) - 1)
				local col = d.who == "self" and UI.Col.dim or UI.Col.text
				draw.SimpleText(part, font, x + UI.S(78), d.y + UI.S(36) + (li - 1) * UI.S(23), col)
				left = left - ll
				if left < 0 then break end
			end
			surface.SetAlphaMultiplier(1)
			y = d.y - UI.S(8)
		end
	end
end)

-- ------------------------------------------------------- G — реплики Фонда --
SCP.Radial("foundation", {
	key = KEY_G, convar = "scp_shout_key", title = "ФОНД",
	items = function() return DG.Shouts end,
	pick = function(i)
		net.Start("scp.shout")
		net.WriteUInt(i, 5)
		net.SendToServer()
	end,
})
