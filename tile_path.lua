--- Some utilities for tile-constrained navigation.

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
local max = math.max
local min = math.min

-- Modules --
local meta = require("tektite_core.table.meta")
local movement = require("s3_utils.movement")
local tile_flags = require("s3_utils.tile_flags")
local tile_layout = require("s3_utils.tile_layout")

-- Exports --
local M = {}

--
--
--

local StuckFrameCounts = meta.WeakKeyed()

--- DOCME
-- @param object
function M.Reset (object)
	StuckFrameCounts[object] = nil
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

local TooManyFrames = 2

local function GetTileInfo (x, y)
	local tile = tile_layout.GetIndex_XY(x, y)
	local tx, ty = tile_layout.GetPosition(tile)

	return tx, ty, tile
end

--- DOCME
-- @param object
-- @number dist
-- @string dir
-- @treturn boolean M
-- @treturn number X
-- @treturn number Y
-- @treturn string D
function M.TryToMove (object, dist, dir)
	local path_opts, near_goal = PathOpts[object]
	local tilew, tileh = tile_layout.GetSizes()
  local halfw, halfh = tilew / 2, tileh / 2

  if path_opts then
    near_goal = path_opts.NearGoal * (halfw + halfh) -- based on average

    if near_goal < dist then
      dist = near_goal
    end
  end

  local x, y, step = object.x, object.y, min(dist, tilew, tileh)
	local x0, y0, tx, ty, tile = x, y, GetTileInfo(x, y)

	while dist > 0 do
		local prevx, prevy, flags = x, y, tile_flags.GetFlags(tile)

		dist, x, y = dist - step, movement.MoveFrom(x, y, tx, ty, flags, min(step, dist), dir)
    tx, ty, tile = GetTileInfo(x, y)

		-- If the entity is following a path, stop if it reaches the goal (or gets impeded).
		-- Because the goal can be on the fringe of the rectangular cell, radius checks have
		-- problems, so we instead check the before and after projections of the goal onto
		-- the path. If the position on the path switched sides, it passed the goal; if the
		-- goal is also within cell range, we consider it reached.
		if path_opts and path_opts.IsFollowingPath(object) then
			local switch, gx, gy, cur_tile = false, path_opts.GoalPos(object)

			if dir == "left" or dir == "right" then
				switch = (gx - prevx) * (gx - x) <= 0 and abs(gy - y) <= halfh
			else
				switch = (gy - prevy) * (gy - y) <= 0 and abs(gx - x) <= halfw
			end

			if switch or StuckFrameCounts[object] == TooManyFrames then
				path_opts.CancelPath(object)

				break
			end

			-- If the entity steps onto the center of a non-corner / junction tile for the
			-- first time during a path, update the pathing state.
      if tile ~= cur_tile then
        flags = tile_flags.GetFlags(tile)

        if not tile_layout.IsStraight(flags) and max(abs(tx - x), abs(ty - y)) < near_goal then
          dir = path_opts.UpdateOnMove(dir, tile, object)
        end
      end
		end
	end

	--
	-- CONSIDER: What if 'dist' happened to be low?
  local dx, dy = x - x0, y - y0
	local stuck = 1 + dx * dx + dy * dy == 1

	if stuck and path_opts and path_opts.IsFollowingPath(object) then
		local count = StuckFrameCounts[object] or 0

		if count < TooManyFrames then
			StuckFrameCounts[object] = count + 1
		end
	else
		StuckFrameCounts[object] = nil
	end

	return not stuck, x, y, dir, tile
end

--
--
--

return M