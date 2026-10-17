--[[
	Диалоги: реплики показываются окном диалога снизу (имя, роль, текст «печатается»).
	Источники: бойцы отряда (фразы, команды, крики на G), Командование по рации, мысли персонажа.

	G — круговое меню «Фонд»: настоящие реплики МОГ Эпсилон-11 из SCP – Containment Breach
	(звук — оригинальный голос, текст — перевод). Слышно вокруг, громко.
]]

local DG = {}
SCP.Dialog = DG

DG.Shouts = {
	{ text = "Стоять! Ни с места!", icon = "hand", sub = "ЭПСИЛОН-11", snd = "stop", n = 6 },
	{ text = "Вот он!", icon = "eye", sub = "ЭПСИЛОН-11", snd = "thereheis", n = 6 },
	{ text = "Моргаю!", icon = "eye", sub = "ПРОТОКОЛ 173", snd = "blinking", n = 1 },
	{ text = "Вижу SCP-173!", icon = "warning", sub = "ЭПСИЛОН-11", snd = "173_spotted", n = 3 },
	{ text = "Вижу SCP-096! Не смотреть!", icon = "warning", sub = "ЭПСИЛОН-11", snd = "096_spotted", n = 2 },
	{ text = "Вижу SCP-049!", icon = "warning", sub = "ЭПСИЛОН-11", snd = "049_spotted", n = 5 },
	{ text = "Прочёсываем сектор.", icon = "map_pin", sub = "ЭПСИЛОН-11", snd = "searching", n = 6 },
	{ text = "Цель потеряна.", icon = "close", sub = "ЭПСИЛОН-11", snd = "targetlost", n = 3 },
	{ text = "Цель ликвидирована.", icon = "skull", sub = "ЭПСИЛОН-11", snd = "terminated", n = 4 },
	{ text = "Объект сдержан!", icon = "check", sub = "ЭПСИЛОН-11", snd = "contained", n = 4 },
}

-- Как подписывать говорящего
DG.Roles = {
	command = { name = "Командование", role = "РАДИОСВЯЗЬ · О5", icon = "radio", col = Color(230, 180, 60) },
	pa = { name = "Система оповещения", role = "ГРОМКАЯ СВЯЗЬ ОБЪЕКТА", icon = "volume", col = Color(206, 52, 46) },
	self = { name = "Мысли", role = "", icon = "user", col = Color(150, 152, 158) },
}

DG.Range = 1100
