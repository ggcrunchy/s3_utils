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
local abs = math.abs
local huge = math.huge
local max = math.max
local min = math.min
local type = type

-- Modules --
local coro_flow = require("solar2d_utils.coro_flow")
local meta = require("tektite_core.table.meta")
local movement = require("s3_utils.movement")
local range = require("tektite_core.number.range")
local tile_flags = require("s3_utils.tile_flags")
local tile_layout = require("s3_utils.tile_layout")

-- Plugins --
local mwc = require("plugin.mwc")

-- Solar2D globals --
local display = display

-- Cached module references --
local _IsClose_
local _NotZero_

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
	BestT = huge

	if _NotZero_(vx) then
		TryNormal(-px / vx, 1, 0, nx, ny)
		TryNormal((MaxX - px) / vx, -1, 0, nx, ny)
	end

	if _NotZero_(vy) then
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
			col = range.ClampIn(col + TSign(gw, biasx), 1, ncols)
			row = range.ClampIn(row + TSign(gh, biasy), 1, nrows)

			tile = tile_layout.GetIndex(col, row)
		end
	until tile ~= start

	return tile
end

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
-- @number value
-- @treturn boolean X
function M.NotZero (value)
	return abs(value) > 1e-5
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
		if i > 1 and not _IsClose_(x - prevx, y - prevy, tolerx, tolery) then
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

local PathOpts = meta.WeakKeyed()

--- DOCME
function M.SetPathingOpts (entity, path_opts)
	PathOpts[entity] = path_opts
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

-- Count of frames without movement --
local NoMove = meta.WeakKeyed()

local TooManyMoves = 2

local function GetTileInfo (x, y)
	local tile = tile_layout.GetIndex_XY(x, y)
	local tx, ty = tile_layout.GetPosition(tile)

	return tx, ty, tile
end

--- DOCME
-- @param entity
-- @number dist
-- @string dir
-- @treturn boolean M
-- @treturn number X
-- @treturn number Y
-- @treturn string D
function M.TryToMove (entity, dist, dir)
	local path_opts = PathOpts[entity]
	local acc, step, x, y = 0, min(path_opts and path_opts.NearGoal or dist, dist), entity.x, entity.y
	local x0, y0, tilew, tileh = x, y, tile_layout.GetSizes()
	local tx, ty, tile = GetTileInfo(x, y)

	while acc < dist do
		local prevx, prevy, flags = x, y, tile_flags.GetFlags(tile)

		acc, x, y = acc + step, movement.MoveFrom(x, y, tx, ty, flags, min(step, dist - acc), dir)

		-- If the entity is following a path, stop if it reaches the goal (or gets impeded).
		-- Because the goal can be on the fringe of the rectangular cell, radius checks have
		-- problems, so we instead check the before and after projections of the goal onto
		-- the path. If the position on the path switched sides, it passed the goal; if the
		-- goal is also within cell range, we consider it reached.
		if path_opts and path_opts.IsFollowingPath(entity) then
			local switch, gx, gy, gtile = false, path_opts.GoalPos(entity)

			if dir == "left" or dir == "right" then
				switch = (gx - prevx) * (gx - x) <= 0 and abs(gy - y) <= tileh / 2
			else
				switch = (gy - prevy) * (gy - y) <= 0 and abs(gx - x) <= tilew / 2
			end

			if switch or NoMove[entity] == TooManyMoves then
				path_opts.CancelPath(entity)

				break
			end

			-- If the entity steps onto the center of a non-corner / junction tile for the
			-- first time during a path, update the pathing state.
			tx, ty, tile = GetTileInfo(x, y)

			if not tile_layout.IsStraight(flags) and gtile ~= tile and _IsClose_(tx - x, ty - y, path_opts.NearGoal) then
				dir = path_opts.UpdateOnMove(dir, tile, entity)
			end
		end
	end

	--
	-- CONSIDER: What if 'dist' happened to be low?
	local no_move = _IsClose_(x - x0, y - y0, 1e-3)

	if no_move and path_opts and path_opts.IsFollowingPath(entity) then
		local count = NoMove[entity] or 0

		if count < TooManyMoves then
			NoMove[entity] = count + 1
		end
	else
		NoMove[entity] = nil
	end

	return not no_move, x, y, dir
end

--
--
--

--- DOCME
-- @param entity
function M.WipePath (entity)
	NoMove[entity] = nil
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

_IsClose_ = M.IsClose
_NotZero_ = M.NotZero

return M