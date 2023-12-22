-- WIP Bytestream library for image stickers
-- Mostly made by me, credit is attributed where due

local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local math_huge = math.huge
local math_frexp = math.frexp
local math_ldexp = math.ldexp
local math_floor = math.floor
local math_min = math.min
local math_max = math.max

local bit_rshift = bit.rshift
local tobyte, tochar = {}, {}
for i = 0, 255 do
    local c = string.char(i)
    tobyte[c] = i
    tochar[i] = c
end

-- next two functions are ripped from StarfallEx https://github.com/thegrb93/StarfallEx/blob/97d9b7f2fefaf748cd64717a90cd54f9177f983b/lua/starfall/libs_sh/bit.lua#L52
local function PackIEEE754Float(number)
	if number == 0 then
		return 0x00, 0x00, 0x00, 0x00
	elseif number == math_huge then
		return 0x00, 0x00, 0x80, 0x7F
	elseif number == -math_huge then
		return 0x00, 0x00, 0x80, 0xFF
	elseif number ~= number then
		return 0x00, 0x00, 0xC0, 0xFF
	else
		local sign = 0x00
		if number < 0 then
			sign = 0x80
			number = -number
		end
		local mantissa, exponent = math_frexp(number)
		exponent = exponent + 0x7F
		if exponent <= 0 then
			mantissa = math_ldexp(mantissa, exponent - 1)
			exponent = 0
		elseif exponent > 0 then
			if exponent >= 0xFF then
				return 0x00, 0x00, 0x80, sign + 0x7F
			elseif exponent == 1 then
				exponent = 0
			else
				mantissa = mantissa * 2 - 1
				exponent = exponent - 1
			end
		end
		mantissa = math_floor(math_ldexp(mantissa, 23) + 0.5)
		return mantissa % 0x100,
				bit_rshift(mantissa, 8) % 0x100,
				(exponent % 2) * 0x80 + bit_rshift(mantissa, 16),
				sign + bit_rshift(exponent, 1)
	end
end

local function UnpackIEEE754Float(b4, b3, b2, b1)
	local exponent = (b1 % 0x80) * 0x02 + bit_rshift(b2, 7)
	local mantissa = math_ldexp(((b2 % 0x80) * 0x100 + b3) * 0x100 + b4, -23)
	if exponent == 0xFF then
		if mantissa > 0 then
			return 0 / 0
		else
			if b1 >= 0x80 then
				return -math_huge
			else
				return math_huge
			end
		end
	elseif exponent > 0 then
		mantissa = mantissa + 1
	else
		exponent = exponent + 1
	end
	if b1 >= 0x80 then
		mantissa = -mantissa
	end
	return math_ldexp(mantissa, exponent - 0x7F)
end

local function Bytestream(data)
    local obj = {} do
        obj.data = data or ""
        obj.pointer = 1
        
        -- Internal Seeking/Writing/Reading Functions

        function obj:eof()
            return self.pointer > #self.data
        end

        function obj:advance(p) 
            p = p or 1 
            self.pointer = self.pointer + p 
        end

        function obj:backup(p)  
            p = p or 1 
            self.pointer = self.pointer - p 
        end

        function obj:peek(p) 
            p = p or 0
            if self:eof() then 
                error("cannot read further; end-of-file[" .. #self.data .. "]") 
            end 
            return self.data[self.pointer + p] 
        end

        function obj:push(s) 
            self.data = self.data .. s 
            self:advance(#s)
        end

        function obj:seek(p) 
            self.pointer = p
        end
        
        -- Read Functions

        function obj:readAngle()
            return Angle(self:readFloat(),self:readFloat(),self:readFloat())
        end

        function obj:readByte()
            return tobyte[self:readChar()]
        end
        
        function obj:readBytes(n)
            local bytes = {}
            for i = 1, n do bytes[i] = self:readByte() end
            return bytes
        end
        
        function obj:readChar()
            local r = self:peek()
            self:advance()
            return r
        end

        function obj:readColor()
            return Color(self:readUInt(8),self:readUInt(8),self:readUInt(8),self:readUInt(8))
        end

        function obj:readFloat()
            local b1, b2, b3, b4 = self:readByte(), self:readByte(), self:readByte(), self:readByte()
            return UnpackIEEE754Float(b1,b2,b3,b4)
        end

        function obj:readInt(bits)
            if bits % 8 ~= 0 then error("int length must be multiple of 8") end
            if bits > 32 then error("int length must be int32 or less") end
            
            local bytes = math.floor(bits / 8)
            local shift = 0
            local v = 0
            for i = 1, bytes do
                v = v + lshift(self:readByte(), shift)
                shift = shift + 8
            end
            
            if bits < 32 then -- 32-bit integers work fine, but less than need to be dealt with a bit differently
                local t = band(lshift(1, bits-1), v)
                if t == lshift(1, bits-1) then
                    local l = (2^(bits-1))
                    local mask = (l - 1)
                    local ret = l - band(v, mask)
                    return ret * -1
                end
            end

            return v
        end

        function obj:readString()
            local s = ""
            while not self:eof() and self:peek() ~= "\0" do
                s = s .. self:readChar()
            end
            self:advance()
            return s
        end
        
        function obj:readUInt(bits)
            local v = self:readInt(bits)
            
            if v < 0 then
                return bor(2^(bits-1), v)
            end
    
            return v
        end

        function obj:readVector()
            return Vector(self:readFloat(),self:readFloat(),self:readFloat())
        end
        
        -- Writing Functions

        function obj:writeAngle(a)
            self:writeFloat(a.pitch)
            self:writeFloat(a.yaw)
            self:writeFloat(a.roll)
        end
        
        function obj:writeByte(b)
            if b == nil then error("no input to bytestream:writeByte") end
            if b % 1 ~= 0 then b = math.Round(b) end
            self:push(tochar[b])
        end

        function obj:writeBytes(...)
            local t = {...}
            if type(t[1]) == "table" then t = t[1] end
            
            for _, v in ipairs(t) do self:writeByte(v) end
        end

        function obj:writeChar(c)
            if c == nil then error("no input to bytestream:writeChar") end
            self:push(c)
        end
        
        function obj:writeColor(c)
            self:writeUInt(c.r, 8)
            self:writeUInt(c.g, 8)
            self:writeUInt(c.b, 8)
            self:writeUInt(c.a, 8)
        end

        function obj:writeFloat(n)
            local b1, b2, b3, b4 = PackIEEE754Float(n)
            self:writeBytes(b1, b2, b3, b4)
        end

        function obj:writeInt(n, bits)
            if bits % 8 ~= 0 then error("int length must be multiple of 8") end
            if bits > 32 then error("int length must be int32 or less") end
            
            if n % 1 ~= 0 then 
                n = math.Round(n) 
                print("trying to write floating point value as int. will continue, but the value will be rounded; use writeFloat if this is unintended...")
            end
            
            local bytes = math.floor(bits / 8)
            for i = 1, bytes do
                self:writeByte(band(n, 0xFF))
                n = rshift(n, 8)
            end
        end

        function obj:writeString(s)
            self:push(s .. "\0")
        end

        -- They do basically the same thing, it's only the reader that needs a difference in logic
        function obj:writeUInt(n, bits) self:writeInt(n, bits) end

        function obj:writeVector(v)
            self:writeFloat(v.x)
            self:writeFloat(v.y)
            self:writeFloat(v.z)
        end

        function obj:dump()
            return self.data
        end
        
    end return obj
end

ImageStickers.Bytestream = Bytestream