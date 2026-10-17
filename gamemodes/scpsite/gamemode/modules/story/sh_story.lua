--[[
	Сюжет: «Протокол „Скромник“» — глава I.
	Пересменка на Объекте-19. Сбой питания, генератор, нарушение условий содержания SCP-096,
	карты доступа, пульт изоляции, эвакуация.

	Этапы (kind):
	  reach   — дойти до точки (radius)
	  use     — удерживать E у объекта на точке (duration секунд, needItem — нужен предмет у кого-то из отряда)
	  collect — собрать count предметов item (спавнятся на случайных точках spawnPoint)
	Реплики оповещения (vo) лежат в sound/scpsite/vo/<id>.mp3, текст — субтитры.
]]

local S = SCP.Story
S.Title = "Протокол «Скромник»"
S.Chapter = "ГЛАВА I"

S.Stages = {
	{
		id = "command", title = "Пересменка", goal = "Доберитесь до поста охраны",
		kind = "reach", point = "obj_command", radius = 170,
		startVO = { "intro1" }, doneVO = { "command_done" },
	},
	{
		id = "generator", title = "Тишина", goal = "Запустите резервный генератор",
		kind = "use", point = "obj_generator", label = "запуск генератора", duration = 10,
		model = "models/props_vehicles/generatortrailer01.mdl",
		startFX = "blackout", startVO = { "blackout" }, doneVO = { "generator_done" }, doneFX = "power",
	},
	{
		id = "keycards", title = "Не смотри", goal = "Соберите карты доступа",
		kind = "collect", item = "keycard", count = 3, spawnPoint = "item_keycard",
		startFX = "breach", startVO = { "breach", "keycards_hint" }, doneVO = { "keycards_done" }, spawn096 = true,
	},
	{
		id = "lockdown", title = "Изоляция", goal = "Активируйте пульт изоляции сектора",
		kind = "use", point = "obj_lockdown", label = "протокол изоляции", duration = 14, needItem = "keycard",
		model = "models/props_lab/reciever_cart.mdl",
		startVO = { "lockdown_hint" }, useVO = "lockdown_start", doneVO = { "lockdown_done" }, doneFX = "contain",
	},
	{
		id = "exit", title = "Эвакуация", goal = "Доберитесь до точки эвакуации",
		kind = "reach", point = "obj_exit", radius = 220,
		doneVO = { "exit_done" },
	},
}

-- Оповещения системы безопасности объекта (женский голос, громкая связь)
S.VO = {
	intro1 = "Доброе утро, Объект-19. Время — шесть ноль-ноль. Смене службы безопасности сектора четыре прибыть на пост охраны.",
	command_done = "Пост охраны: смена принята. Внимание: зафиксированы перебои питания в секторе четыре.",
	blackout = "Внимание. Отказ основной сети питания. Переход на аварийное освещение. Персоналу сектора четыре — запустить резервный генератор.",
	generator_done = "Резервное питание восстановлено. Проверка систем содержания…",
	breach = "Внимание всему персоналу. Нарушение условий содержания. Объект ноль девять шесть покинул камеру. Не смотрите на объект. Повторяю: не смотрите на объект.",
	keycards_hint = "Для протокола изоляции сектора требуются три карты доступа третьего уровня. Карты находятся у дежурных постов.",
	keycards_done = "Карты доступа подтверждены. Пульт изоляции сектора разблокирован.",
	lockdown_hint = "Пульт изоляции готов к запуску. Требуется удержание доступа до завершения протокола.",
	lockdown_start = "Запуск протокола изоляции. Гермозатворы закрываются. Подача седативного газа в сектор четыре.",
	lockdown_done = "Объект ноль девять шесть обездвижен. Протокол изоляции выполнен. Персоналу — эвакуация через контрольно-пропускной пункт.",
	exit_done = "Эвакуация подтверждена. Спасибо за службу, сотрудники.",
	reminder = "Напоминание: не смотрите на объект ноль девять шесть.",
	fail = "Связь с группой потеряна. Сектор четыре закрыт. Протокол омега.",
}

S.State = S.State or { running = false, stage = 0, started = 0 }

function S.Current()
	return S.Stages[S.State.stage]
end
