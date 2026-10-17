--[[
	Сюжетная кампания: 5 глав. Глава I — за службу безопасности, II–V — за МОГ Эпсилон-11.

	Этап (stage):
	  kind    = "reach"   — дойти до точки (radius)
	            "use"     — удерживать E у объекта на точке (duration с; needItem — предмет у кого-то в отряде)
	            "collect" — собрать count предметов item (появляются на случайных точках spawnPoint)
	            "survive" — продержаться duration секунд в зоне point (radius), хотя бы одному живому
	  timer   = секунды — не успели — задание провалено (эвакуация, боеголовка)
	  spawn   = { "096", "173" } — выпустить SCP в начале этапа; contain = {…} — убрать после этапа
	  talk    = { { "player" | "command" | "self", "текст" }, … } — диалог в начале этапа:
	            player — говорит случайный живой боец отряда, command — Командование по рации
	  startVO / doneVO / useVO — оповещения громкой связи (S.VO), startFX / doneFX — эффекты
	Точки для каждого этапа регистрируются в редакторе автоматически (группа = глава).
]]

local S = SCP.Story
local P = SCP.Points

S.Chapters = {
	-- ------------------------------------------------------------------ I --
	{
		id = "c1", roman = "I", title = "Скромник", faction = "security", spawn = "spawn",
		desc = "Пересменка на Объекте-19 оборачивается отключением питания. Где-то в секторе 4 плачет SCP-096.",
		image = "096", intro = "c1_intro", outro = nil,
		stages = {
			{ id = "command", title = "Пересменка", goal = "Доберитесь до поста охраны",
				kind = "reach", point = "obj_command", pointName = "Пост охраны", radius = 170,
				startVO = { "intro1" }, doneVO = { "command_done" },
				talk = { { "player", "Ещё одна смена в этой дыре. Пошли, пока кофе не остыл." },
					{ "command", "Пост-4, приём. Смена, доложите о прибытии на пост охраны." } } },
			{ id = "generator", title = "Тишина", goal = "Запустите резервный генератор",
				kind = "use", point = "obj_generator", pointName = "Генератор", label = "запуск генератора", duration = 10,
				model = "models/props_vehicles/generatortrailer01.mdl",
				startFX = "blackout", startVO = { "blackout" }, doneVO = { "generator_done" }, doneFX = "power",
				talk = { { "player", "Свет… Только не сейчас. Фонари включить!" },
					{ "command", "Сектор 4, у нас ноль по питанию камеры содержания. Запустите генератор вручную." } } },
			{ id = "keycards", title = "Не смотри", goal = "Соберите карты доступа",
				kind = "collect", item = "keycard", count = 3, spawnPoint = "item_keycard", spawnName = "Карта доступа (3+)",
				startFX = "breach", startVO = { "breach", "keycards_hint" }, doneVO = { "keycards_done" }, spawn = { "096" },
				talk = { { "player", "Вы слышали? Это… плач." }, { "player", "Не смотрите на него. Что бы ни случилось — не смотрите." } } },
			{ id = "lockdown", title = "Изоляция", goal = "Активируйте пульт изоляции сектора",
				kind = "use", point = "obj_lockdown", pointName = "Пульт изоляции", label = "протокол изоляции", duration = 14, needItem = "keycard",
				model = "models/props_lab/reciever_cart.mdl",
				startVO = { "lockdown_hint" }, useVO = "lockdown_start", doneVO = { "lockdown_done" }, doneFX = "contain", contain = { "096" },
				talk = { { "command", "Карты подтверждены. Держите пульт, пока не опустятся гермозатворы." } } },
			{ id = "exit", title = "Эвакуация", goal = "Доберитесь до точки эвакуации",
				kind = "reach", point = "obj_exit", pointName = "Точка эвакуации", radius = 220, doneVO = { "exit_done" },
				talk = { { "player", "Всё. Уходим отсюда и больше никогда не возвращаемся." } } },
		},
	},
	-- ----------------------------------------------------------------- II --
	{
		id = "c2", roman = "II", title = "Не моргай", faction = "mtf", spawn = "spawn_mtf",
		desc = "МОГ Эпсилон-11 входит в зону лёгкого содержания. SCP-173 вне камеры. Не теряйте его из виду.",
		image = "173", intro = "c2_intro",
		stages = {
			{ id = "entry", title = "Высадка", goal = "Войдите в зону лёгкого содержания",
				kind = "reach", point = "c2_entry", pointName = "Вход в ЗЛС", radius = 200, startVO = { "c2_intro" },
				talk = { { "command", "Эпсилон-11, говорит Командование. Объект 173 вне камеры. Двигайтесь парами, не теряйте его из виду." },
					{ "player", "Принято. Девятихвостая лиса входит." } } },
			{ id = "cameras", title = "Слепые зоны", goal = "Перезапустите систему наблюдения",
				kind = "use", point = "c2_cameras", pointName = "Щит видеонаблюдения", label = "перезапуск камер", duration = 9,
				model = "models/props_lab/workspace003.mdl", startFX = "flicker", spawn = { "173" }, doneVO = { "c2_cameras" },
				talk = { { "player", "Камеры мертвы. Без них мы слепые." }, { "player", "Кто моргнёт — предупреждайте. Один смотрит — другой моргает." } } },
			{ id = "fuses", title = "Предохранители", goal = "Найдите предохранители для клетки",
				kind = "collect", item = "fuse", count = 3, spawnPoint = "c2_fuse", spawnName = "Предохранитель (3+)",
				startVO = { "c2_fuses" },
				talk = { { "command", "Клетка сдерживания обесточена. Найдите три предохранителя в подсобках." } } },
			{ id = "cage", title = "Клетка", goal = "Опустите клетку сдерживания",
				kind = "use", point = "c2_cage", pointName = "Пульт клетки", label = "опускание клетки", duration = 12, needItem = "fuse",
				model = "models/props_lab/reciever_cart.mdl", doneFX = "contain", contain = { "173" }, doneVO = { "c2_contained" },
				talk = { { "player", "Смотрите на него. Все. Не отводите глаз, пока клетка не опустится." } } },
			{ id = "exit", title = "Отход", goal = "Вернитесь к точке эвакуации",
				kind = "reach", point = "c2_exit", pointName = "Точка эвакуации", radius = 220, doneVO = { "c2_exit" },
				talk = { { "command", "Хорошая работа, лиса. Возвращайтесь." } } },
		},
	},
	-- ---------------------------------------------------------------- III --
	{
		id = "c3", roman = "III", title = "Лекарство", faction = "mtf", spawn = "spawn_mtf",
		desc = "SCP-049 «лечит» персонал медицинского крыла. Нужно забрать образцы и сжечь заражённый сектор.",
		image = "049",
		stages = {
			{ id = "lab", title = "Карантин", goal = "Доберитесь до лаборатории",
				kind = "reach", point = "c3_lab", pointName = "Лаборатория", radius = 180, startVO = { "c3_intro" },
				talk = { { "command", "Медицинское крыло на карантине. Объект 049 на свободе. Не дайте ему прикоснуться к вам." },
					{ "player", "Понял. Если он кого-то тронет — тот больше не наш." } } },
			{ id = "samples", title = "Образцы", goal = "Соберите образцы «лекарства»",
				kind = "collect", item = "sample", count = 3, spawnPoint = "c3_sample", spawnName = "Образец (3+)", spawn = { "049" },
				talk = { { "player", "Он говорит. Слышите? «Я — лекарство»…" }, { "player", "Хватаем образцы и не задерживаемся." } } },
			{ id = "hold", title = "Шлюз", goal = "Удерживайте шлюз во время дезинфекции",
				kind = "survive", point = "c3_hold", pointName = "Шлюз дезинфекции", radius = 260, duration = 60,
				startFX = "alarm", startVO = { "c3_hold" },
				talk = { { "command", "Дезинфекция шлюза — шестьдесят секунд. Держите позицию!" } } },
			{ id = "burn", title = "Очищение", goal = "Запустите печь сжигания",
				kind = "use", point = "c3_burn", pointName = "Пульт печи", label = "запуск печи", duration = 10, needItem = "sample",
				model = "models/props_c17/furnitureboiler001a.mdl", doneFX = "contain", contain = { "049" }, doneVO = { "c3_burned" },
				talk = { { "player", "Пусть горит. Всё крыло." } } },
			{ id = "exit", title = "Отход", goal = "Покиньте медицинское крыло",
				kind = "reach", point = "c3_exit", pointName = "Выход из крыла", radius = 220, doneVO = { "exit_done" } },
		},
	},
	-- ----------------------------------------------------------------- IV --
	{
		id = "c4", roman = "IV", title = "Каскад", faction = "mtf", spawn = "spawn_mtf",
		desc = "Каскадное нарушение: 096, 173 и 049 на свободе одновременно. Продержитесь до прибытия эвакуации.",
		image = "keter",
		stages = {
			{ id = "hub", title = "Узел", goal = "Доберитесь до центрального узла",
				kind = "reach", point = "c4_hub", pointName = "Центральный узел", radius = 200, startVO = { "c4_intro" },
				talk = { { "command", "Всем группам: каскадное нарушение условий содержания. Повторяю — каскадное." },
					{ "player", "Сколько их?" }, { "command", "Все, лиса. Все, кого вы знаете." } } },
			{ id = "power", title = "Тьма", goal = "Восстановите питание узла",
				kind = "use", point = "c4_power", pointName = "Щит питания", label = "переключение питания", duration = 10,
				model = "models/props_vehicles/generatortrailer01.mdl", startFX = "blackout", doneFX = "power", spawn = { "173" },
				startVO = { "blackout" }, doneVO = { "generator_done" } },
			{ id = "cards", title = "Доступ", goal = "Соберите карты доступа",
				kind = "collect", item = "keycard", count = 3, spawnPoint = "c4_card", spawnName = "Карта доступа (3+)", spawn = { "096" },
				startFX = "breach", startVO = { "breach" },
				talk = { { "player", "Плач… Он тоже здесь." } } },
			{ id = "hold", title = "Ожидание", goal = "Удерживайте посадочную площадку",
				kind = "survive", point = "c4_hold", pointName = "Посадочная площадка", radius = 300, duration = 75, spawn = { "049" },
				startFX = "alarm", startVO = { "c4_hold" },
				talk = { { "command", "Эвакуационная группа будет через семьдесят пять секунд. Держитесь." } } },
			{ id = "exit", title = "Эвакуация", goal = "Успейте к эвакуации",
				kind = "reach", point = "c4_exit", pointName = "Эвакуация", radius = 240, timer = 150, doneVO = { "exit_done" },
				talk = { { "command", "Борт на месте. У вас две с половиной минуты. Он не будет ждать." } } },
		},
	},
	-- ------------------------------------------------------------------ V --
	{
		id = "c5", roman = "V", title = "Омега", faction = "mtf", spawn = "spawn_mtf",
		desc = "Объект потерян. Совет О5 санкционирует боеголовку «Альфа». Кто-то должен её взвести — и успеть уйти.",
		image = "foundation", intro = "c5_intro", outro = "c5_outro",
		stages = {
			{ id = "command", title = "Последний приказ", goal = "Доберитесь до командного центра",
				kind = "reach", point = "c5_command", pointName = "Командный центр", radius = 200, startVO = { "c5_intro" },
				talk = { { "command", "Эпсилон-11. Решение принято на уровне О5. Объект девятнадцать будет уничтожен." },
					{ "player", "А персонал?" }, { "command", "…Выполняйте приказ, лиса." } } },
			{ id = "codes", title = "Коды", goal = "Введите коды подтверждения",
				kind = "use", point = "c5_codes", pointName = "Терминал кодов", label = "ввод кодов О5", duration = 15,
				model = "models/props_lab/workspace003.mdl", spawn = { "049", "096" },
				talk = { { "player", "Пятнадцать секунд на коды. Прикройте меня!" } } },
			{ id = "warhead", title = "«Альфа»", goal = "Взведите боеголовку",
				kind = "use", point = "c5_warhead", pointName = "Боеголовка «Альфа»", label = "взведение боеголовки", duration = 12,
				model = "models/props_c17/substation_transformer01d.mdl", startFX = "alarm", doneFX = "warhead", doneVO = { "c5_armed" },
				talk = { { "player", "Рычаг… Поехали." } } },
			{ id = "run", title = "Девяносто секунд", goal = "Бегите к поверхности",
				kind = "reach", point = "c5_exit", pointName = "Выход на поверхность", radius = 260, timer = 95, spawn = { "173" },
				doneVO = { "c5_end" },
				talk = { { "player", "Бегом! Не останавливаться!" } } },
		},
	},
}

