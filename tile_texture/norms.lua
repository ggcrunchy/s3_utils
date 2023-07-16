--- Tile shape normals.

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
local ceil = math.ceil
local cos = math.cos
local pi = math.pi
local sqrt = math.sqrt

-- Exports --
local M = {}

--
--
--

local LUTs = {}

--
--
--

local function GetLUT (n)
  local lut = LUTs[n]

  if not lut then
    lut = { 1 }

    local frac = pi / (2 * n)

    for i = 1, n - 1 do
      lut[i + 1] = cos(i * frac)
    end
    
    lut[n + 1], LUTs[n] = 0, lut
  end

  return lut
end

--
--
--

local function Lookup (what, i, n)
  local is_full = what == "full"
  local lut, flip = GetLUT(is_full and ceil(n / 2) or n)

  n = #lut

  if what == "backward" then
    i = n - i + 1
  elseif is_full and i > n then
    i, flip = 2 * n - i, true
  end

  local scale = lut[i]

  return flip and -scale or scale
end

--
--
--

function M.Arc (normals, what, x, y, i, n)
  local sq_len = x * x + y * y

  if 1 + sq_len ~= 1 then
    local scale = Lookup(what, i + 1, n) / sqrt(sq_len)

    x, y = x * scale, y * scale
  end

  normals[#normals + 1] = x
  normals[#normals + 1] = y
end

--
--
--

function M.Interior (normals, x, y, i, n, ni)
  local index, scale = ni * 2, Lookup("full", x, y) * Lookup("forward", i + 1, n)

  normals[#normals + 1] = scale * normals[index - 1]
  normals[#normals + 1] = scale * normals[index]
end

--
--
--

function M.Unit (normals, nx, ny)
  local sq_len, scale = nx * nx + ny * ny, 0

  if 1 + sq_len ~= 1 then
    scale = 1 / sqrt(sq_len)
  end

  normals[#normals + 1] = nx * scale
  normals[#normals + 1] = ny * scale
end

--
--
--

return M