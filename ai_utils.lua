--- Various AI utilities.

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
local max = math.max
local min = math.min
local type = type

-- Modules --
local coro_flow = require("solar2d_utils.coro_flow")
local numeric = require("s3_utils.numeric")
local tile_layout = require("s3_utils.tile_layout")

-- Plugins --
local mwc = require("plugin.mwc")

-- Solar2D globals --
local display = display

-- Exports --
local M = {}

--
--
--

local BestT, Nx, Ny

local function TryNormal (t, nx, ny, compx, compy)
	if t > 0 and t < BestT and (nx ~= compx or ny ~= compy) then
		BestT, Nx, Ny = t, nx, ny
	end
end

local MaxX, MaxY

--- DOCME
-- @number px
-- @number py
-- @number vx
-- @number vy
-- @number nx
-- @number ny
-- @treturn number
-- @treturn number
-- @treturn number
function M.FindNearestBorder (px, py, vx, vy, nx, ny)
	BestT = 1 / 0

	if numeric.NotZero(vx) then
		TryNormal(-px / vx, 1, 0, nx, ny)
		TryNormal((MaxX - px) / vx, -1, 0, nx, ny)
	end

	if numeric.NotZero(vy) then
		TryNormal(-py / vy, 0, 1, nx, ny)
		TryNormal((MaxY - py) / vy, 0, -1, nx, ny)
	end

	return BestT, Nx, Ny
end

--
--
--

--- DOCME
-- @treturn number X
-- @treturn number Y
function M.GetExtents ()
	return MaxX, MaxY
end

--
--
--

--- DOCME
-- @uint start
-- @uint halfx
-- @uint halfy
-- @callable gen
-- @treturn uint T
function M.GetTileNeighbor (start, halfx, halfy, gen)
	local col, row = tile_layout.GetCell(start)
	local ncols, nrows = tile_layout.GetCounts()
	local w, h, tile = 2 * halfx + 1, 2 * halfy + 1

	repeat
		col = min(ncols, max(col - halfx, 1) + gen() % w)
		row = min(nrows, max(row - halfy, 1) + gen() % h)

		tile = tile_layout.GetIndex(col, row)
	until tile ~= start

	return tile
end

--
--
--

local function TSign (n, bias)
	return n + (n < 0 and -bias or bias)
end

--- DOCME
-- @uint start
-- @uint halfx
-- @uint halfy
-- @callable gen
-- @int biasx
-- @int biasy
-- @treturn uint T
function M.GetTileNeighbor_Biased (start, halfx, halfy, gen, biasx, biasy)
	halfx, halfy = halfx - biasx, halfy - biasy

	local col, row = tile_layout.GetCell(start)
	local ncols, nrows = tile_layout.GetCounts()
	local w, h, tile = 2 * halfx + 1, 2 * halfy + 1, start

	repeat
		local gw = halfx - gen() % w + 1
		local gh = halfy - gen() % h + 1

		if gw ~= 0 and gh ~= 0 then
			col = max(1, min(col + TSign(gw, biasx), ncols))
			row = max(1, min(row + TSign(gh, biasy), nrows))
			tile = tile_layout.GetIndex(col, row)
		end
	until tile ~= start

	return tile
end

--
--
--

--- DOCME
-- @uint n
-- @number tolerx
-- @number tolery
-- @pobject target
-- @number dt
-- @callable update
-- @param arg
-- @treturn boolean B
-- @treturn number X
-- @treturn number Y
function M.SamplePositions (n, tolerx, tolery, target, dt, update, arg)
	local sumx, sumy, prevx, prevy = 0, 0
	local is_func = type(target) == "function"

	for i = 1, n do
		--
		if not coro_flow.Wait(dt, update, arg) then
			return false
		end

		--
		local x, y

		if is_func then
			x, y = target()
		else
			x, y = target.x, target.y
		end

		--
		if i > 1 and not numeric.IsClose(x - prevx, y - prevy, tolerx, tolery) then
			return false
		end		

		prevx, sumx = x, sumx + x
		prevy, sumy = y, sumy + y
	end

	return true, sumx / n, sumy / n
end

--
--
--

--- DOCME
-- @pobject enemy
-- @treturn boolean X
function M.StartWithGenerator (enemy)
	local life = enemy.m_life

	enemy.m_life = (life or 0) + 1
	enemy.m_gen = mwc.MakeGenerator{ z = enemy.m_tile or 0, w = enemy.m_life }

	return life == nil
end

--
--
--

Runtime:addEventListener("things_loaded", function()
	local w, h = tile_layout.GetFullSizes()

	MaxX = max(w, display.contentWidth)
	MaxY = max(h, display.contentHeight)
end)

--
--
--

return M