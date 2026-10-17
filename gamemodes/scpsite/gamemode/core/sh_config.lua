--[[
	Настройки режима. Всё, что может захотеть поменять владелец сервера, — здесь.
]]

local C = SCP.Config

-- Фракции: модели (выбор стрелками в лобби) и снаряжение. Фракцию задаёт глава.
C.Factions = {
	security = {
		name = "Служба безопасности",
		short = "СБ",
		color = Color(150, 160, 175),
		clearance = 2,
		models = {
			"models/arty/codmw2022/sp/mexican federal police/grunts/SCP_OZ_Security_1.mdl",
			"models/arty/codmw2022/sp/mexican federal police/grunts/SCP_OZ_Security_2.mdl",
			"models/arty/codmw2022/sp/mexican federal police/grunts/SCP_OZ_Security_3.mdl",
		},
		modelNames = { "Оперативник «Альфа»", "Оперативник «Браво»", "Оперативник «Чарли»" },
		weapons = { "tfa_fml_p90_tac" },
		armor = 50,
	},
	mtf = {
		name = "МОГ Эпсилон-11 «Девятихвостая лиса»",
		short = "МОГ",
		color = Color(96, 140, 210),
		clearance = 4,
		models = {
			"models/scp_mtf_russian/mtf_rus_02.mdl",
			"models/scp_mtf_russian/mtf_rus_04.mdl",
			"models/scp_mtf_russian/mtf_rus_05.mdl",
			"models/scp_mtf_russian/mtf_rus_06.mdl",
			"models/scp_mtf_russian/mtf_rus_07.mdl",
			"models/scp_mtf_russian/mtf_rus_08.mdl",
			"models/scp_mtf_russian/mtf_rus_09.mdl",
		},
		modelNames = { "Штурмовик", "Пулемётчик", "Разведчик", "Медик", "Сапёр", "Связист", "Командир звена" },
		weapons = { "tfa_ins2_ak12", "tfa_ins2_usp_match" },
		armor = 100,
	},
}

-- Совместимость со старым кодом: модели фракции по умолчанию
C.Models = C.Factions.security.models
C.ModelNames = C.Factions.security.modelNames
C.Weapons = C.Factions.security.weapons
C.SpareMags = 5

-- Противники (классы NPC из аддонов). point — точка появления в редакторе.
C.SCPs = {
	["096"] = { class = "npc_shaklin_scp096", name = "SCP-096", nick = "Скромник", point = "npc_096", respawn = 25 },
	["173"] = { class = "npc_scp-173_nextbot", name = "SCP-173", nick = "Скульптура", point = "npc_173", respawn = 20, blink = true },
	["049"] = { class = "npc_scp_049", name = "SCP-049", nick = "Чумной доктор", point = "npc_049", respawn = 25 },
}
C.Enemy096 = C.SCPs["096"].class

-- Передвижение
C.Movement = {
	Walk = 105,          -- обычный шаг
	Run = 215,           -- бег (Shift)
	SlowWalk = 68,       -- медленный шаг (Alt)
	Crouch = 0.4,        -- множитель скорости в приседе
	Jump = 175,
	BackwardFactor = 0.62, -- бег спиной/боком
	LandSlowdown = 0.45, -- скорость сразу после приземления
	JumpCooldown = 0.55,
}

-- Выносливость (0..100)
C.Stamina = {
	Max = 100,
	SprintDrain = 13,    -- в секунду при беге
	JumpCost = 11,
	Regen = 15,          -- в секунду, когда стоим/идём
	RegenDelay = 1.1,    -- пауза перед восстановлением
	Exhausted = 25,      -- после «выдоха» бег снова доступен с этого значения
}

-- Голос: дальность в игре; в лобби слышно всех участников лобби
C.VoiceRange = 750
C.VoiceRadio = true      -- рация (B) — слышно всю группу на задании

-- Чат
C.ChatRange = 600
C.WhisperRange = 140
C.YellRange = 1300

-- Сколько участников в лобби
C.LobbyMax = 8

-- Цвета интерфейса (тема «Фонд»: графит, бумага, сигнальный жёлто-красный)
C.Theme = {
	accent = Color(222, 226, 232),
	warn = Color(230, 180, 60),
	danger = Color(206, 52, 46),
}
