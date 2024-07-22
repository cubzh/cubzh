mod = {}

local to_normalized = {
	["À"] = "A",
	["Á"] = "A",
	["Â"] = "A",
	["Ã"] = "A",
	["Ä"] = "A",
	["Å"] = "A",
	["Ç"] = "C",
	["É"] = "E",
	["Ê"] = "E",
	["Ë"] = "E",
	["Ì"] = "I",
	["Í"] = "I",
	["Î"] = "I",
	["Ï"] = "I",
	["Ð"] = "D",
	["Ñ"] = "N",
	["Ò"] = "O",
	["Ó"] = "O",
	["Ô"] = "O",
	["Õ"] = "O",
	["Ö"] = "O",
	["Ø"] = "O",
	["Ù"] = "U",
	["Ú"] = "U",
	["Û"] = "U",
	["Ý"] = "Y",
	["Þ"] = "Th",
	["ß"] = "ss",
	["à"] = "a",
	["á"] = "a",
	["â"] = "a",
	["ã"] = "a",
	["ä"] = "a",
	["å"] = "a",
	["æ"] = "ae",
	["ç"] = "c",
	["è"] = "e",
	["é"] = "e",
	["ê"] = "e",
	["ë"] = "e",
	["ì"] = "i",
	["í"] = "i",
	["î"] = "i",
	["ï"] = "i",
	["ð"] = "d",
	["ñ"] = "n",
	["ò"] = "o",
	["ó"] = "o",
	["ô"] = "o",
	["õ"] = "o",
	["ö"] = "o",
	["ø"] = "o",
	["ù"] = "u",
	["ú"] = "u",
	["û"] = "u",
	["ü"] = "u",
	["ý"] = "y",
	["þ"] = "th",
	["ÿ"] = "y",
	["ă"] = "a",
	["ą"] = "a",
	["Ć"] = "C",
	["ć"] = "c",
	["Č"] = "C",
	["č"] = "c",
	["Đ"] = "D",
	["đ"] = "d",
	["ė"] = "e",
	["ę"] = "e",
	["ě"] = "e",
	["ğ"] = "g",
	["ĩ"] = "i",
	["į"] = "i",
	["ı"] = "i",
	["ł"] = "l",
	["ń"] = "n",
	["ő"] = "o",
	["Œ"] = "OE",
	["œ"] = "oe",
	["ś"] = "s",
	["Ŝ"] = "S",
	["Š"] = "S",
	["š"] = "s",
	["ţ"] = "t",
	["ũ"] = "u",
	["Ŭ"] = "U",
	["ű"] = "u",
	["ų"] = "u",
	["ź"] = "z",
	["ż"] = "z",
	["Ž"] = "Z",
	["ž"] = "z",
	["ơ"] = "o",
	["ư"] = "u",
	["Ș"] = "S",
	["ș"] = "s",
	["ț"] = "t",
	["ả"] = "a",
}

-- NOTE: not dealing with all possible characters,
-- ideally, we should include a library like ICU at the engine
-- level and expose utf8 features.
local lowercase_to_uppercase = {
	-- Latin
	a = "A",
	b = "B",
	c = "C",
	d = "D",
	e = "E",
	f = "F",
	g = "G",
	h = "H",
	i = "I",
	j = "J",
	k = "K",
	l = "L",
	m = "M",
	n = "N",
	o = "O",
	p = "P",
	q = "Q",
	r = "R",
	s = "S",
	t = "T",
	u = "U",
	v = "V",
	w = "W",
	x = "X",
	y = "Y",
	z = "Z",
	-- Cyrillic
	["а"] = "А",
	["б"] = "Б",
	["в"] = "В",
	["г"] = "Г",
	["д"] = "Д",
	["е"] = "Е",
	["ж"] = "Ж",
	["з"] = "З",
	["и"] = "И",
	["й"] = "Й",
	["к"] = "К",
	["л"] = "Л",
	["м"] = "М",
	["н"] = "Н",
	["о"] = "О",
	["п"] = "П",
	["р"] = "Р",
	["с"] = "С",
	["т"] = "Т",
	["у"] = "У",
	["ф"] = "Ф",
	["х"] = "Х",
	["ц"] = "Ц",
	["ч"] = "Ч",
	["ш"] = "Ш",
	["щ"] = "Щ",
	["ъ"] = "Ъ",
	["ы"] = "Ы",
	["ь"] = "Ь",
	["э"] = "Э",
	["ю"] = "Ю",
	["я"] = "Я",
	-- Ukrainian-specific
	["і"] = "І",
	["ї"] = "Ї",
	["є"] = "Є",
	["ґ"] = "Ґ",
	-- Polish-specific
	["ą"] = "Ą",
	["ć"] = "Ć",
	["ę"] = "Ę",
	["ł"] = "Ł",
	["ń"] = "Ń",
	["ó"] = "Ó",
	["ś"] = "Ś",
	["ź"] = "Ź",
	["ż"] = "Ż",
}

local uppercase_to_lowercase = {}
for k, v in pairs(lowercase_to_uppercase) do
	uppercase_to_lowercase[v] = k
end

local function utf8sub(str, start, stop)
	local sub = ""
	local currentIndex = 1
	for uchar in string.gmatch(str, "([%z\1-\127\194-\244][\128-\191]*)") do
		if currentIndex >= start and (stop == nil or currentIndex <= stop) then
			sub = sub .. uchar
		elseif stop ~= nil and currentIndex > stop then
			break
		end
		currentIndex = currentIndex + 1
	end
	return sub
end

mod.normalize = function(self, str)
	if self ~= mod then
		error("str:normalize(someString) should be called with `:`", 2)
	end
	return str:gsub("[%z\1-\127\194-\244][\128-\191]*", to_normalized)
end

mod.lower = function(self, str)
	if self ~= mod then
		error("str:lower(someString) should be called with `:`", 2)
	end
	return str:gsub("[%z\1-\127\194-\244][\128-\191]*", uppercase_to_lowercase)
end

mod.upper = function(self, str)
	if self ~= mod then
		error("str:upper(someString) should be called with `:`", 2)
	end
	return str:gsub("[%z\1-\127\194-\244][\128-\191]*", lowercase_to_uppercase)
end

mod.upperFirstChar = function(self, str)
	if self ~= mod then
		error("str:upperFirstChar(someString) should be called with `:`", 2)
	end
	local firstChar = utf8sub(str, 1, 1)
	local rest = utf8sub(str, 2)
	local upperFirstChar = lowercase_to_uppercase[firstChar] or firstChar -- Fallback to original if no mapping
	return upperFirstChar .. rest
end

mod.trimSpaces = function(self, str)
	if self ~= mod then
		error("str:trimSpaces(someString) should be called with `:`", 2)
	end
	if type(str) ~= "string" then
		error("str:trimSpaces(someString) - someString should be a string", 2)
	end
	return str:gsub("^%s*(.-)%s*$", "%1")
end

return mod