-- Катсцены: камера пролетает по точкам "cs_<id>" (ставятся в редакторе по взгляду, по порядку).
S.Cutscenes = {
	c1_intro = { title = "ОБЪЕКТ-19", sub = "Сектор 4 · 05:58", duration = 12,
		lines = { { 1, "Командование", "Смена, доброе утро. Сектор 4 — без происшествий. Пока что." } } },
	c2_intro = { title = "НЕ МОРГАЙ", sub = "Глава II · Зона лёгкого содержания", duration = 12,
		lines = { { 1, "Командование", "Эпсилон-11, объект 173 вне камеры. Держите его в поле зрения. Всегда." } } },
	c5_intro = { title = "ОМЕГА", sub = "Глава V · Решение Совета О5", duration = 14,
		lines = { { 1, "Командование", "Объект потерян. Боеголовка «Альфа» — единственный выход." },
			{ 7, "Командование", "Взведите её. И постарайтесь вернуться." } } },
	c5_outro = { title = "СПАСИБО ЗА СЛУЖБУ", sub = "Объект-19 уничтожен", duration = 12, flash = true,
		lines = { { 2, "Командование", "Детонация подтверждена. Объект-19 больше не существует." },
			{ 7, "Командование", "Эпсилон-11… с возвращением." } } },
}

