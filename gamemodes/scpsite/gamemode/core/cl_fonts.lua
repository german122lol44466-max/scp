--[[
	Шрифты (лежат в аддоне контента, resource/fonts):
	  Oswald — заголовки, Manrope — интерфейс и чат, JetBrains Mono — «терминальные» надписи Фонда.
	SCP.Font(style, size) — size в пикселях для 1080p, масштабируется под экран.
]]

local families = {
	regular = { "Manrope", 400 },
	medium = { "Manrope Medium", 500 },
	semibold = { "Manrope SemiBold", 600 },
	bold = { "Manrope ExtraBold", 800 },
	title = { "Oswald SemiBold", 600 },
	titlemed = { "Oswald Medium", 500 },
	titlelight = { "Oswald Light", 300 },
	mono = { "JetBrains Mono", 400 },
	monobold = { "JetBrains Mono", 700 },
}

local created = {}

local function create(name, style, size)
	local fam = families[style] or families.regular
	surface.CreateFont(name, {
		font = fam[1],
		weight = fam[2],
		size = math.max(8, math.Round(size * ScrH() / 1080)),
		extended = true,
		antialias = true,
	})
end

function SCP.Font(style, size)
	local name = "scp." .. style .. "." .. size
	if not created[name] then
		create(name, style, size)
		created[name] = { style, size }
	end
	return name
end

hook.Add("OnScreenSizeChanged", "scp.fonts", function()
	for name, def in pairs(created) do create(name, def[1], def[2]) end
end)

-- Фиксированный размер (для 3D2D в мире).
local raw = {}
function SCP.FontRaw(style, size)
	local name = "scp.raw." .. style .. "." .. size
	if not raw[name] then
		local fam = families[style] or families.regular
		surface.CreateFont(name, { font = fam[1], weight = fam[2], size = size, extended = true, antialias = true })
		raw[name] = true
	end
	return name
end
