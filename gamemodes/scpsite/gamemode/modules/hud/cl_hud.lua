--[[
	HUD. Три стиля (ESC → Настройки → Стиль HUD, convar scp_hud_style):
	  minimal — «Объект-19»: здоровье/выносливость/патроны появляются только когда нужны (ALT — показать);
	  cb      — как в SCP – Containment Breach: шкалы из блоков с иконками моргания и бега, снизу слева;
	  sl      — как в SCP: Secret Laboratory: роль цветом фракции, полосы здоровья/брони/выносливости, патроны справа.
	Общее для всех: виньетка, кровь по краям, имя игрока при взгляде, подсказка E, карточка роли при появлении.
]]

local UI = SCP.UI
local H = SCP.HUD
local Set = SCP.Settings

local shown = { vit = 0, ammo = 0 }
local last = { hp = 100, st = 100, clip = -1, reserve = -1 }
local showUntil = { vit = 0, ammo = 0 }
local hurtAt, hurtAmt = 0, 0
local smooth = { hp = 100, st = 100, armor = 0, blink = 1 }

local function playing()
	local me = LocalPlayer()
	return IsValid(me) and SCP.MyState() == "playing" and me:Alive() and not (SCP.Cutscene.Active and SCP.Cutscene.Active())
end
H.Playing = playing

function H.Style() return Set.Str("hud") end

-- ---------------------------------------------------------- виньетка --
hook.Add("HUDPaintBackground", "scp.hud.vignette", function()
	if SCP.MyState() ~= "playing" then return end
	local w, h = ScrW(), ScrH()
	if Set.Bool("vignette") then UI.Vignette(0, 0, w, h, 235) end
	local me = LocalPlayer()
	if not me:Alive() then return end
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

-- ------------------------------------------------------------ моргание --
-- Рядом SCP-173 — глаза устают: шкала моргания пустеет, на нуле — моргаете сами (X — моргнуть вручную).
local blink = { level = 1, closedUntil = 0, active = false }
H.Blink = blink
local blinkKey = CreateClientConVar("scp_blink_key", tostring(KEY_X), true, false, "Моргнуть вручную (код KEY_*)")

local function doBlink()
	blink.closedUntil = RealTime() + 0.22
	blink.level = 1
end

hook.Add("Think", "scp.hud.blink", function()
	local me = LocalPlayer()
	if not IsValid(me) then return end
	local near = false
	if SCP.MyState() == "playing" and me:Alive() then
		for _, e in ipairs(ents.FindByClass(SCP.Config.SCPs["173"].class)) do
			if e:GetPos():DistToSqr(me:GetPos()) < 1800 * 1800 then near = true break end
		end
	end
	blink.active = near
	if not near then blink.level = math.min(1, blink.level + FrameTime() * 0.5) return end
	blink.level = blink.level - FrameTime() / 9
	if blink.level <= 0 then doBlink() end
end)

hook.Add("PlayerButtonDown", "scp.hud.blink", function(ply, key)
	if key == blinkKey:GetInt() and IsFirstTimePredicted() and blink.active and not vgui.GetKeyboardFocus() then doBlink() end
end)

hook.Add("PostRenderVGUI", "scp.hud.blinkclose", function()
	if RealTime() < blink.closedUntil and SCP.MyState() == "playing" then
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(0, 0, ScrW(), ScrH())
	end
end)

-- ---------------------------------------------------------- общие данные --
local function vitals(me)
	local hp, st = me:Health(), SCP.Stamina.Get(me)
	local now = RealTime()
	if math.abs(hp - last.hp) > 0.5 then showUntil.vit = now + 4 end
	if st < last.st - 0.5 then showUntil.vit = now + 2.5 end
	last.hp, last.st = hp, st
	smooth.hp = UI.Approach(smooth.hp, hp, 8)
	smooth.st = UI.Approach(smooth.st, st, 12)
	smooth.armor = UI.Approach(smooth.armor, me:Armor(), 8)
	smooth.blink = UI.Approach(smooth.blink, blink.level, 14)
	return hp, st
end

local function ammoInfo(me)
	local w = me:GetActiveWeapon()
	if not IsValid(w) or w:GetMaxClip1() <= 0 then return nil end
	local clip, reserve = w:Clip1(), me:GetAmmoCount(w:GetPrimaryAmmoType())
	if clip ~= last.clip or reserve ~= last.reserve then showUntil.ammo = RealTime() + 2.5 end
	last.clip, last.reserve = clip, reserve
	return w, clip, reserve, w:GetMaxClip1()
end

local function bar(x, y, w, h, frac, col, back)
	surface.SetDrawColor(back or Color(255, 255, 255, 22))
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, w * math.Clamp(frac, 0, 1), h)
end

