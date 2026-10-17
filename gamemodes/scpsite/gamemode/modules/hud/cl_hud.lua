--[[
	Иммерсивный HUD — на экране только то, что нужно сейчас:
	  - виньетка всегда (темнее по краям), кровь по краям при уроне, обесцвечивание при низком здоровье;
	  - здоровье и выносливость снизу слева появляются, когда меняются или когда их мало;
	  - патроны снизу справа — при стрельбе, перезарядке и когда их мало;
	  - имя игрока над головой, когда на него смотришь;
	  - подсказка «E» у предметов и целей.
]]

local UI = SCP.UI
local H = SCP.HUD

local shown = { vit = 0, ammo = 0 }
local last = { hp = 100, st = 100, clip = -1, reserve = -1 }
local showUntil = { vit = 0, ammo = 0 }
local hurtAt, hurtAmt = 0, 0
local smooth = { hp = 100, st = 100, armor = 0 }

local function playing()
	local me = LocalPlayer()
	return IsValid(me) and SCP.MyState() == "playing" and me:Alive()
end

-- ---------------------------------------------------------- виньетка --
hook.Add("HUDPaintBackground", "scp.hud.vignette", function()
	local st = SCP.MyState()
	if st ~= "playing" then return end
	local w, h = ScrW(), ScrH()
	UI.Vignette(0, 0, w, h, 235)
	local me = LocalPlayer()
	if not me:Alive() then return end
	-- кровь по краям: вспышка при уроне + постоянно при низком здоровье
	local t = RealTime() - hurtAt
	local flash = math.Clamp(1 - t / 1.2, 0, 1) * hurtAmt
	local low = math.Clamp(1 - me:Health() / 45, 0, 1)
	local pulse = low * (0.55 + 0.45 * math.sin(RealTime() * (2 + low * 3)))
	local a = math.max(flash, pulse)
	if a > 0.01 then
		surface.SetMaterial(UI.Mat("scpsite/ui/blood_edges.png"))
		surface.SetDrawColor(255, 255, 255, 255 * a)
		surface.DrawTexturedRect(0, 0, w, h)
	end
end)

gameevent.Listen("player_hurt")
hook.Add("player_hurt", "scp.hud", function(data)
	local me = LocalPlayer()
	if IsValid(me) and data.userid == me:UserID() then
		hurtAmt = math.Clamp((last.hp - data.health) / 40, 0.35, 1)
		hurtAt = RealTime()
	end
end)

hook.Add("RenderScreenspaceEffects", "scp.hud.lowhp", function()
	if not playing() then return end
	local low = math.Clamp(1 - LocalPlayer():Health() / 50, 0, 1)
	if low <= 0 then return end
	DrawColorModify({
		["$pp_colour_addr"] = 0.02 * low, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.02 * low, ["$pp_colour_contrast"] = 1 + 0.1 * low,
		["$pp_colour_colour"] = 1 - 0.7 * low, ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
	})
end)

-- ------------------------------------------------------- здоровье и т.д. --
local function bar(x, y, w, h, frac, col, back)
	surface.SetDrawColor(back or Color(255, 255, 255, 22))
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, w * math.Clamp(frac, 0, 1), h)
end