-- Оповещения громкой связи (женский голос; звук — sound/scpsite/vo/<id>.mp3)
S.VO = {
	intro1 = "Доброе утро, Объект-19. Время — шесть ноль-ноль. Смене службы безопасности сектора четыре прибыть на пост охраны.",
	command_done = "Пост охраны: смена принята. Внимание: зафиксированы перебои питания в секторе четыре.",
	blackout = "Внимание. Отказ основной сети питания. Переход на аварийное освещение. Персоналу — запустить резервный генератор.",
	generator_done = "Резервное питание восстановлено. Проверка систем содержания.",
	breach = "Внимание всему персоналу. Нарушение условий содержания. Объект ноль девять шесть покинул камеру. Не смотрите на объект. Повторяю: не смотрите на объект.",
	keycards_hint = "Для протокола изоляции сектора требуются три карты доступа третьего уровня. Карты находятся у дежурных постов.",
	keycards_done = "Карты доступа подтверждены. Пульт изоляции сектора разблокирован.",
	lockdown_hint = "Пульт изоляции готов к запуску. Требуется удержание доступа до завершения протокола.",
	lockdown_start = "Запуск протокола изоляции. Гермозатворы закрываются. Подача седативного газа в сектор четыре.",
	lockdown_done = "Объект ноль девять шесть обездвижен. Протокол изоляции выполнен. Персоналу — эвакуация через контрольно-пропускной пункт.",
	exit_done = "Эвакуация подтверждена. Спасибо за службу.",
	reminder = "Напоминание: не смотрите на объект ноль девять шесть.",
	fail = "Связь с группой потеряна. Сектор закрыт. Протокол омега.",
	c2_intro = "Мобильная оперативная группа Эпсилон-одиннадцать вошла в зону лёгкого содержания. Всему персоналу — оставаться в укрытиях.",
	c2_cameras = "Система видеонаблюдения восстановлена. Объект один семь три обнаружен в зоне лёгкого содержания.",
	c2_fuses = "Клетка сдерживания объекта один семь три обесточена. Требуется замена предохранителей.",
	c2_contained = "Объект один семь три помещён в клетку сдерживания. Повторное содержание подтверждено.",
	c2_exit = "Мобильная оперативная группа покидает зону лёгкого содержания.",
	c3_intro = "Внимание. Медицинское крыло на карантине. Объект ноль четыре девять вне камеры содержания. Избегайте физического контакта.",
	c3_hold = "Запущена дезинфекция шлюза. Время цикла: шестьдесят секунд. Не покидайте шлюз.",
	c3_burned = "Печь сжигания запущена. Медицинское крыло подлежит полной стерилизации.",
	c4_intro = "Внимание. Каскадное нарушение условий содержания. Множественные объекты класса Кетер вне камер. Всему персоналу — немедленная эвакуация.",
	c4_hold = "Эвакуационный борт на подлёте. Расчётное время прибытия — семьдесят пять секунд.",
	c5_intro = "Внимание. Совет О5 санкционировал процедуру уничтожения объекта. Персоналу с допуском четыре — прибыть в командный центр.",
	c5_armed = "Боеголовка Альфа взведена. Детонация через девяносто секунд. Всему персоналу — немедленно покинуть объект.",
	c5_end = "Детонация. Детонация. Детонация.",
	-- обычная жизнь объекта (между событиями)
	routine1 = "Доктор Гирс, пройдите в лабораторию номер четыре. Доктор Гирс, в лабораторию номер четыре.",
	routine2 = "Напоминание: курение на территории объекта запрещено, за исключением отведённых мест.",
	routine3 = "Персоналу класса Д: построение в блоке три через десять минут.",
	routine4 = "Плановая проверка систем вентиляции. Возможны кратковременные перепады давления.",
	routine5 = "Сотрудникам службы безопасности: проверка пропусков на контрольно-пропускных пунктах усилена.",
	routine6 = "Обед в столовой сектора два задерживается на пятнадцать минут. Приносим извинения.",
}
S.Routine = { "routine1", "routine2", "routine3", "routine4", "routine5", "routine6" }

