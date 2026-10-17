--[[
	Инвентарь на сервере. ply.scpInv = { [slot] = { id, n, data } }
]]

local I = SCP.Items

function I.Sync(ply)
	net.Start("scp.inv.sync")
	net.WriteTable(ply.scpInv or {})
	net.Send(ply)
end

function I.Reset(ply)
	ply.scpInv = {}
	I.Sync(ply)
end

function I.Count(ply, id)
	local n = 0
	for _, it in pairs(ply.scpInv or {}) do if it.id == id then n = n + it.n end end
	return n
end

function I.Give(ply, id, n, data)
	local def = I.Defs[id]
	if not def then return false end
	ply.scpInv = ply.scpInv or {}
	n = n or 1
	-- в существующую стопку (без данных)
	if not data then
		for s = 1, I.Slots do
			local it = ply.scpInv[s]
			if it and it.id == id and not it.data and it.n < def.stack then
				local add = math.min(def.stack - it.n, n)
				it.n = it.n + add
				n = n - add
				if n <= 0 then I.Sync(ply) return true end
			end
		end
	end
	for s = 1, I.Slots do
		if not ply.scpInv[s] then
			ply.scpInv[s] = { id = id, n = math.min(n, def.stack), data = data }
			n = n - def.stack
			if n <= 0 then I.Sync(ply) return true end
		end
	end
	I.Sync(ply)
	return false
end

function I.Take(ply, slot, n)
	local it = ply.scpInv and ply.scpInv[slot]
	if not it then return end
	it.n = it.n - (n or 1)
	if it.n <= 0 then ply.scpInv[slot] = nil end
	I.Sync(ply)
end

-- Использование
I.Use = {
	medkit = function(ply)
		if ply:Health() >= ply:GetMaxHealth() then SCP.Notify(ply, "Вы не ранены.", "info") return false end
		ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + 40))
		ply:EmitSound("items/medshot4.wav", 60)
		return true
	end,
	ammo = function(ply)
		local w = ply:GetActiveWeapon()
		if not IsValid(w) or w:GetPrimaryAmmoType() < 0 then return false end
		ply:GiveAmmo(math.max(w:GetMaxClip1(), 30) * 2, w:GetPrimaryAmmoType())
		return true
	end,
}

net.Receive("scp.inv.use", function(_, ply)
	local slot = net.ReadUInt(5)
	local it = ply.scpInv and ply.scpInv[slot]
	if not it or not ply:InGame() or not ply:Alive() then return end
	local fn = I.Use[it.id]
	if fn and fn(ply, it) then I.Take(ply, slot, 1) end
end)

net.Receive("scp.inv.drop", function(_, ply)
	local slot = net.ReadUInt(5)
	local it = ply.scpInv and ply.scpInv[slot]
	if not it or not ply:InGame() or not ply:Alive() then return end
	local def = I.Defs[it.id]
	if not def then return end
	if def.story then SCP.Notify(ply, "Сюжетный предмет нельзя выбросить.", "warn") return end
	local tr = util.TraceLine({ start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector() * 60, filter = ply })
	local e = ents.Create("scp_pickup")
	e:SetItem(it.id, it.data)
	e:SetPos(tr.HitPos + tr.HitNormal * 6)
	e:Spawn()
	I.Take(ply, slot, 1)
end)

hook.Add("PlayerInitialSpawn", "scp.items", function(ply) ply.scpInv = {} end)
