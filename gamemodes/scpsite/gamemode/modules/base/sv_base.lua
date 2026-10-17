--[[
	Жизненный цикл игрока:
	  menu / lobby — игрок «призрак»: невидим, без оружия, стоит у камеры меню (чтобы карта вокруг была прогружена);
	  playing      — модель охраны, P90, спавн на точках отряда;
	  edit         — редактор (modules/editor).
	Песочница выключена для всех, кроме редактора.
]]

local P = SCP.Points

function GM:PlayerInitialSpawn(ply)
	ply:SetNW2String("scp.state", "menu")
	local d = SCP.Data.Of(ply)
	if d.name then ply:SetNW2String("scp.name", d.name) end
	ply:SetNW2Int("scp.model", d.model or math.random(#SCP.Config.Models))
	ply:SetTeam(TEAM_UNASSIGNED)
end

local function ghost(ply)
	ply:StripWeapons()
	ply:SetNoDraw(true)
	ply:SetNotSolid(true)
	ply:DrawShadow(false)
	ply:GodEnable()
	ply:SetMoveType(MOVETYPE_NONE)
	ply:SetAvoidPlayers(false)
	ply:Flashlight(false)
	local cam = P.First(ply:SCPState() == "lobby" and "lobby_cam" or "menu_cam") or P.First("menu_cam")
	if cam then ply:SetPos(cam.pos - Vector(0, 0, 64)) end
end

function GM:PlayerSpawn(ply, transition)
	player_manager.SetPlayerClass(ply, "player_default")
	ply:UnSpectate()
	ply:SetNoDraw(false)
	ply:SetNotSolid(false)
	ply:DrawShadow(true)
	ply:GodDisable()
	ply:SetMoveType(MOVETYPE_WALK)
	ply:SetAvoidPlayers(true)
	ply:Freeze(false)

	local state = ply:SCPState()
	if state ~= "playing" and state ~= "edit" then
		ghost(ply)
		return
	end

	self:PlayerSetModel(ply)
	ply:SetupHands()
	ply:SetHealth(100)
	ply:SetMaxHealth(100)
	ply:SetArmor(state == "playing" and 50 or 0)
	SCP.ApplyMovement(ply)
	ply:SetNW2Float("scp.stamina", SCP.Config.Stamina.Max)
	ply:SetNW2Bool("scp.dead", false)

	if state == "playing" then
		local where = SCP.Story.SpawnPoint and SCP.Story.SpawnPoint(ply)
		if where then
			ply:SetPos(where.pos)
			ply:SetEyeAngles(where.ang)
		end
		timer.Simple(0, function()
			if IsValid(ply) and ply:InGame() then hook.Run("PlayerLoadout", ply) end
		end)
	end
end

function GM:PlayerSetModel(ply)
	local mdl = SCP.Lobby.ModelOf(ply)
	util.PrecacheModel(mdl)
	ply:SetModel(mdl)
	ply:SetPlayerColor(Vector(0.25, 0.27, 0.3))
	SCP.Data.Set(ply, "model", ply:GetNW2Int("scp.model", 1))
end

function GM:PlayerLoadout(ply)
	if not ply:InGame() then return true end
	ply:StripWeapons()
	ply:StripAmmo()
	for _, cls in ipairs(SCP.Config.Weapons) do
		local w = ply:Give(cls)
		if IsValid(w) then
			local clip = w:GetMaxClip1() > 0 and w:GetMaxClip1() or 50
			ply:GiveAmmo(clip * SCP.Config.SpareMags, w:GetPrimaryAmmoType(), true)
		else
			print("[SCP] Нет оружия " .. cls .. " — установите аддон TFA с ним на сервер.")
		end
	end
	if #SCP.Config.Weapons > 0 then ply:SelectWeapon(SCP.Config.Weapons[1]) end
	return true
end

-- Сюжет сам решает, когда воскрешать (между главами / в конце).
function GM:PlayerDeathThink(ply)
	local state = ply:SCPState()
	if state == "edit" then
		if ply:KeyPressed(IN_ATTACK) or ply:KeyPressed(IN_JUMP) then ply:Spawn() end
		return
	end
	if state ~= "playing" then ply:Spawn() end
	return false
end

-- Звук «flatline» и прочее из базового режима не нужны.
function GM:PlayerDeathSound() return true end
function GM:CanPlayerSuicide(ply) return ply:InGame() end

-- Урон только на задании; друг по другу — вполовину.
function GM:PlayerShouldTakeDamage(ply, attacker)
	if not ply:InGame() then return SCP.InEdit(ply) end
	if IsValid(attacker) and attacker:IsPlayer() and attacker ~= ply then return true end
	return true
end

hook.Add("ScalePlayerDamage", "scp.ff", function(ply, hit, dmg)
	local att = dmg:GetAttacker()
	if IsValid(att) and att:IsPlayer() and att ~= ply then dmg:ScaleDamage(0.5) end
end)

-- ---------------------------------------------------- песочница — только в редакторе --
local function sandboxOnly(ply) return SCP.InEdit(ply) end
for _, name in ipairs({ "PlayerSpawnProp", "PlayerSpawnEffect", "PlayerSpawnRagdoll", "PlayerSpawnNPC",
	"PlayerSpawnSENT", "PlayerSpawnSWEP", "PlayerGiveSWEP", "PlayerSpawnVehicle", "PlayerSpawnObject", "CanTool",
	"CanProperty", "CanDrive" }) do
	GM[name] = function(self, ply) return sandboxOnly(ply) end
end
function GM:PlayerNoClip(ply) return SCP.InEdit(ply) end
function GM:PhysgunPickup(ply, ent)
	if not SCP.InEdit(ply) then return false end
	return self.BaseClass.PhysgunPickup(self, ply, ent)
end

-- Фонарик есть у охраны всегда
function GM:PlayerSwitchFlashlight(ply, on) return not on or ply:InGame() or SCP.InEdit(ply) end

-- Выйти в меню (из сюжета по окончании или из редактора).
SCP.Menu.ToMenu = function(ply)
	ply:SetNW2Bool("scp.edit", false)
	ply:SetNW2String("scp.state", ply:SCPLobby() > 0 and "lobby" or "menu")
	ply:Spawn()
	net.Start("scp.menu.state")
	net.Send(ply)
end
