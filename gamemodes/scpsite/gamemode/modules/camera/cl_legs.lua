--[[
	Ноги от первого лица.
	Основа — плагин «Legs» (Valkyrie & blackops7799, public domain / Unlicense), переделан под режим:
	без Helix, свой convar scp_legs, рисуется только на задании.
]]

CreateClientConVar("scp_legs", "1", true, false, "Показывать ноги от первого лица")

local Legs = {}
SCP.Legs = Legs

local function ShouldDrawLegs()
	if hook.Run("ShouldDisableLegs") == true then return false end
	if not GetConVar("scp_legs"):GetBool() then return false end
	local client = LocalPlayer()
	return IsValid(Legs.LegEnt) and client:Alive() and SCP.MyState() == "playing" and not client:InVehicle()
		and GetViewEntity() == client and not client:ShouldDrawLocalPlayer() and not IsValid(client:GetObserverTarget())
		and not client:GetNoDraw() and client:GetMoveType() ~= MOVETYPE_NOCLIP
end

function Legs:Setup(model)
	model = model or LocalPlayer():GetModel()
	if not IsValid(self.LegEnt) then
		self.LegEnt = ClientsideModel(model, RENDER_GROUP_OPAQUE_ENTITY)
	else
		self.LegEnt:SetModel(model)
	end
	if not IsValid(self.LegEnt) then return end
	self.LegEnt:SetNoDraw(true)
	local me = LocalPlayer()
	for _, v in pairs(me:GetBodyGroups()) do
		self.LegEnt:SetBodygroup(v.id, me:GetBodygroup(v.id))
	end
	for k in ipairs(me:GetMaterials()) do
		self.LegEnt:SetSubMaterial(k - 1, me:GetSubMaterial(k - 1))
	end
	self.LegEnt:SetSkin(me:GetSkin())
	self.LegEnt:SetMaterial(me:GetMaterial())
	self.LegEnt:SetColor(me:GetColor())
	self.LegEnt.GetPlayerColor = function() return LocalPlayer():GetPlayerColor() end
	self.LegEnt.Anim = nil
	self.LegEnt.LastTick = 0
	self.Model = model
	self.PlaybackRate = 1
	self.Sequence = nil
	self.Velocity = 0
	self:FixBones()
	self:Update(0)
end

function Legs:Update(maxSeqGroundSpeed)
	if not IsValid(self.LegEnt) then return end
	local me = LocalPlayer()
	self.Velocity = me:GetVelocity():Length2D()
	self.PlaybackRate = 1
	if self.Velocity > 0.5 then
		if maxSeqGroundSpeed < 0.001 then
			self.PlaybackRate = 0.01
		else
			self.PlaybackRate = math.Clamp(self.Velocity / maxSeqGroundSpeed, 0.01, 10)
		end
	end
	self.LegEnt:SetPlaybackRate(self.PlaybackRate)
	self.Sequence = me:GetSequence()
	if self.LegEnt.Anim ~= self.Sequence then
		self.LegEnt.Anim = self.Sequence
		self.LegEnt:ResetSequence(self.Sequence)
	end
	self.LegEnt:FrameAdvance(CurTime() - self.LegEnt.LastTick)
	self.LegEnt.LastTick = CurTime()
	self.LegEnt:SetPoseParameter("move_x", (me:GetPoseParameter("move_x") * 2) - 1)
	self.LegEnt:SetPoseParameter("move_y", (me:GetPoseParameter("move_y") * 2) - 1)
	self.LegEnt:SetPoseParameter("move_yaw", (me:GetPoseParameter("move_yaw") * 360) - 180)
	self.LegEnt:SetPoseParameter("body_yaw", (me:GetPoseParameter("body_yaw") * 180) - 90)
	self.LegEnt:SetPoseParameter("spine_yaw", (me:GetPoseParameter("spine_yaw") * 180) - 90)
end

local ClipVector = vector_up * -1

function Legs:Render()
	if not ShouldDrawLegs() then return end
	local me = LocalPlayer()
	local pos = me:GetPos()
	local yaw = me:EyeAngles().y
	local rad = math.rad(yaw)
	local fwd = -22
	pos.x = pos.x + math.cos(rad) * fwd
	pos.y = pos.y + math.sin(rad) * fwd
	if me:GetGroundEntity() == NULL then
		pos.z = pos.z + 8
		if me:KeyDown(IN_DUCK) then pos.z = pos.z - 28 end
	end
	local col = me:GetColor()
	cam.Start3D(EyePos(), EyeAngles())
	local was = render.EnableClipping(true)
	render.PushCustomClipPlane(ClipVector, ClipVector:Dot(EyePos()))
	render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
	render.SetBlend(col.a / 255)
	self.LegEnt:SetRenderOrigin(pos)
	self.LegEnt:SetRenderAngles(Angle(0, yaw, 0))
	self.LegEnt:SetupBones()
	self.LegEnt:DrawModel()
	self.LegEnt:SetRenderOrigin()
	self.LegEnt:SetRenderAngles()
	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
	render.PopCustomClipPlane()
	render.EnableClipping(was)
	cam.End3D()
end

local removeBones = {
	"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Neck1",
	"ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Upperarm", "ValveBiped.Bip01_L_Clavicle",
	"ValveBiped.Bip01_R_Hand", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Upperarm", "ValveBiped.Bip01_R_Clavicle",
	"ValveBiped.Bip01_Spine4", "ValveBiped.Bip01_Spine2",
}
for _, side in ipairs({ "L", "R" }) do
	for f = 0, 4 do
		for _, s in ipairs({ "", "1", "2" }) do
			removeBones[#removeBones + 1] = "ValveBiped.Bip01_" .. side .. "_Finger" .. f .. s
		end
	end
end

function Legs:FixBones()
	if not IsValid(self.LegEnt) then return end
	for i = 0, self.LegEnt:GetBoneCount() - 1 do
		self.LegEnt:ManipulateBoneScale(i, Vector(1, 1, 1))
		self.LegEnt:ManipulateBonePosition(i, vector_origin)
	end
	for _, v in ipairs(removeBones) do
		local bone = self.LegEnt:LookupBone(v)
		if bone then
			self.LegEnt:ManipulateBoneScale(bone, vector_origin)
			self.LegEnt:ManipulateBonePosition(bone, Vector(0, -100, 0))
			self.LegEnt:ManipulateBoneAngles(bone, angle_zero)
		end
	end
end

hook.Add("UpdateAnimation", "scp.legs", function(ply, velocity, maxSeqGroundSpeed)
	if ply ~= LocalPlayer() then return end
	if not IsValid(Legs.LegEnt) or Legs.Model ~= ply:GetModel() then
		Legs:Setup(ply:GetModel())
	else
		Legs:Update(maxSeqGroundSpeed)
	end
end)

hook.Add("PlayerSwitchWeapon", "scp.legs", function(ply)
	if ply == LocalPlayer() and IsValid(Legs.LegEnt) then
		timer.Simple(0, function() Legs:FixBones() end)
	end
end)

hook.Add("PostDrawTranslucentRenderables", "scp.legs", function(depth, sky)
	if sky or depth then return end
	Legs:Render()
end)
