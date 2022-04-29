--- Star-based effects.

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
local cos = math.cos
local deg = math.deg
local ipairs = ipairs
local min = math.min
local pi = math.pi
local random = math.random
local sin = math.sin
local type = type

-- Solar2D globals --
local display = display
local timer = timer

-- Cached module references --
local _Star_

-- Exports --
local M = {}

--
--
--

-- Full circle --
local _2pi = 2 * pi

-- Angle between star endpoints --
local Angle = _2pi / 5

-- Computes the i-th endpoint of a star
local function Point (x, y, angle, radius, i)
	angle = angle + 2 * Angle * i

	local ca, sa = cos(angle), sin(angle)

	return x + radius * ca, y + radius * sa
end

--- Make a 5-pointed star.
-- @pgroup group Group to which the star will be inserted.
-- @number x Center x-coordinate.
-- @number y As per _x_.
-- @number radius Distance from center to each endpoint.
-- @number[opt=0] angle Initial angle. An angle of 0 has two points on the "ground", two
-- points out to left and right, and one point centered at the top.
-- @treturn DisplayObject The star object: a closed, centered polyline.
function M.Star (group, x, y, radius, angle)
	angle = -Angle / 4 + (angle or 0)

	local x1, y1 = Point(x, y, angle, radius, 0)
	local x2, y2 = Point(x, y, angle, radius, 1)

	local star = display.newLine(group, x1, y1, x2, y2)

	for i = 2, 5 do
		star:append(Point(x, y, angle, radius, i))
	end

	return star
end

--
--
--

local StarFuncs = {
	-- Mild rocking --
	mild_rocking = function(star, t, i)
		local angle = (t + i) % pi

		if angle > pi / 2 then
			angle = pi - angle
		end

		star.rotation = deg(angle)
	end
}

local StarSets = {
	default = { "T1", "T5", "T7" }
}

for _, set in pairs(StarSets) do
	for k, v in pairs(set) do
		set[k] = "s3_utils/assets/fx/Star-" .. v .. ".png"
	end
end

local RotateSpeed = 1.5 * _2pi

--- DOCME
-- @pgroup group
-- @uint nstars
-- @number dx
-- @number dy
-- @ptable[opt] opts
-- @treturn DisplayGroup X
-- @treturn DisplayGroup Y
function M.RingOfStars (group, nstars, dx, dy, opts)
	--
	local square, file, func

	if opts then
		file = opts.file
		func = opts.func
		func = StarFuncs[func] or func
		square = not opts.skew
	end

	file = StarSets[file] or file

	--
	local front = display.newGroup()
	local back = display.newGroup()

	group:insert(front)
	group:insert(back)

	back:toBack()

	--
	local function Update (star, angle, index)
		angle = angle % _2pi

		star.x = cos(angle) * dx
		star.y = sin(angle) * dy

		;(angle < pi and front or back):insert(star)

		if func then
			func(star, angle, index)
		end
	end

	--
	local w, h = dx, dy

	if square then
		local size = .75 * min(dx, dy) + .25 * (dx + dy)

		w, h = size, size
	end

	--
	local stars, is_table = {}, type(file) == "table"

	for i = 1, nstars do
		if file then
			local name = is_table and file[random(#file)] or file

			stars[i] = display.newImageRect(name, w, h)
		else
			stars[i] = _Star_(front, 0, 0, 10, 0)
		end

		Update(stars[i], (i - 1) * _2pi / nstars, i)
	end

	--
	local delay = 10

	timer.performWithDelay(10, function(event)
		if display.isValid(front) and display.isValid(back) then
			local t = (event.count * delay) * RotateSpeed / 1000
			local dt = _2pi / #stars

			for i, star in ipairs(stars) do
				Update(star, t, i)

				t = t + dt
			end
		else
			display.remove(front)
      display.remove(back)
			timer.cancel(event.source)
		end
	end, 0)

	return front, back
end

--
--
--

_Star_ = M.Star

return M