-- ======================================================== стиль minimal ==
local function drawMinimal(me)
	local hp, st = vitals(me)
	local now = RealTime()
	local need = hp < 50 or st < 35 or SCP.Stamina.Exhausted(me) or now < showUntil.vit or input.IsKeyDown(KEY_LALT) or blink.active
	shown.vit = UI.Approach(shown.vit, need and 1 or 0, need and 10 or 3)
	if shown.vit > 0.01 then
		local a = shown.vit
		local x, y = UI.S(40), ScrH() - UI.S(64)
		local w = UI.S(240)
		surface.SetAlphaMultiplier(a)
		UI.DrawIcon("heart", x + UI.S(8), y - UI.S(28), UI.S(16), hp < 35 and UI.Col.red or UI.Col.text)
		draw.SimpleText(math.max(0, hp), SCP.Font("title", 26), x + UI.S(26), y - UI.S(28), hp < 35 and UI.Col.red or UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		if me:Armor() > 0 then
			UI.DrawIcon("shield", x + UI.S(96), y - UI.S(28), UI.S(15), UI.Col.dim)
			draw.SimpleText(me:Armor(), SCP.Font("titlemed", 18), x + UI.S(110), y - UI.S(28), UI.Col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		bar(x, y - UI.S(8), w, UI.S(4), smooth.hp / me:GetMaxHealth(), hp < 35 and UI.Col.red or Color(232, 230, 224, 230))
		if smooth.armor > 0 then bar(x, y, w * 0.6, UI.S(2), smooth.armor / 100, Color(140, 170, 210, 200)) end
		local ex = SCP.Stamina.Exhausted(me)
		bar(x, y + UI.S(8), w, UI.S(3), smooth.st / SCP.Config.Stamina.Max, ex and Color(230, 180, 60, 220) or Color(200, 200, 196, 160))
		if ex then draw.SimpleText("ВЫДОХСЯ", SCP.Font("monobold", 11), x + w + UI.S(10), y + UI.S(9), UI.Col.amber, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
		if blink.active then
			UI.DrawIcon("eye", x + UI.S(8), y - UI.S(62), UI.S(15), smooth.blink < 0.25 and UI.Col.red or UI.Col.text)
			bar(x + UI.S(24), y - UI.S(64), w - UI.S(24), UI.S(3), smooth.blink, smooth.blink < 0.25 and UI.Col.red or Color(232, 230, 224, 220))
		end
		surface.SetAlphaMultiplier(1)
	end

	local w, clip, reserve, max = ammoInfo(me)
	if not w then shown.ammo = UI.Approach(shown.ammo, 0, 6) return end
	local low = clip <= max * 0.25
	local needA = low or now < showUntil.ammo or me:KeyDown(IN_RELOAD) or input.IsKeyDown(KEY_LALT)
	shown.ammo = UI.Approach(shown.ammo, needA and 1 or 0, needA and 10 or 3)
	if shown.ammo < 0.01 then return end
	surface.SetAlphaMultiplier(shown.ammo)
	local x, y = ScrW() - UI.S(44), ScrH() - UI.S(60)
	local col = low and UI.Col.red or UI.Col.text
	draw.SimpleText(reserve, SCP.Font("titlemed", 20), x, y + UI.S(6), UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	local rw = UI.TextSize(reserve, SCP.Font("titlemed", 20))
	draw.SimpleText("/", SCP.Font("titlelight", 22), x - rw - UI.S(8), y + UI.S(6), UI.Col.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	draw.SimpleText(clip, SCP.Font("title", 40), x - rw - UI.S(24), y + UI.S(10), col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	local bw = UI.S(160)
	local seg = math.min(max, 50)
	for i = 1, seg do
		local filled = i <= math.ceil(clip / max * seg)
		surface.SetDrawColor(255, 255, 255, filled and 200 or 30)
		surface.DrawRect(x - bw + (i - 1) * bw / seg, y + UI.S(18), math.max(1, bw / seg - 1), UI.S(6))
	end
	draw.SimpleText(string.upper(w:GetPrintName() or ""), SCP.Font("mono", 11), x, y - UI.S(44), UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	surface.SetAlphaMultiplier(1)
end

-- ===================================================== стиль Containment Breach ==
local function cbMeter(x, y, frac, icon, col)
	local bw, bh = UI.S(204), UI.S(20)
	-- иконка в рамке
	surface.SetDrawColor(255, 255, 255, 230)
	surface.DrawOutlinedRect(x, y, bh + UI.S(6), bh + UI.S(6), 1)
	UI.DrawIcon(icon, x + (bh + UI.S(6)) / 2, y + (bh + UI.S(6)) / 2, bh * 0.8, col or color_white)
	-- рамка шкалы и 20 блоков
	local mx = x + bh + UI.S(14)
	surface.SetDrawColor(255, 255, 255, 230)
	surface.DrawOutlinedRect(mx, y, bw, bh + UI.S(6), 1)
	local n = 20
	local filled = math.ceil(math.Clamp(frac, 0, 1) * n)
	local cw = (bw - UI.S(6)) / n
	for i = 1, filled do
		surface.SetDrawColor(col or Color(255, 255, 255, 235))
		surface.DrawRect(mx + UI.S(3) + (i - 1) * cw, y + UI.S(3), cw - UI.S(2), bh)
	end
end

local function drawCB(me)
	local hp, st = vitals(me)
	local x, y = UI.S(48), ScrH() - UI.S(60)
	cbMeter(x, y, smooth.st / SCP.Config.Stamina.Max, "run", SCP.Stamina.Exhausted(me) and UI.Col.amber or nil)
	y = y - UI.S(36)
	if blink.active then
		cbMeter(x, y, smooth.blink, "eye", smooth.blink < 0.25 and UI.Col.red or nil)
		y = y - UI.S(36)
	end
	cbMeter(x, y, smooth.hp / me:GetMaxHealth(), "heart", hp < 35 and UI.Col.red or nil)
	local w, clip, reserve = ammoInfo(me)
	if w then
		draw.SimpleText(clip .. " / " .. reserve, SCP.Font("monobold", 22), ScrW() - UI.S(48), ScrH() - UI.S(48), color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

-- ===================================================== стиль Secret Laboratory ==
local function drawSL(me)
	local hp, st = vitals(me)
	local _, idx, fac = SCP.Lobby.ModelOf(me)
	local col = fac.color or UI.Col.text
	local x, y = UI.S(42), ScrH() - UI.S(150)
	draw.SimpleText(string.upper(fac.modelNames[idx] or fac.short), SCP.Font("title", 26), x, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(string.upper(fac.name), SCP.Font("mono", 11), x + UI.S(1), y + UI.S(22), UI.Alpha(col, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	local bw = UI.S(300)
	y = y + UI.S(46)
	-- HP: крупная полоса со скосом
	local function slBar(yy, h, frac, c, label, val)
		draw.NoTexture()
		surface.SetDrawColor(0, 0, 0, 140)
		surface.DrawPoly({ { x = x, y = yy }, { x = x + bw, y = yy }, { x = x + bw - h * 0.6, y = yy + h }, { x = x, y = yy + h } })
		local fw = bw * math.Clamp(frac, 0, 1)
		surface.SetDrawColor(c)
		surface.DrawPoly({ { x = x, y = yy }, { x = x + fw, y = yy }, { x = x + math.max(0, fw - h * 0.6), y = yy + h }, { x = x, y = yy + h } })
		if label then
			draw.SimpleText(label, SCP.Font("monobold", 11), x + UI.S(8), yy + h / 2, Color(10, 10, 12), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(val, SCP.Font("title", 18), x + bw + UI.S(10), yy + h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
	slBar(y, UI.S(24), smooth.hp / me:GetMaxHealth(), hp < 35 and UI.Col.red or Color(235, 235, 235), "HP", math.max(0, hp))
	if me:Armor() > 0 then slBar(y + UI.S(30), UI.S(10), smooth.armor / 100, Color(110, 190, 120), nil) end
	slBar(y + UI.S(46), UI.S(6), smooth.st / SCP.Config.Stamina.Max, Color(230, 200, 80), nil)
	if blink.active then slBar(y + UI.S(58), UI.S(6), smooth.blink, Color(180, 200, 255), nil) end
	local w, clip, reserve = ammoInfo(me)
	if w then
		local ax, ay = ScrW() - UI.S(48), ScrH() - UI.S(70)
		draw.SimpleText(clip, SCP.Font("title", 48), ax - UI.S(70), ay, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(255, 255, 255, 120)
		surface.DrawRect(ax - UI.S(60), ay - UI.S(16), UI.S(2), UI.S(32))
		draw.SimpleText(reserve, SCP.Font("titlemed", 24), ax, ay, UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		draw.SimpleText(string.upper(w:GetPrintName() or ""), SCP.Font("mono", 11), ax, ay + UI.S(30), UI.Col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

hook.Add("HUDPaint", "scp.hud.vitals", function()
	if not playing() then return end
	local me = LocalPlayer()
	local style = H.Style()
	if style == "cb" then drawCB(me) elseif style == "sl" then drawSL(me) else drawMinimal(me) end
	local w, clip, reserve = ammoInfo(me)
	if w and clip == 0 and reserve > 0 then
		draw.SimpleText("[R] ПЕРЕЗАРЯДКА", SCP.Font("monobold", 13), ScrW() / 2, ScrH() / 2 + UI.S(60), UI.Alpha(UI.Col.red, 180 + 75 * math.sin(RealTime() * 6)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end)

-- ------------------------------------------------ карточка роли при появлении --
local roleAt = 0
local wasAlive = false
hook.Add("Think", "scp.hud.role", function()
	local me = LocalPlayer()
	if not IsValid(me) then return end
	local alive = SCP.MyState() == "playing" and me:Alive()
	if alive and not wasAlive then roleAt = RealTime() + 0.8 end
	wasAlive = alive
end)

hook.Add("HUDPaint", "scp.hud.rolecard", function()
	local t = RealTime() - roleAt
	if t < 0 or t > 6 or not playing() then return end
	local me = LocalPlayer()
	local _, idx, fac = SCP.Lobby.ModelOf(me)
	local a = math.min(t / 0.5, 1) * math.min((6 - t) / 0.8, 1)
	surface.SetAlphaMultiplier(a)
	local cx, cy = ScrW() / 2, ScrH() * 0.72
	draw.SimpleText("ВЫ —", SCP.Font("mono", 14), cx, cy - UI.S(44), UI.Col.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(string.upper(fac.modelNames[idx] or ""), SCP.Font("title", 46), cx, cy - UI.S(10), fac.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(string.upper(fac.name) .. " · ДОПУСК " .. (fac.clearance or 2), SCP.Font("monobold", 13), cx, cy + UI.S(26), UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	surface.SetDrawColor(fac.color)
	surface.DrawRect(cx - UI.S(60) * UI.Ease(t / 0.8), cy + UI.S(44), UI.S(120) * UI.Ease(t / 0.8), UI.S(2))
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
					local _, idx, fac = SCP.Lobby.ModelOf(p)
					surface.SetAlphaMultiplier(a)
					local y = s.y - (1 - a) * UI.S(6)
					draw.SimpleTextOutlined(p:SCPName(), SCP.Font("semibold", 17), s.x, y, UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 150))
					draw.SimpleTextOutlined(string.upper(fac.modelNames[idx] or ""), SCP.Font("monobold", 10), s.x, y - UI.S(20), fac.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 150))
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
local prompt = { a = 0, text = "", prog = nil, blocked = false }
hook.Add("HUDPaint", "scp.hud.prompt", function()
	if not playing() then prompt.a = 0 return end
	local me = LocalPlayer()
	local tr = util.TraceLine({ start = EyePos(), endpos = EyePos() + EyeAngles():Forward() * 110, filter = me })
	local ent = tr.Entity
	local text, prog, blocked
	if IsValid(ent) and ent.SCPPrompt then text, prog, blocked = ent:SCPPrompt() end
	local mate = SCP.Interact.Target(me)
	if mate then text, prog, blocked = "Взаимодействие: " .. mate:SCPName(), nil, false end
	if text then prompt.text, prompt.prog, prompt.blocked = text, prog, blocked end
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
	if prompt.blocked then
		UI.DrawIcon("lock", cx - w / 2 + UI.S(19), cy, UI.S(16), UI.Col.red)
	else
		surface.SetDrawColor(232, 230, 224)
		surface.DrawRect(cx - w / 2 + UI.S(8), cy - UI.S(11), UI.S(22), UI.S(22))
		draw.SimpleText(key, SCP.Font("monobold", 13), cx - w / 2 + UI.S(19), cy, Color(12, 12, 14), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	draw.SimpleText(prompt.text, font, cx - w / 2 + UI.S(42), cy, prompt.blocked and UI.Col.red or UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
