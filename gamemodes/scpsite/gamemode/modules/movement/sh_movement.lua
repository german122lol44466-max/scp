--[[
	Передвижение и выносливость.
	- шаг 105, бег 215, медленный шаг 68; бег спиной/боком медленнее; после приземления — замедление,
	  распрыжки нет;
	- выносливость тратится на бег и прыжки; на нуле — «выдохся»: бег недоступен, пока не восстановится
	  до 25 (одышка — cl_stamina.lua);
	- ранения (меньше 35 HP) замедляют.
]]

local M = SCP.Config.Movement
local ST = SCP.Config.Stamina

if SERVER then
	function SCP.ApplyMovement(ply)
		ply:SetWalkSpeed(M.Walk)
		ply:SetRunSpeed(M.Run)
		ply:SetSlowWalkSpeed(M.SlowWalk)
		ply:SetCrouchedWalkSpeed(M.Crouch)
		ply:SetJumpPower(M.Jump)
		ply:SetDuckSpeed(0.32)
		ply:SetUnDuckSpeed(0.32)
		ply:SetLadderClimbSpeed(110)
	end
end

function SCP.Stamina.Get(ply)
	return ply:GetNW2Float("scp.stamina", ST.Max)
end

function SCP.Stamina.Exhausted(ply)
	return ply:GetNW2Bool("scp.exhausted", false)
end

local function sprinting(ply, mv)
	return mv:KeyDown(IN_SPEED) and ply:OnGround() and mv:GetVelocity():Length2DSqr() > 90 * 90
		and not ply:Crouching() and mv:GetForwardSpeed() > 0
end

hook.Add("OnPlayerHitGround", "scp.movement", function(ply, inWater, onFloater, speed)
	ply.scpLanded = CurTime()
	ply.scpLandSpeed = speed
end)

hook.Add("SetupMove", "scp.movement", function(ply, mv, cmd)
	if ply:GetMoveType() ~= MOVETYPE_WALK then return end
	if not ply:InGame() then return end

	local max = mv:GetMaxClientSpeed()
	local exhausted = SCP.Stamina.Exhausted(ply)

	if mv:KeyDown(IN_SPEED) and exhausted then
		max = math.min(max, ply:GetWalkSpeed())
	end
	-- бег спиной и боком
	if mv:KeyDown(IN_SPEED) and mv:GetForwardSpeed() <= 0 then
		max = math.min(max, ply:GetRunSpeed() * M.BackwardFactor)
	end
	-- ранен — медленнее
	local hp = ply:Health()
	if hp < 35 then max = max * Lerp(hp / 35, 0.72, 1) end

	-- приземление: замедление и пауза перед прыжком
	local since = CurTime() - (ply.scpLanded or 0)
	if since < 0.4 then
		local hard = math.Clamp(((ply.scpLandSpeed or 0) - 200) / 400, 0, 1)
		max = max * Lerp(since / 0.4, Lerp(hard, M.LandSlowdown + 0.2, M.LandSlowdown), 1)
	end
	if since < M.JumpCooldown and ply:OnGround() then
		mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
	end
	-- нет сил — не прыгнуть
	if SCP.Stamina.Get(ply) < ST.JumpCost and ply:OnGround() then
		mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
	end

	mv:SetMaxClientSpeed(max)
	mv:SetMaxSpeed(math.min(mv:GetMaxSpeed(), max))

	-- выносливость считает сервер
	if SERVER then
		local st = SCP.Stamina.Get(ply)
		local dt = FrameTime()
		if sprinting(ply, mv) and not exhausted then
			st = st - ST.SprintDrain * dt
			ply.scpStaminaUsed = CurTime()
		elseif CurTime() - (ply.scpStaminaUsed or 0) > ST.RegenDelay then
			local still = mv:GetVelocity():Length2DSqr() < 10
			st = st + ST.Regen * dt * (still and 1.4 or 1) * (ply:Crouching() and 1.2 or 1)
		end
		if mv:KeyPressed(IN_JUMP) and ply:OnGround() then
			st = st - ST.JumpCost
			ply.scpStaminaUsed = CurTime()
		end
		st = math.Clamp(st, 0, ST.Max)
		if st <= 0 and not exhausted then ply:SetNW2Bool("scp.exhausted", true) end
		if exhausted and st >= ST.Exhausted then ply:SetNW2Bool("scp.exhausted", false) end
		if math.abs(st - SCP.Stamina.Get(ply)) > 0.05 then ply:SetNW2Float("scp.stamina", st) end
	end
end)
