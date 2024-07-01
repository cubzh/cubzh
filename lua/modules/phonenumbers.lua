local mod = {}

local countryPrefixes = {
	["1"] = { emoji = "🇺🇸", code = "US" },
	["7"] = { emoji = "🇷🇺", code = "RU" },
	["20"] = { emoji = "🇪🇬", code = "EG" },
	["30"] = { emoji = "🇬🇷", code = "GR" },
	["31"] = { emoji = "🇳🇱", code = "NL" },
	["32"] = { emoji = "🇧🇪", code = "BE" },
	["33"] = { emoji = "🇫🇷", code = "FR" },
	["34"] = { emoji = "🇪🇸", code = "ES" },
	["36"] = { emoji = "🇭🇺", code = "HU" },
	["39"] = { emoji = "🇮🇹", code = "IT" },
	["40"] = { emoji = "🇷🇴", code = "RO" },
	["44"] = { emoji = "🇬🇧", code = "GB" },
	["45"] = { emoji = "🇩🇰", code = "DK" },
	["46"] = { emoji = "🇸🇪", code = "SE" },
	["47"] = { emoji = "🇳🇴", code = "NO" },
	["48"] = { emoji = "🇵🇱", code = "PL" },
	["49"] = { emoji = "🇩🇪", code = "DE" },
	["51"] = { emoji = "🇵🇪", code = "PE" },
	["52"] = { emoji = "🇲🇽", code = "MX" },
	["53"] = { emoji = "🇨🇺", code = "CU" },
	["54"] = { emoji = "🇦🇷", code = "AR" },
	["55"] = { emoji = "🇧🇷", code = "BR" },
	["56"] = { emoji = "🇨🇱", code = "CL" },
	["57"] = { emoji = "🇨🇴", code = "CO" },
	["58"] = { emoji = "🇻🇪", code = "VE" },
	["60"] = { emoji = "🇲🇾", code = "MY" },
	["61"] = { emoji = "🇦🇺", code = "AU" },
	["62"] = { emoji = "🇮🇩", code = "ID" },
	["63"] = { emoji = "🇵🇭", code = "PH" },
	["64"] = { emoji = "🇳🇿", code = "NZ" },
	["65"] = { emoji = "🇸🇬", code = "SG" },
	["66"] = { emoji = "🇹🇭", code = "TH" },
	["81"] = { emoji = "🇯🇵", code = "JP" },
	["82"] = { emoji = "🇰🇷", code = "KR" },
	["84"] = { emoji = "🇻🇳", code = "VN" },
	["86"] = { emoji = "🇨🇳", code = "CN" },
	["90"] = { emoji = "🇹🇷", code = "TR" },
	["91"] = { emoji = "🇮🇳", code = "IN" },
	["92"] = { emoji = "🇵🇰", code = "PK" },
	["93"] = { emoji = "🇦🇫", code = "AF" },
	["94"] = { emoji = "🇱🇰", code = "LK" },
	["95"] = { emoji = "🇲🇲", code = "MM" },
	["98"] = { emoji = "🇮🇷", code = "IR" },
	["212"] = { emoji = "🇲🇦", code = "MA" },
	["213"] = { emoji = "🇩🇿", code = "DZ" },
	["216"] = { emoji = "🇹🇳", code = "TN" },
	["218"] = { emoji = "🇱🇾", code = "LY" },
	["220"] = { emoji = "🇬🇲", code = "GM" },
	["221"] = { emoji = "🇸🇳", code = "SN" },
	["222"] = { emoji = "🇲🇷", code = "MR" },
	["223"] = { emoji = "🇲🇱", code = "ML" },
	["224"] = { emoji = "🇬🇳", code = "GN" },
	["225"] = { emoji = "🇨🇮", code = "CI" },
	["226"] = { emoji = "🇧🇫", code = "BF" },
	["227"] = { emoji = "🇳🇪", code = "NE" },
	["228"] = { emoji = "🇹🇬", code = "TG" },
	["229"] = { emoji = "🇧🇯", code = "BJ" },
	["230"] = { emoji = "🇲🇺", code = "MU" },
	["231"] = { emoji = "🇱🇷", code = "LR" },
	["232"] = { emoji = "🇸🇱", code = "SL" },
	["233"] = { emoji = "🇬🇭", code = "GH" },
	["234"] = { emoji = "🇳🇬", code = "NG" },
	["235"] = { emoji = "🇹🇩", code = "TD" },
	["236"] = { emoji = "🇨🇫", code = "CF" },
	["237"] = { emoji = "🇨🇲", code = "CM" },
	["238"] = { emoji = "🇨🇻", code = "CV" },
	["239"] = { emoji = "🇸🇹", code = "ST" },
	["240"] = { emoji = "🇬🇶", code = "GQ" },
	["241"] = { emoji = "🇬🇦", code = "GA" },
	["242"] = { emoji = "🇨🇬", code = "CG" },
	["243"] = { emoji = "🇨🇩", code = "CD" },
	["244"] = { emoji = "🇦🇴", code = "AO" },
	["245"] = { emoji = "🇬🇼", code = "GW" },
	["246"] = { emoji = "🇮🇴", code = "IO" },
	["248"] = { emoji = "🇸🇨", code = "SC" },
	["249"] = { emoji = "🇸🇩", code = "SD" },
	["250"] = { emoji = "🇷🇼", code = "RW" },
	["251"] = { emoji = "🇪🇹", code = "ET" },
	["252"] = { emoji = "🇸🇴", code = "SO" },
	["253"] = { emoji = "🇩🇯", code = "DJ" },
	["254"] = { emoji = "🇰🇪", code = "KE" },
	["255"] = { emoji = "🇹🇿", code = "TZ" },
	["256"] = { emoji = "🇺🇬", code = "UG" },
	["257"] = { emoji = "🇧🇮", code = "BI" },
	["258"] = { emoji = "🇲🇿", code = "MZ" },
	["260"] = { emoji = "🇿🇲", code = "ZM" },
	["261"] = { emoji = "🇲🇬", code = "MG" },
	["262"] = { emoji = "🇾🇹", code = "YT" },
	["263"] = { emoji = "🇿🇼", code = "ZW" },
	["264"] = { emoji = "🇳🇦", code = "NA" },
	["265"] = { emoji = "🇲🇼", code = "MW" },
	["266"] = { emoji = "🇱🇸", code = "LS" },
	["267"] = { emoji = "🇧🇼", code = "BW" },
	["268"] = { emoji = "🇸🇿", code = "SZ" },
	["269"] = { emoji = "🇰🇲", code = "KM" },
	["290"] = { emoji = "🇸🇭", code = "SH" },
	["291"] = { emoji = "🇪🇷", code = "ER" },
	["297"] = { emoji = "🇦🇼", code = "AW" },
	["298"] = { emoji = "🇫🇴", code = "FO" },
	["299"] = { emoji = "🇬🇱", code = "GL" },
	["350"] = { emoji = "🇬🇮", code = "GI" },
	["351"] = { emoji = "🇵🇹", code = "PT" },
	["352"] = { emoji = "🇱🇺", code = "LU" },
	["353"] = { emoji = "🇮🇪", code = "IE" },
	["354"] = { emoji = "🇮🇸", code = "IS" },
	["355"] = { emoji = "🇦🇱", code = "AL" },
	["356"] = { emoji = "🇲🇹", code = "MT" },
	["357"] = { emoji = "🇨🇾", code = "CY" },
	["358"] = { emoji = "🇫🇮", code = "FI" },
	["359"] = { emoji = "🇧🇬", code = "BG" },
	["370"] = { emoji = "🇱🇹", code = "LT" },
	["371"] = { emoji = "🇱🇻", code = "LV" },
	["372"] = { emoji = "🇪🇪", code = "EE" },
	["373"] = { emoji = "🇲🇩", code = "MD" },
	["374"] = { emoji = "🇦🇲", code = "AM" },
	["375"] = { emoji = "🇧🇾", code = "BY" },
	["376"] = { emoji = "🇦🇩", code = "AD" },
	["377"] = { emoji = "🇲🇨", code = "MC" },
	["378"] = { emoji = "🇸🇲", code = "SM" },
	["379"] = { emoji = "🇻🇦", code = "VA" },
	["380"] = { emoji = "🇺🇦", code = "UA" },
	["381"] = { emoji = "🇷🇸", code = "RS" },
	["382"] = { emoji = "🇲🇪", code = "ME" },
	["383"] = { emoji = "🇽🇰", code = "XK" },
	["385"] = { emoji = "🇭🇷", code = "HR" },
	["386"] = { emoji = "🇸🇮", code = "SI" },
	["387"] = { emoji = "🇧🇦", code = "BA" },
	["389"] = { emoji = "🇲🇰", code = "MK" },
	["420"] = { emoji = "🇨🇿", code = "CZ" },
	["421"] = { emoji = "🇸🇰", code = "SK" },
	["423"] = { emoji = "🇱🇮", code = "LI" },
	["500"] = { emoji = "🇫🇰", code = "FK" },
	["501"] = { emoji = "🇧🇿", code = "BZ" },
	["502"] = { emoji = "🇬🇹", code = "GT" },
	["503"] = { emoji = "🇸🇻", code = "SV" },
	["504"] = { emoji = "🇭🇳", code = "HN" },
	["505"] = { emoji = "🇳🇮", code = "NI" },
	["506"] = { emoji = "🇨🇷", code = "CR" },
	["507"] = { emoji = "🇵🇦", code = "PA" },
	["508"] = { emoji = "🇵🇲", code = "PM" },
	["509"] = { emoji = "🇭🇹", code = "HT" },
	["590"] = { emoji = "🇬🇵", code = "GP" },
	["591"] = { emoji = "🇧🇴", code = "BO" },
	["592"] = { emoji = "🇬🇾", code = "GY" },
	["593"] = { emoji = "🇪🇨", code = "EC" },
	["594"] = { emoji = "🇬🇫", code = "GF" },
	["595"] = { emoji = "🇵🇾", code = "PY" },
	["596"] = { emoji = "🇲🇶", code = "MQ" },
	["597"] = { emoji = "🇸🇷", code = "SR" },
	["598"] = { emoji = "🇺🇾", code = "UY" },
	["599"] = { emoji = "🇧🇶", code = "BQ" },
	["670"] = { emoji = "🇹🇱", code = "TL" },
	["672"] = { emoji = "🇳🇫", code = "NF" },
	["673"] = { emoji = "🇧🇳", code = "BN" },
	["674"] = { emoji = "🇳🇷", code = "NR" },
	["675"] = { emoji = "🇵🇬", code = "PG" },
	["676"] = { emoji = "🇹🇴", code = "TO" },
	["677"] = { emoji = "🇸🇧", code = "SB" },
	["678"] = { emoji = "🇻🇺", code = "VU" },
	["679"] = { emoji = "🇫🇯", code = "FJ" },
	["680"] = { emoji = "🇵🇼", code = "PW" },
	["681"] = { emoji = "🇼🇫", code = "WF" },
	["682"] = { emoji = "🇨🇰", code = "CK" },
	["683"] = { emoji = "🇳🇺", code = "NU" },
	["685"] = { emoji = "🇼🇸", code = "WS" },
	["686"] = { emoji = "🇰🇮", code = "KI" },
	["687"] = { emoji = "🇳🇨", code = "NC" },
	["688"] = { emoji = "🇹🇻", code = "TV" },
	["689"] = { emoji = "🇵🇫", code = "PF" },
	["690"] = { emoji = "🇹🇰", code = "TK" },
	["691"] = { emoji = "🇫🇲", code = "FM" },
	["692"] = { emoji = "🇲🇭", code = "MH" },
	["850"] = { emoji = "🇰🇵", code = "KP" },
	["852"] = { emoji = "🇭🇰", code = "HK" },
	["853"] = { emoji = "🇲🇴", code = "MO" },
	["855"] = { emoji = "🇰🇭", code = "KH" },
	["856"] = { emoji = "🇱🇦", code = "LA" },
	["880"] = { emoji = "🇧🇩", code = "BD" },
	["886"] = { emoji = "🇹🇼", code = "TW" },
	["960"] = { emoji = "🇲🇻", code = "MV" },
	["961"] = { emoji = "🇱🇧", code = "LB" },
	["962"] = { emoji = "🇯🇴", code = "JO" },
	["963"] = { emoji = "🇸🇾", code = "SY" },
	["964"] = { emoji = "🇮🇶", code = "IQ" },
	["965"] = { emoji = "🇰🇼", code = "KW" },
	["966"] = { emoji = "🇸🇦", code = "SA" },
	["967"] = { emoji = "🇾🇪", code = "YE" },
	["968"] = { emoji = "🇴🇲", code = "OM" },
	["970"] = { emoji = "🇵🇸", code = "PS" },
	["971"] = { emoji = "🇦🇪", code = "AE" },
	["972"] = { emoji = "🇮🇱", code = "IL" },
	["973"] = { emoji = "🇧🇭", code = "BH" },
	["974"] = { emoji = "🇶🇦", code = "QA" },
	["975"] = { emoji = "🇧🇹", code = "BT" },
	["976"] = { emoji = "🇲🇳", code = "MN" },
	["977"] = { emoji = "🇳🇵", code = "NP" },
	["992"] = { emoji = "🇹🇯", code = "TJ" },
	["993"] = { emoji = "🇹🇲", code = "TM" },
	["994"] = { emoji = "🇦🇿", code = "AZ" },
	["995"] = { emoji = "🇬🇪", code = "GE" },
	["996"] = { emoji = "🇰🇬", code = "KG" },
	["998"] = { emoji = "🇺🇿", code = "UZ" },
}

