--- Various glow-based utilities.

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

-- Solar2D globals --
local easing = easing
local Runtime = Runtime

-- Cached module references --
local _GetGlowTime_

-- Exports --
local M = {}

--
--
--

local Glow = {}

---
-- @byte r1 Red...
-- @byte g1 ...green...
-- @byte b1 ...and blue, #1.
-- @byte r2 Red...
-- @byte g2 ...green...
-- @byte b2 ...and blue, #2.
-- @treturn function Returns the red, green, and blue values interpolated at the glow time.
-- @see GetGlowTime
function M.ColorInterpolator (r1, g1, b1, r2, g2, b2)
  local dr, dg, db = r2 - r1, g2 - g1, b2 - b1

	return function()
    -- 1 - (1 - x)^2 -> x * (2 - x), cf. http://www.plunk.org/~hatch/rightway.html...
    local x = 2 * _GetGlowTime_() -- ...so we have 2 * t * (2 - 2 * t)...
		local u = 4 * x * (1 - x) -- ...and finally this

		return r1 + u * dr, g1 + u * dg, b1 + u * db
	end
end

---
-- @treturn number Current glow time, &isin; [0, 1].
function M.GetGlowTime ()
  return easing.inOutQuad(Runtime.getFrameStartTime() % 1100, 1100, 0, 1)
--	return Glow.t
end

--
--
--

_GetGlowTime_ = M.GetGlowTime

return M