S.State = S.State or { running = false, chapter = 1, stage = 0, started = 0 }

function S.ChapterDef(i) return S.Chapters[i or S.State.chapter or 1] or S.Chapters[1] end
function S.StagesOf(i) return S.ChapterDef(i).stages end
function S.Current()
	return S.StagesOf()[S.State.stage]
end
-- совместимость: S.Stages / S.Chapter / S.Title — текущей главы
setmetatable(S, { __index = function(t, k)
	if k == "Stages" then return t.StagesOf() end
	if k == "Chapter" then return "ГЛАВА " .. t.ChapterDef().roman end
	if k == "Title" then return t.ChapterDef().title end
end })

-- ------------------------------------------ точки редактора из сюжета --
for ci, ch in ipairs(S.Chapters) do
	local group = "Глава " .. ch.roman .. " · " .. ch.title
	for _, st in ipairs(ch.stages) do
		if st.point then
			P.Register({ id = st.point, name = st.pointName or st.title, single = true, col = Color(230, 180, 60), group = group, need = 1, chapter = ci })
		end
		if st.spawnPoint then
			P.Register({ id = st.spawnPoint, name = st.spawnName or "Предмет", col = Color(230, 180, 60), group = group, need = st.count, chapter = ci })
		end
	end
	for _, cs in ipairs({ ch.intro, ch.outro }) do
		if cs then
			P.Register({ id = "cs_" .. cs, name = "Катсцена: " .. (S.Cutscenes[cs] and S.Cutscenes[cs].title or cs) .. " (камеры по порядку)",
				cam = true, col = Color(190, 120, 230), group = group, cutscene = cs, chapter = ci })
		end
	end
end
