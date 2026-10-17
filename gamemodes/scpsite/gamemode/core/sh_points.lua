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
	{ id = "spawn", name = "Спавн отряда — охрана (глава I)", col = Color(110, 196, 120), group = "Спавны и SCP", need = 1 },
	{ id = "spawn_mtf", name = "Спавн отряда — МОГ (главы II–V)", col = Color(96, 140, 210), group = "Спавны и SCP", need = 1 },
	{ id = "npc_096", name = "SCP-096 (камера содержания)", single = true, col = Color(206, 52, 46), group = "Спавны и SCP", need = 1 },
	{ id = "npc_173", name = "SCP-173 (камера содержания)", single = true, col = Color(206, 52, 46), group = "Спавны и SCP", need = 1 },
	{ id = "npc_049", name = "SCP-049 (камера содержания)", single = true, col = Color(206, 52, 46), group = "Спавны и SCP", need = 1 },
	{ id = "scp_roam", name = "Точки блуждания SCP (куда они переходят)", col = Color(160, 60, 56), group = "Спавны и SCP" },
	{ id = "note", name = "Документ (записка)", col = Color(200, 200, 200), group = "Предметы и атмосфера" },
	{ id = "medkit", name = "Аптечка", col = Color(200, 200, 200), group = "Предметы и атмосфера" },
	{ id = "ammo", name = "Патроны", col = Color(200, 200, 200), group = "Предметы и атмосфера" },
	{ id = "ambient", name = "Источник звука комплекса (гул, капли, вентиляция)", col = Color(140, 140, 160), group = "Предметы и атмосфера" },
	{ id = "flicker", name = "Мигающая лампа", col = Color(255, 230, 160), group = "Предметы и атмосфера" },
}

P.ByID = {}

-- Регистрация типа точки из модулей (сюжет добавляет точки своих этапов и катсцен).
function P.Register(t)
	if P.ByID[t.id] then return end
	P.Types[#P.Types + 1] = t
	t.index = #P.Types
	P.ByID[t.id] = t
end

for i, t in ipairs(P.Types) do t.index = i P.ByID[t.id] = t end

P.Data = P.Data or {}   -- [id] = { {pos = Vector, ang = Angle}, ... }

function P.Get(id) return P.Data[id] or {} end
function P.First(id) return (P.Data[id] or {})[1] end
function P.Count(id) return #(P.Data[id] or {}) end

-- Чего не хватает (для подсказки админу). chapter — только для этой главы (и общие точки).
function P.Missing(chapter)
	local out = {}
	for _, t in ipairs(P.Types) do
		if t.need and P.Count(t.id) < t.need and (not chapter or not t.chapter or t.chapter == chapter) then
			out[#out + 1] = t
		end
	end
	return out
end

function SCP.InEdit(ply)
	return IsValid(ply) and ply:GetNW2Bool("scp.edit", false)
end
