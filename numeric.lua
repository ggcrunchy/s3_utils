--- Miscellaneous numeric utilities.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local abs = math.abs
local assert = assert
local ceil = math.ceil
local floor = math.floor
local max = math.max
local sqrt = math.sqrt
local type = type

-- Exports --
local M = {}

--
--
--

--- DOCME
-- @number dx
-- @number dy
-- @number tolerx
-- @number tolery
function M.IsClose (dx, dy, tolerx, tolery)
	tolerx, tolery = tolerx or 1e-5, tolery or tolerx or 1e-5

	return abs(dx) <= tolerx and abs(dy) <= tolery
end

--
--
--

--- DOCME
function M.MakeLengthQuantizer (params)
    assert(params == nil or type(params) == "table", "Non-table params")

    local step_func, bias, minimum, offset, rescale, unit = floor

    if params then
        if params.round_up then
            step_func = ceil
        end

        bias, minimum, offset, rescale, unit = params.bias, params.minimum, params.offset, params.rescale, params.unit

        assert(bias == nil or type(bias) == "number", "Non-number bias")
        assert(minimum == nil or type(minimum) == "number", "Non-number minimum")
        assert(offset == nil or type(offset) == "number", "Non-number offset")
        assert(rescale == nil or type(rescale) == "number", "Non-number rescale")
        assert(unit == nil or type(unit) == "number", "Non-number unit")
    end

    bias, minimum, offset, rescale, unit = bias or 0 or 1, minimum or 0, offset or 0, rescale or 1, unit or 1

    return function(dx, dy)
        return max(minimum, step_func(sqrt(dx^2 + dy^2) / unit + bias)) * rescale + offset
    end
end

--
--
--

--- DOCME
-- @number value
-- @treturn boolean X
function M.NotZero (value)
	return abs(value) > 1e-5
end

--
--
--

-- An implementation of Ken Perlin's simplex noise.
--
-- Based on code and comments in [Simplex noise demystified][1],
-- by Stefan Gustavson.
--
-- Thanks to Mike Pall for some cleanup and improvements (and for [LuaJIT][2]!).
--
-- [1]: http://www.itn.liu.se/~stegu/simplexnoise/simplexnoise.pdf
-- [2]: http://www.luajit.org

-- Index loop when index sums exceed 256 --
local MT = {
	__index = function(t, i)
		return t[i - 256]
	end
}

-- Permutation of 0-255, replicated to allow easy indexing with sums of two bytes --
local Perms = setmetatable({
	151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225,
	140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148,
	247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32,
	57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68,	175,
	74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111,	229, 122,
	60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54,
	65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169,
	200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64,
	52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212,
	207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213,
	119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9,
	129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104,
	218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241,
	81,	51, 145, 235, 249, 14, 239,	107, 49, 192, 214, 31, 181, 199, 106, 157,
	184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93,
	222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180
}, MT)

-- The above, mod 12 for each element --
local Perms12 = setmetatable({}, MT)

for i = 1, 256 do
	Perms12[i] = Perms[i] % 12 + 1
	Perms[i] = Perms[i] + 1
end

-- Gradients for 2D, 3D case --
local Grads3 = {
	{ 1, 1, 0 }, { -1, 1, 0 }, { 1, -1, 0 }, { -1, -1, 0 },
	{ 1, 0, 1 }, { -1, 0, 1 }, { 1, 0, -1 }, { -1, 0, -1 },
	{ 0, 1, 1 }, { 0, -1, 1 }, { 0, 1, -1 }, { 0, -1, -1 }
}

-- 2D weight contribution
local function GetN (ix, iy, x, y)
    local t = .5 - x^2 - y^2
    local index = Perms12[ix + Perms[iy + 1]]
    local grad = Grads3[index]

    return max(0, t^4) * (grad[1] * x + grad[2] * y)
end

-- 2D skew factor:
local F = (math.sqrt(3) - 1) / 2
local G = (3 - math.sqrt(3)) / 6
local G2 = 2 * G - 1

--- 2-dimensional simplex noise.
-- @number x Value #1.
-- @number y Value #2.
-- @treturn number Noise value &isin; [-1, +1].
function M.SampleNoise (x, y)
    -- Skew the input space to determine which simplex cell we are in.
    local s = (x + y) * F
    local ix, iy = floor(x + s), floor(y + s)

    -- Unskew the cell origin back to (x, y) space.
    local t = (ix + iy) * G
    local x0 = x + t - ix
    local y0 = y + t - iy

    -- Calculate the contribution from the two fixed corners.
    -- A step of (1,0) in (i,j) means a step of (1-G,-G) in (x,y), and
    -- A step of (0,1) in (i,j) means a step of (-G,1-G) in (x,y).
    ix, iy = ix % 256, iy % 256

    local n0 = GetN(ix, iy, x0, y0)
    local n2 = GetN(ix + 1, iy + 1, x0 + G2, y0 + G2)

    --[[
        Determine other corner based on simplex (equilateral triangle) we are in:
        if x0 > y0 then
            ix, x1 = ix + 1, x1 - 1
        else
            iy, y1 = iy + 1, y1 - 1
        end
    ]]
    local xi = x0 > y0 and 1 or 0
    local n1 = GetN(ix + xi, iy + (1 - xi), x0 + G - xi, y0 + G - (1 - xi))

    -- Add contributions from each corner to get the final noise value.
    -- The result is scaled to return values in the interval [-1,1].
    return 70.1480580019 * (n0 + n1 + n2)
end

--
--
--

return M