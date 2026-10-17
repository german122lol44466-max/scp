--[[
	Метки в мире: цель этапа и сюжетные предметы (карты доступа, предохранители, образцы).
	Ромб с иконкой и кольцом, название и расстояние; за краем экрана — стрелка по направлению.
	Цель «продержаться» — кольцо прогресса. Отключаются в настройках (scp_markers 0).
]]

local UI = SCP.UI
local S = SCP.Story
local Set = SCP.Settings

local kindIcon = { reach = "map_pin", use = "hand", collect = "key", survive = "shield" }

-- Экранная позиция; за экраном — прижимаем к краю (возвращает x, y, onScreen, угол стрелки)
local function project(pos)
	local sc = pos:ToScreen()
	local x, y = sc.x, sc.y
	local margin = UI.S(60)
	local on = sc.visible and x > margin and x < ScrW() - margin and y > margin and y < ScrH() - margin
	if on then return x, y, true end
	local dir = (pos - EyePos()):GetNormalized()
	local ang = EyeAngles()
	local rx, ry = dir:Dot(ang:Right()), -dir:Dot(ang:Up())
	if dir:Dot(ang:Forward()) < 0 and math.abs(rx) < 0.2 then rx = rx < 0 and -1 or 1 end
	local len = math.sqrt(rx * rx + ry * ry)
	if len < 0.001 then rx, ry, len = 0, 1, 1 end
	rx, ry = rx / len, ry / len
	local kx = (ScrW() / 2 - margin) / math.max(math.abs(rx), 0.001)
	local ky = (ScrH() / 2 - margin) / math.max(math.abs(ry), 0.001)
	local k = math.min(kx, ky)
	return ScrW() / 2 + rx * k, ScrH() / 2 + ry * k, false, math.deg(math.atan2(ry, rx))
end

local function diamond(x, y, s, col)
	draw.NoTexture()
	surface.SetDrawColor(col)
	surface.DrawPoly({ { x = x, y = y - s }, { x = x + s, y = y }, { x = x, y = y + s }, { x = x - s, y = y } })
end

local function marker(pos, icon, label, col, opts)
	opts = opts or {}
	local d = EyePos():Distance(pos)
	local x, y, on, arrow = project(pos)
	local near = math.Clamp((d - (opts.hideNear or 90)) / 160, 0, 1)
	if near <= 0 then return end
	local pulse = 0.5 + 0.5 * math.sin(RealTime() * 3 + (opts.phase or 0))
	local s = UI.S(opts.small and 11 or 15)
	local a = near * (opts.alpha or 1)
	surface.SetAlphaMultiplier(a)
	-- ореол и пульс
	UI.Glow(x, y, s * 7, s * 7, Color(col.r, col.g, col.b, 40))
	UI.Ring(x, y, s * (1.6 + pulse * 0.5), Color(col.r, col.g, col.b, 120 * (1 - pulse)))
	diamond(x, y, s + UI.S(3), Color(0, 0, 0, 170))
	diamond(x, y, s, Color(col.r, col.g, col.b, 235))
	UI.DrawIcon(icon, x, y, s * 1.0, Color(14, 14, 16))
	if opts.progress then
		-- кольцо прогресса из точек
		local n = 32
		for i = 1, math.floor(n * opts.progress) do
			local ang = math.rad(i / n * 360 - 90)
			UI.Circle(x + math.cos(ang) * s * 2.1, y + math.sin(ang) * s * 2.1, UI.S(2), col)
		end
	end
	if not on and arrow then
		local r = math.rad(arrow)
		local ax, ay = x + math.cos(r) * s * 2.2, y + math.sin(r) * s * 2.2
		local px, py = -math.sin(r), math.cos(r)
		draw.NoTexture()
		surface.SetDrawColor(col)
		surface.DrawPoly({ { x = ax + math.cos(r) * UI.S(8), y = ay + math.sin(r) * UI.S(8) }, { x = ax + px * UI.S(6), y = ay + py * UI.S(6) }, { x = ax - px * UI.S(6), y = ay - py * UI.S(6) } })
	end
	if label and (on or not opts.small) then
		draw.SimpleTextOutlined(label, SCP.Font("semibold", opts.small and 11 or 13), x, y - s - UI.S(14), Color(240, 238, 232), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 170))
	end
	draw.SimpleTextOutlined(math.Round(d / 52.5) .. " м", SCP.Font("monobold", 11), x, y + s + UI.S(14), Color(230, 230, 224), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 170))
	surface.SetAlphaMultiplier(1)
end

hook.Add("HUDPaint", "scp.markers", function()
	if not SCP.HUD.Playing() or not S.State.running or not Set.Bool("markers") then return end
	local st = S.Current()
	if not st then return end
	local gold = Color(236, 186, 64)
	-- цель
	if S.State.goalPos then
		marker(S.State.goalPos + Vector(0, 0, st.kind == "use" and 10 or 50), kindIcon[st.kind] or "map_pin", string.upper(st.pointName or st.title), gold,
			{ progress = st.kind == "survive" and (S.State.progress or 0) or nil })
	end
	-- предметы, которые нужно собрать
	if st.kind == "collect" then
		local def = SCP.Items.Defs[st.item]
		local col = def and def.color or gold
		for i, e in ipairs(ents.FindByClass("scp_pickup")) do
			if e:GetItemID() == st.item and e:GetPos():DistToSqr(EyePos()) < 5000 * 5000 then
				marker(e:WorldSpaceCenter() + Vector(0, 0, 14), def and def.icon or "item", def and string.upper(def.name) or nil, col,
					{ small = true, phase = i, hideNear = 50 })
			end
		end
	end
end)