hook.Add("HUDPaint", "scp.hud.vitals", function()
	if not playing() then return end
	local me = LocalPlayer()
	local hp, st = me:Health(), SCP.Stamina.Get(me)
	local now = RealTime()
	if math.abs(hp - last.hp) > 0.5 then showUntil.vit = now + 4 end
	if st < last.st - 0.5 then showUntil.vit = now + 2.5 end
	last.hp, last.st = hp, st
	local need = hp < 50 or st < 35 or SCP.Stamina.Exhausted(me) or now < showUntil.vit or input.IsKeyDown(KEY_LALT)
	shown.vit = UI.Approach(shown.vit, need and 1 or 0, need and 10 or 3)
	smooth.hp = UI.Approach(smooth.hp, hp, 8)
	smooth.st = UI.Approach(smooth.st, st, 12)
	smooth.armor = UI.Approach(smooth.armor, me:Armor(), 8)
	if shown.vit < 0.01 then return end

	local a = shown.vit
	local x, y = UI.S(40), ScrH() - UI.S(64)
	local w = UI.S(240)
	surface.SetAlphaMultiplier(a)
	-- здоровье: число + полоса
	UI.DrawIcon("heart", x + UI.S(8), y - UI.S(28), UI.S(16), hp < 35 and UI.Col.red or UI.Col.text)
	draw.SimpleText(math.max(0, hp), SCP.Font("title", 26), x + UI.S(26), y - UI.S(28), hp < 35 and UI.Col.red or UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	if me:Armor() > 0 then
		UI.DrawIcon("shield", x + UI.S(96), y - UI.S(28), UI.S(15), UI.Col.dim)
		draw.SimpleText(me:Armor(), SCP.Font("titlemed", 18), x + UI.S(110), y - UI.S(28), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	bar(x, y - UI.S(8), w, UI.S(4), smooth.hp / me:GetMaxHealth(), hp < 35 and UI.Col.red or Color(232, 230, 224, 230))
	if smooth.armor > 0 then bar(x, y, w * 0.6, UI.S(2), smooth.armor / 100, Color(140, 170, 210, 200)) end
	-- выносливость
	local ex = SCP.Stamina.Exhausted(me)
	bar(x, y + UI.S(8), w, UI.S(3), smooth.st / SCP.Config.Stamina.Max, ex and Color(230, 180, 60, 220) or Color(200, 200, 196, 160))
	if ex then
		draw.SimpleText("ВЫДОХСЯ", SCP.Font("monobold", 11), x + w + UI.S(10), y + UI.S(9), UI.Col.amber, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	surface.SetAlphaMultiplier(1)
end)

-- --------------------------------------------------------------- патроны --
hook.Add("HUDPaint", "scp.hud.ammo", function()
	if not playing() then return end
	local me = LocalPlayer()
	local w = me:GetActiveWeapon()
	if not IsValid(w) or w:GetMaxClip1() <= 0 then shown.ammo = UI.Approach(shown.ammo, 0, 6) return end
	local clip, reserve = w:Clip1(), me:GetAmmoCount(w:GetPrimaryAmmoType())
	local now = RealTime()
	if clip ~= last.clip or reserve ~= last.reserve then showUntil.ammo = now + 2.5 end
	last.clip, last.reserve = clip, reserve
	local low = clip <= w:GetMaxClip1() * 0.25
	local need = low or now < showUntil.ammo or me:KeyDown(IN_RELOAD) or input.IsKeyDown(KEY_LALT)
	shown.ammo = UI.Approach(shown.ammo, need and 1 or 0, need and 10 or 3)
	if shown.ammo < 0.01 then return end
	surface.SetAlphaMultiplier(shown.ammo)
	local x, y = ScrW() - UI.S(44), ScrH() - UI.S(60)
	local col = low and UI.Col.red or UI.Col.text
	local cw = UI.TextSize(clip, SCP.Font("title", 40))
	draw.SimpleText(reserve, SCP.Font("titlemed", 20), x, y + UI.S(6), UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	local rw = UI.TextSize(reserve, SCP.Font("titlemed", 20))
	draw.SimpleText("/", SCP.Font("titlelight", 22), x - rw - UI.S(8), y + UI.S(6), UI.Col.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	draw.SimpleText(clip, SCP.Font("title", 40), x - rw - UI.S(24), y + UI.S(10), col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	-- пули клипа полоской
	local max = w:GetMaxClip1()
	local bw = UI.S(160)
	local seg = math.min(max, 50)
	for i = 1, seg do
		local filled = i <= math.ceil(clip / max * seg)
		surface.SetDrawColor(255, 255, 255, filled and 200 or 30)
		surface.DrawRect(x - bw + (i - 1) * bw / seg, y + UI.S(18), math.max(1, bw / seg - 1), UI.S(6))
	end
	draw.SimpleText(string.upper(w:GetPrintName() or ""), SCP.Font("mono", 11), x, y - UI.S(44), UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	if clip == 0 and reserve > 0 then
		draw.SimpleText("[R] ПЕРЕЗАРЯДКА", SCP.Font("monobold", 13), ScrW() / 2, ScrH() / 2 + UI.S(60), UI.Alpha(UI.Col.red, 180 + 75 * math.sin(RealTime() * 6)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	surface.SetAlphaMultiplier(1)
end)

-- ------------------------------------------------- имя при взгляде на игрока --
local nameAnim = {}
hook.Add("HUDPaint", "scp.hud.names", function()
	if SCP.MyState() ~= "playing" then return end
	local me = LocalPlayer()
	local tr = util.TraceHull({ start = EyePos(), endpos = EyePos() + EyeAngles():Forward() * 500, filter = me, mins = Vector(-4, -4, -4), maxs = Vector(4, 4, 4), mask = MASK_SHOT })
	local target = IsValid(tr.Entity) and tr.Entity:IsPlayer() and tr.Entity:Alive() and tr.Entity or nil
	for _, p in ipairs(player.GetAll()) do
		if p ~= me then
			nameAnim[p] = UI.Approach(nameAnim[p] or 0, p == target and 1 or 0, p == target and 10 or 5)
			local a = nameAnim[p]
			if a > 0.01 and p:Alive() then
				local bone = p:LookupBone("ValveBiped.Bip01_Head1")
				local pos = (bone and p:GetBonePosition(bone) or p:EyePos()) + Vector(0, 0, 16)
				local s = pos:ToScreen()
				if s.visible then
					surface.SetAlphaMultiplier(a)
					local y = s.y - (1 - a) * UI.S(6)
					draw.SimpleTextOutlined(p:SCPName(), SCP.Font("semibold", 17), s.x, y, UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 150))
					local hp = p:Health()
					local status = hp < 35 and "ТЯЖЕЛО РАНЕН" or (hp < 70 and "РАНЕН" or nil)
					if status then
						draw.SimpleTextOutlined(status, SCP.Font("monobold", 11), s.x, y + UI.S(4), hp < 35 and UI.Col.red or UI.Col.amber, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 150))
					end
					surface.SetAlphaMultiplier(1)
				end
			end
		end
	end
end)

-- ---------------------------------------------------- подсказка «E» --
local prompt = { a = 0, text = "", prog = nil }
hook.Add("HUDPaint", "scp.hud.prompt", function()
	if not playing() then prompt.a = 0 return end
	local me = LocalPlayer()
	local tr = util.TraceLine({ start = EyePos(), endpos = EyePos() + EyeAngles():Forward() * 110, filter = me })
	local ent = tr.Entity
	local text, prog
	if IsValid(ent) and ent.SCPPrompt then text, prog = ent:SCPPrompt() end
	if text then prompt.text, prompt.prog = text, prog end
	prompt.a = UI.Approach(prompt.a, text and 1 or 0, 12)
	if prompt.a < 0.01 then return end
	surface.SetAlphaMultiplier(prompt.a)
	local cx, cy = ScrW() / 2, ScrH() / 2 + UI.S(70)
	local key = string.upper(input.LookupBinding("+use") or "E")
	local font = SCP.Font("semibold", 16)
	local tw = UI.TextSize(prompt.text, font)
	local w = tw + UI.S(60)
	surface.SetDrawColor(10, 11, 13, 200)
	surface.DrawRect(cx - w / 2, cy - UI.S(18), w, UI.S(36))
	surface.SetDrawColor(232, 230, 224)
	surface.DrawRect(cx - w / 2 + UI.S(8), cy - UI.S(11), UI.S(22), UI.S(22))
	draw.SimpleText(key, SCP.Font("monobold", 13), cx - w / 2 + UI.S(19), cy, Color(12, 12, 14), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(prompt.text, font, cx - w / 2 + UI.S(42), cy, UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	if prompt.prog then
		surface.SetDrawColor(255, 255, 255, 30)
		surface.DrawRect(cx - w / 2, cy + UI.S(18), w, UI.S(3))
		surface.SetDrawColor(UI.Col.amber)
		surface.DrawRect(cx - w / 2, cy + UI.S(18), w * prompt.prog, UI.S(3))
	end
	surface.SetAlphaMultiplier(1)
end)

-- Маленькая точка по центру, когда в руках нет оружия с прицелом (TFA рисует свой прицел)
hook.Add("HUDPaint", "scp.hud.dot", function()
	if not playing() then return end
	local w = LocalPlayer():GetActiveWeapon()
	if IsValid(w) and w.IsTFAWeapon then return end
	UI.Circle(ScrW() / 2, ScrH() / 2, UI.S(2), Color(255, 255, 255, 140))
end)
