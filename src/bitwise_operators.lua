function bit(p)
  return 2 ^ (p - 1)  -- 1-based indexing
end

function hasbit(x, p)
  return x % (p + p) >= p       
end

function setbit(x, p)
  return hasbit(x, p) and x or x + p
end

function clearbit(x, p)
  return hasbit(x, p) and x - p or x
end

function OctToDec(value)
	base = 8
	local octal_string = tostring(value)
	local decimal = 0
	for char in octal_string:gmatch(".") do
		local n = tonumber(char, base)
		if not n then return 0 end
		decimal = decimal * base + n
	end
	return decimal
end

function DecToOct(value)
	base = 10
	local decimal_string = string.format("%o",value)
	local octal = 0
	for char in decimal_string:gmatch(".") do
		local n = tonumber(char, base)
		if not n then return 0 end
		octal = octal * base + n
	end
	return octal
end