--[[
	Выглядывание на Q / E (удерживать):
	- короткое нажатие Q — личное дело, короткое E — «использовать», как обычно;
	- удержание Q — наклон влево, E — вправо (E не наклоняет, когда смотрите на дверь, предмет, цель или товарища);
	- камера сдвигается вбок и кренится, упираясь в стены; другие игроки видят наклон корпуса.
]]

local UI = SCP.UI
local Cam = SCP.Camera
local HOLD = 0.2
local lean, sent = 0, 0
local qAt, eAt

local function keyOf(bind, def)
	local k = input.LookupBinding(bind)
	return input.GetKeyCode(k or def)
end

-- E «занят», если смотрим на что-то используемое
local function eBusy()
	local me = LocalPlayer()
	local tr = util.TraceLine({ start = EyePos(), endpos = EyePos() + EyeAngles():Forward() * 110, filter = me })
	local e = tr.Entity
	if not IsValid(e) then return false end
	if e:IsPlayer() or e.SCPPrompt then return true end
	local cls = e:GetClass()
	return string.find(cls, "door", 1, true) or string.find(cls, "button", 1, true) or string.find(cls, "func_", 1, true) ~= nil
end

function Cam.Lean() return lean end

-- Q: личное дело по короткому нажатию (вызывается из GM:OnSpawnMenuOpen/Close)
function Cam.QPressed() qAt = RealTime() end
function Cam.QReleased()
	local short = qAt and (RealTime() - qAt) < HOLD
	qAt = nil
	return short
end

hook.Add("Think", "scp.lean", function()
	local me = LocalPlayer()
	if not IsValid(me) then return end
	local want = 0
	local ok = SCP.MyState() == "playing" and me:Alive() and not vgui.GetKeyboardFocus() and not gui.IsGameUIVisible()
		and me:GetMoveType() == MOVETYPE_WALK and not IsValid(SCP.Inv.Panel)
	if ok then
		if qAt and RealTime() - qAt > HOLD and input.IsKeyDown(keyOf("+menu", "q")) then want = want - 1 end
		local eDown = input.IsKeyDown(keyOf("+use", "e"))
		if eDown then
			eAt = eAt or RealTime()
			if RealTime() - eAt > HOLD and not eBusy() then want = want + 1 end
		else
			eAt = nil
		end
		-- на бегу не выглядываем
		if me:KeyDown(IN_SPEED) and me:GetVelocity():Length2D() > 150 then want = 0 end
	else
		qAt, eAt = nil, nil
	end
	lean = UI.Approach(lean, want, 9)
	if math.abs(lean) < 0.01 and want == 0 then lean = 0 end
	local q = math.Round(lean * 100)
	if q ~= sent and (math.abs(q - sent) > 8 or q == 0 or math.abs(q) == 100) then
		sent = q
		net.Start("scp.lean")
		net.WriteInt(q, 8)
		net.SendToServer()
	end
end)

-- Смещение камеры (вызывается из GM:CalcView)
function Cam.ApplyLean(view, ply)
	if lean == 0 then return end
	local ang = view.angles
	local want = view.origin + ang:Right() * lean * 15 - ang:Up() * math.abs(lean) * 2
	local tr = util.TraceHull({ start = view.origin, endpos = want, mins = Vector(-4, -4, -4), maxs = Vector(4, 4, 4), filter = ply, mask = MASK_SOLID })
	view.origin = tr.HitPos
	view.angles = Angle(ang.p, ang.y, ang.r + lean * 11)
end

-- Наклон корпуса у других игроков (и у себя — для ног/тени)
local bones = { "ValveBiped.Bip01_Spine", "ValveBiped.Bip01_Spine1", "ValveBiped.Bip01_Spine2" }
hook.Add("PrePlayerDraw", "scp.lean", function(ply)
	local v = ply == LocalPlayer() and lean or ply:GetNW2Float("scp.lean", 0)
	ply.scpLeanSmooth = UI.Approach(ply.scpLeanSmooth or 0, v, 10)
	local l = ply.scpLeanSmooth
	if math.abs(l) < 0.01 and not ply.scpLeanApplied then return end
	ply.scpLeanApplied = math.abs(l) >= 0.01
	for _, name in ipairs(bones) do
		local b = ply:LookupBone(name)
		if b then ply:ManipulateBoneAngles(b, Angle(0, 0, l * 10)) end
	end
end)
