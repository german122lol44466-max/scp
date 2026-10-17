--[[
	Настройки режима. Всё, что может захотеть поменять владелец сервера, — здесь.
]]

local C = SCP.Config

-- Модели охраны (выбор стрелками в лобби)
C.Models = {
	"models/arty/codmw2022/sp/mexican federal police/grunts/SCP_OZ_Security_1.mdl",
	"models/arty/codmw2022/sp/mexican federal police/grunts/SCP_OZ_Security_2.mdl",
	"models/arty/codmw2022/sp/mexican federal police/grunts/SCP_OZ_Security_3.mdl",
}
C.ModelNames = { "Оперативник «Альфа»", "Оперативник «Браво»", "Оперативник «Чарли»" }

-- Оружие и патроны при выходе на задание
C.Weapons = { "tfa_fml_p90_tac" }
C.SpareMags = 5

-- Главный противник
C.Enemy096 = "npc_shaklin_scp096"

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
