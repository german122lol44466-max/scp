--[[
	Клиент: убираем всё стандартное (HUD, подсказки, ники, килфид, панели песочницы),
	Q — инвентарь, C — только в редакторе. Свой курсор и прочее — в других модулях.
]]

SCP.State = SCP.State or "menu"

function SCP.MyState()
	local me = LocalPlayer()
	if not IsValid(me) then return "menu" end
	if SCP.InEdit(me) then return "edit" end
	return me:SCPState()
end

local hide = {
	CHudHealth = true, CHudBattery = true, CHudAmmo = true, CHudSecondaryAmmo = true, CHudCrosshair = true,
	CHudDamageIndicator = true, CHudWeaponSelection = true, CHudChat = true, CHudDeathNotice = true,
	CHudVoiceStatus = true, CHudVoiceSelfStatus = true, CHudSuitPower = true, CHudPoisonDamageIndicator = true,
	CHudGeiger = true, CHudTrain = true, CHudHintDisplay = true, CHudHistoryResource = true, CHudQuickInfo = true,
	CHudSquadStatus = true, CHudZoom = true, CHudMessage = true, CHudGMod = false,
}

function GM:HUDShouldDraw(name)
	if hide[name] then
		-- в редакторе оставим патроны и выбор оружия (физган/тулган)
		if SCP.MyState() == "edit" and (name == "CHudAmmo" or name == "CHudWeaponSelection" or name == "CHudCrosshair") then
			return true
		end
		return false
	end
	return true
end

function GM:HUDDrawTargetID() end
function GM:DrawDeathNotice() end
function GM:AddDeathNotice() end
function GM:HUDDrawPickupHistory() end
function GM:HUDWeaponPickedUp() end
function GM:HUDItemPickedUp() end
function GM:HUDAmmoPickedUp() end
function GM:PaintNotes() end
function GM:AddHint() end
function GM:SuppressHint() return true end

-- Q: инвентарь (в редакторе — обычное спавн-меню)
-- Q: короткое нажатие — личное дело, удержание — выглядывание влево (modules/lean)
function GM:OnSpawnMenuOpen()
	if SCP.MyState() == "edit" then return self.BaseClass.OnSpawnMenuOpen(self) end
	if IsValid(SCP.Inv.Panel) then SCP.Inv.Close() return end
	SCP.Camera.QPressed()
end

function GM:OnSpawnMenuClose()
	if SCP.MyState() == "edit" then return self.BaseClass.OnSpawnMenuClose(self) end
	if SCP.Camera.QReleased() and SCP.MyState() == "playing" and LocalPlayer():Alive() then SCP.Inv.Open() end
end

function GM:OnContextMenuOpen()
	if SCP.MyState() == "edit" then return self.BaseClass.OnContextMenuOpen(self) end
end

function GM:OnContextMenuClose()
	if SCP.MyState() == "edit" then return self.BaseClass.OnContextMenuClose(self) end
end

-- В меню/лобби игровые бинды (кроме голоса, чата и консоли) не работают
local allowedInMenu = { ["+voicerecord"] = true, ["-voicerecord"] = true, messagemode = true, messagemode2 = true,
	toggleconsole = true, cancelselect = true, ["+showscores"] = true, ["-showscores"] = true }

function GM:PlayerBindPress(ply, bind, pressed)
	local st = SCP.MyState()
	if st == "menu" or st == "lobby" then
		local cmd = string.match(bind, "^%S+")
		if not allowedInMenu[cmd] then return true end
	end
	return self.BaseClass.PlayerBindPress and self.BaseClass.PlayerBindPress(self, ply, bind, pressed)
end

hook.Add("InitPostEntity", "scp.base", function()
	RunConsoleCommand("cl_showhints", "0")
end)

-- Сервер вернул в меню/лобби
net.Receive("scp.menu.state", function()
	timer.Simple(0.1, function() if SCP.Menu.Sync then SCP.Menu.Sync() end end)
end)
