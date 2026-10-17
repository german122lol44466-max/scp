--[[
	Предметы. Инвентарь — 12 ячеек, сбрасывается в начале и в конце задания.
	story = true — сюжетный предмет: нельзя выбросить.
]]

local I = SCP.Items
I.Slots = 12

I.Defs = {
	keycard = {
		name = "Карта доступа", icon = "key", story = true, stack = 5,
		desc = "Карта доступа третьего уровня. Нужна для пульта изоляции сектора.",
		model = "models/props_c17/paper01.mdl", color = Color(255, 210, 90),
	},
	fuse = {
		name = "Предохранитель", icon = "bolt", story = true, stack = 5,
		desc = "Высоковольтный предохранитель клетки сдерживания. Тяжёлый и тёплый.",
		model = "models/items/battery.mdl", color = Color(140, 200, 255),
	},
	sample = {
		name = "Образец SCP-049", icon = "flask", story = true, stack = 5,
		desc = "Колба с «лекарством» Чумного доктора. Не открывать.",
		model = "models/healthvial.mdl", color = Color(160, 255, 140),
	},
	note = {
		name = "Документ", icon = "clipboard", stack = 1,
		desc = "Служебная записка. Можно прочитать.",
		model = "models/props_lab/clipboard.mdl",
	},
	medkit = {
		name = "Аптечка", icon = "medkit", stack = 3,
		desc = "Перевязочный пакет и стимулятор. Восстанавливает 40 здоровья.",
		model = "models/items/healthkit.mdl",
	},
	ammo = {
		name = "Магазины", icon = "box", stack = 4,
		desc = "Два магазина к основному оружию.",
		model = "models/items/boxmrounds.mdl",
	},
}

function I.Name(id, data)
	local d = I.Defs[id]
	if not d then return id end
	if id == "note" and data and data.note and SCP.Notes[data.note] then return SCP.Notes[data.note].title end
	return d.name
end