local countries = {}
local countryCodes = {}
local entry
for prefix in pairs(countryPrefixes) do
	entry = countryPrefixes[prefix]
	if entry ~= nil then
		entry.prefix = prefix -- add prefix in entry
		table.insert(countries, entry)
		countryCodes[entry.code] = entry
	end
end
table.sort(countries, function(a, b)
	return a.code < b.code
end)

mod.countries = countries
mod.countryCodes = countryCodes

function sanitize(phoneNumber)
	return phoneNumber:gsub("[^%d+]", "")
end

function extractCountryCode(phoneNumber)
	phoneNumber = sanitize(phoneNumber)

	local res = {
		phoneNumber = phoneNumber,
		countryCode = nil,
		countryPrefix = nil,
		remainingNumber = nil,
		emoji = nil,
		sanitizedNumber = nil,
	}

	-- Check if the number starts with '+'
	if phoneNumber:sub(1, 1) == "+" then
		phoneNumber = phoneNumber:sub(2)
		-- Try to match the longest country code first
		for i = 3, 1, -1 do
			local potentialPrefix = phoneNumber:sub(1, i)
			if countryPrefixes[potentialPrefix] then
				local entry = countryPrefixes[potentialPrefix]
				res.countryCode = entry.code
				res.emoji = entry.emoji
				res.countryPrefix = potentialPrefix
				res.remainingNumber = phoneNumber:sub(i + 1)
				res.sanitizedNumber = "+" .. res.countryPrefix .. res.remainingNumber
				break
			end
		end
	elseif phoneNumber:sub(1, 2) == "00" then
		phoneNumber = phoneNumber:sub(3)
		-- Try to match the longest country code first
		for i = 3, 1, -1 do
			local potentialPrefix = phoneNumber:sub(1, i)
			if countryPrefixes[potentialPrefix] then
				local entry = countryPrefixes[potentialPrefix]
				res.countryCode = entry.code
				res.emoji = entry.emoji
				res.countryPrefix = potentialPrefix
				res.remainingNumber = phoneNumber:sub(i + 1)
				res.sanitizedNumber = "+" .. res.countryPrefix .. res.remainingNumber
				break
			end
		end
	end

	return res
end

mod.extractCountryCode = function(self, phoneNumber)
	if self ~= mod then
		error("phonenumbers:parse(phoneNumber) should be called with `:`", 2)
	end

	return extractCountryCode(phoneNumber)
end

mod.sanitize = function(_, phoneNumber)
	return sanitize(phoneNumber)
end

return mod
