--[[
	Динамичная камера от первого лица:
	- покачивание головы от шагов (сильнее на бегу), лёгкий крен при стрейфе;
	- «присед» камеры при приземлении, толчок при уроне;
	- дыхание: в покое еле заметное, после бега — тяжёлое;
	- на бегу FOV чуть шире, при низком здоровье картинку «ведёт».
	Модули могут перехватить вид целиком через hook "SCP.CalcView" (меню, смерть, предпросмотр камер).
]]

local UI = SCP.UI
local Cam = SCP.Camera

local bobT, bobAmt = 0, 0
local roll, fovAdd = 0, 0
local landKick, landVel = 0, 0
local punch, punchVel = Angle(), Angle()
local lastAng

CreateClientConVar("scp_camera_bob", "1", true, false, "Сила покачивания камеры (0..1.5)", 0, 1.5)

hook.Add("OnPlayerHitGround", "scp.camera", function(ply, inWater, onFloater, speed)
	if ply ~= LocalPlayer() or not IsFirstTimePredicted() then return end
	landVel = landVel + math.Clamp((speed - 120) / 500, 0, 1) * 22
end)

-- Толчок камеры (урон, взрыв): Cam.Punch(Angle)
function Cam.Punch(a)
	punchVel = punchVel + a * 20
end

gameevent.Listen("player_hurt")
hook.Add("player_hurt", "scp.camera", function(data)
	local me = LocalPlayer()
	if IsValid(me) and data.userid == me:UserID() then
		Cam.Punch(Angle(math.Rand(-3, -1.5), math.Rand(-2, 2), math.Rand(-4, 4)))
		Cam.HurtAt = RealTime()
	end
end)

function GM:CalcView(ply, origin, angles, fov, znear, zfar)
	local custom = hook.Run("SCP.CalcView", ply, origin, angles, fov)
	if custom then return custom end

	local view = self.BaseClass.CalcView(self, ply, origin, angles, fov, znear, zfar) or { origin = origin, angles = angles, fov = fov }
	if not ply:Alive() or ply:InVehicle() or ply:GetViewEntity() ~= ply or ply:GetMoveType() == MOVETYPE_NOCLIP then
		return view
	end
	if SCP.MyState() ~= "playing" then return view end

	local ft = FrameTime()
	local k = GetConVar("scp_camera_bob"):GetFloat()
	local vel = ply:GetVelocity()
	local speed = vel:Length2D()
	local onGround = ply:OnGround()
	local running = ply:KeyDown(IN_SPEED) and speed > ply:GetWalkSpeed() + 10

	-- шаги
	local want = onGround and math.Clamp(speed / ply:GetRunSpeed(), 0, 1.2) or 0
	bobAmt = UI.Approach(bobAmt, want, 8)
	bobT = bobT + ft * (running and 13 or 9.5) * math.Clamp(speed / 120, 0.5, 1.5)
	local ang = view.angles * 1
	local pos = view.origin * 1
	local amp = bobAmt * k * (running and 1.4 or 0.8)
	pos = pos + ang:Up() * math.abs(math.sin(bobT)) * -1.4 * amp
	pos = pos + ang:Right() * math.sin(bobT) * 0.6 * amp
	ang.p = ang.p + math.abs(math.sin(bobT)) * 0.7 * amp
	ang.r = ang.r + math.sin(bobT) * 0.5 * amp

	-- крен при стрейфе
	local side = vel:Dot(angles:Right())
	roll = UI.Approach(roll, math.Clamp(side / 200, -1, 1) * 1.8 * k, 6)
	ang.r = ang.r + roll

	-- дыхание (после бега — сильнее)
	local st = SCP.Stamina.Get(ply) / SCP.Config.Stamina.Max
	local breath = (0.25 + (1 - st) * 1.3) * k
	local bt = RealTime() * (1.1 + (1 - st) * 1.6)
	ang.p = ang.p + math.sin(bt) * 0.35 * breath
	ang.y = ang.y + math.sin(bt * 0.5) * 0.2 * breath
	pos.z = pos.z + math.sin(bt) * 0.25 * breath

	-- приземление
	landVel = landVel + (-landKick * 70 - landVel * 11) * ft
	landKick = landKick + landVel * ft
	pos.z = pos.z - landKick * 5
	ang.p = ang.p + landKick * 2.5

	-- толчки
	punchVel = punchVel + (punch * -120 - punchVel * 14) * ft
	punch = punch + punchVel * ft
	ang = ang + punch

	-- низкое здоровье — картинку «ведёт»
	local hp = ply:Health()
	if hp < 40 then
		local d = (1 - hp / 40) * k
		local t = RealTime()
		ang.r = ang.r + math.sin(t * 0.8) * 2.2 * d
		ang.p = ang.p + math.sin(t * 0.55) * 0.9 * d
	end

	-- FOV на бегу
	fovAdd = UI.Approach(fovAdd, running and 5 or 0, 5)
	view.fov = view.fov + fovAdd

	view.origin, view.angles = pos, ang
	Cam.ApplyLean(view, ply)
	return view
end

-- Вьюмодель: те же покачивания, но мягче (TFA добавит своё поверх)
function GM:CalcViewModelView(wep, vm, oldPos, oldAng, pos, ang)
	local p, a = self.BaseClass.CalcViewModelView(self, wep, vm, oldPos, oldAng, pos, ang)
	p, a = p or pos, a or ang
	if SCP.MyState() == "playing" then
		p = p - Vector(0, 0, landKick * 1.5)
	end
	return p, a
end
