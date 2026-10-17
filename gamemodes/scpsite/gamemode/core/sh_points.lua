--[[
	Точки карты: камеры меню, спавны, цели сюжета, предметы.
	Хранятся на сервере в data/scpsite/points/<карта>.json и не теряются после перезапуска.
	Расставляются в редакторе: команда scp_edit (суперадмин).

	single = true — одна точка (новая заменяет старую), иначе их может быть много.
	cam = true — сохраняется вид камеры (позиция глаз + направление взгляда), иначе позиция ног + поворот.
]]

local P = SCP.Points

P.Types = {
	{ id = "menu_cam", name = "Камера главного меню", single = true, cam = true, col = Color(110, 160, 220), group = "Меню" },
	{ id = "lobby_cam", name = "Камера лобби", single = true, cam = true, col = Color(110, 160, 220), group = "Меню" },
	{ id = "spawn", name = "Спавн отряда", col = Color(110, 196, 120), group = "Игра", need = 1 },
	{ id = "npc_096", name = "SCP-096 (камера содержания)", single = true, col = Color(206, 52, 46), group = "Сюжет", need = 1 },
	{ id = "obj_command", name = "Цель 1 — пост охраны", single = true, col = Color(230, 180, 60), group = "Сюжет", need = 1 },
	{ id = "obj_generator", name = "Цель 2 — генератор", single = true, col = Color(230, 180, 60), group = "Сюжет", need = 1 },
	{ id = "item_keycard", name = "Цель 3 — карта доступа (3+)", col = Color(230, 180, 60), group = "Сюжет", need = 3 },
	{ id = "obj_lockdown", name = "Цель 4 — пульт изоляции", single = true, col = Color(230, 180, 60), group = "Сюжет", need = 1 },
	{ id = "obj_exit", name = "Цель 5 — точка эвакуации", single = true, col = Color(230, 180, 60), group = "Сюжет", need = 1 },
	{ id = "note", name = "Документ (записка)", col = Color(200, 200, 200), group = "Предметы" },
	{ id = "medkit", name = "Аптечка", col = Color(200, 200, 200), group = "Предметы" },
	{ id = "ammo", name = "Патроны", col = Color(200, 200, 200), group = "Предметы" },
}

P.ByID = {}
for i, t in ipairs(P.Types) do t.index = i P.ByID[t.id] = t end

P.Data = P.Data or {}   -- [id] = { {pos = Vector, ang = Angle}, ... }

function P.Get(id) return P.Data[id] or {} end
function P.First(id) return (P.Data[id] or {})[1] end
function P.Count(id) return #(P.Data[id] or {}) end

-- Чего не хватает для сюжета (для подсказки админу).
function P.Missing()
	local out = {}
	for _, t in ipairs(P.Types) do
		if t.need and P.Count(t.id) < t.need then out[#out + 1] = t end
	end
	return out
end

function SCP.InEdit(ply)
	return IsValid(ply) and ply:GetNW2Bool("scp.edit", false)
end
