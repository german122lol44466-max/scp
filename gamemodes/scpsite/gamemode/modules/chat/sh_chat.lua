--[[
	Чат. Каналы:
	  обычный  — на задании слышно рядом (~11 м), в лобби — свой отряд, в меню — все в меню
	  /r       — рация (весь отряд на задании); Y (messagemode2) сразу открывает рацию
	  /w /y    — шёпот / крик        /me — действие        // или /ooc — общий чат сервера
	  погибшие пишут только погибшим.
]]

local CH = SCP.Chat

CH.Kinds = {
	say = { label = nil, col = Color(232, 230, 224) },
	whisper = { label = "шёпотом", col = Color(170, 180, 200) },
	yell = { label = "кричит", col = Color(255, 196, 120) },
	me = { label = nil, col = Color(196, 170, 230) },
	radio = { label = "РАЦИЯ", col = Color(230, 180, 60) },
	ooc = { label = "OOC", col = Color(150, 152, 158) },
	lobby = { label = "ОТРЯД", col = Color(110, 196, 120) },
	dead = { label = "МЁРТВ", col = Color(206, 52, 46) },
	system = { label = "СИСТЕМА", col = Color(110, 160, 220) },
}

CH.Prefixes = {
	{ "/r ", "radio" }, { "/рация ", "radio" }, { "/w ", "whisper" }, { "/ш ", "whisper" },
	{ "/y ", "yell" }, { "/к ", "yell" }, { "/me ", "me" }, { "/я ", "me" },
	{ "// ", "ooc" }, { "//", "ooc" }, { "/ooc ", "ooc" }, { "/оос ", "ooc" },
}

function CH.Parse(text)
	local low = string.lower(text)
	for _, p in ipairs(CH.Prefixes) do
		if string.StartWith(low, p[1]) then return p[2], string.Trim(string.sub(text, #p[1] + 1)) end
	end
	return nil, text
end
