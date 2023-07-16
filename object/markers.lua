--- Various screen markers.

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
local atan2 = math.atan2
local cos = math.cos
local deg = math.deg
local max = math.max
local min = math.min
local pairs = pairs
local pi = math.pi
local sin = math.sin

-- Modules --
local glow = require("s3_utils.object.glow")
local numeric = require("s3_utils.numeric")

-- Extension imports --
local hypot = math.hypot

-- Solar2D globals --
local display = display
local timer = timer

-- Cached module references --
local _LineOfArrows_
local _StraightArrow_
local _WallOfArrows_

-- Exports --
local M = {}

--
--
--

-- --
local Near = {}

-- --
local Mult = 5

-- --
local Axis = {
	{ x = 0, y = 1 }, { x = -1, y = 0 }, { x = 0, y = -1 }, { x = 1, y = 0 }
}

-- --
local AngleDelta = pi / (2 * Mult)

--
local Points, Index, MinX, MinY, MaxX, MaxY = {}

--
local function AddPoint (x, y)
	if Index == 0 then
		MinX, MinY, MaxX, MaxY = x, y, x, y
	else
		MinX, MaxX = min(x, MinX), max(x, MaxX)
		MinY, MaxY = min(y, MinY), max(y, MaxY)
	end

	Points[Index + 1], Points[Index + 2], Index = x, y, Index + 2
end

--
local function Trim ()
	for i = #Points, Index + 1, -1 do
		Points[i] = nil
	end
end

--
local function MakePolygon (group, x, y, correct)
	Trim()

	if correct then
		local cx, cy = (MaxX - MinX) / 2, (MaxY - MinY) / 2

		for i = 1, Index, 2 do
			Points[i], Points[i + 1] = Points[i] - cx, Points[i + 1] - cy
		end
	end

	return display.newPolygon(group, x, y, Points)
end

--- DOCME
-- @pgroup group Group to which arrow will be inserted.
-- @string how
-- @number x
-- @number y
-- @number radius
-- @number thickness
-- @treturn DisplayObject X
function M.CurvedArrow (group, how, x, y, radius, thickness)
	--
	local aindex = 1

	if how == "180" then
		aindex = 2
	elseif how == "270" then
		aindex = 3
	end

	--
	Index = 0

	--
	local far = radius + thickness

	AddPoint(radius, 0)
	AddPoint(far, 0)

	for i = 1, aindex * Mult do
		local angle = i * AngleDelta
		local ca, sa = cos(angle), sin(angle)

		Near[i * 2 - 1], Near[i * 2] = radius * ca, radius * sa

		AddPoint(far * ca, -far * sa)
	end

	--
	local axis, perp = Axis[aindex], Axis[aindex + 1]
	local ax, ay = axis.x, axis.y
	local px, py = perp.x, perp.y

	local d1 = far + radius * .3
	local d2 = radius + thickness / 2
	local d3 = .8 * thickness
	local d4 = radius * .7

	AddPoint(ax * d1, -ay * d1)
	AddPoint(ax * d2 + px * d3, -(ay * d2 + py * d3))
	AddPoint(ax * d4, -ay * d4)

	--
	for i = aindex * Mult * 2, 3, -2 do
		AddPoint(Near[i - 1], -Near[i])
	end

	return MakePolygon(group, x, y)
end

--
--
--

local ArrowGroup = {}

--
--
--

--- DOCME
-- @byte r
-- @byte g
-- @byte b
function ArrowGroup:SetColor (r, g, b)
	for i = 1, self.numChildren do
		self[i]:setFillColor(r, g, b)
	end
end

--
--
--

--- DOCME
-- @number x1
-- @number y1
-- @number x2
-- @number y2
-- @number offset
function ArrowGroup:SetEndPoints (x1, y1, x2, y2, offset)
	offset = offset or 0

	local dx, dy = x2 - x1, y2 - y1
	local angle = deg(atan2(dy, dx))
	local dfunc = self.m_dfunc
	local n, len, fade_from = self.numChildren, hypot(dx, dy)

	if self.m_is_line then
		fade_from = len - self[1].height
	end

	for i = 1, n do
		local arrow = self[i]
		local dx2, dy2 = dfunc(i, n, dx, dy, offset, self)

		arrow.x = x1 + dx2
		arrow.y = y1 + dy2
		arrow.rotation = angle

		--
		if fade_from then
			local dist = max(hypot(dx2, dy2) - fade_from, 0)

			arrow.alpha = 1 - (dist / (len - fade_from))^3
		end
	end
end

--
--
--

-- Common logic to build arrow group constructors
local function ArrowGroupMaker (sep, dfunc)
	local DistanceToCount = numeric.MakeLengthQuantizer{ unit = sep, bias = 1 }

	return function(group, dir, x1, y1, x2, y2, _, offset)
		local arrow_group = display.newGroup()

		group:insert(arrow_group)

		--
		local dx, dy = x2 - x1, y2 - y1

		for _ = 1, DistanceToCount(dx, dy) do
			_StraightArrow_(arrow_group, dir, 0, 0)
		end

		--
		for k, v in pairs(ArrowGroup) do
			arrow_group[k] = v
		end

		--
		arrow_group.m_dfunc = dfunc

		arrow_group:SetEndPoints(x1, y1, x2, y2, offset)

		return arrow_group
	end
end

-- Maker that creates a group of arrows in a line formation
local MakeLine = ArrowGroupMaker(125, function(i, n, dx, dy, offset)
	local frac = ((i - .5) / n + offset) % 1

	return frac * dx, frac * dy
end)

--- DOCME
-- @pgroup group Group to which arrows will be inserted.
-- @number x1
-- @number y1
-- @number x2
-- @number y2
-- @int width
-- @number offset
-- @treturn DisplayGroup G
function M.LineOfArrows (group, x1, y1, x2, y2, width, offset)
	local arrow_group = MakeLine(group, "right", x1, y1, x2, y2, width, offset)

	arrow_group.m_is_line = true

	return arrow_group
end

--
--
--

-- Current arrow glow color --
local ArrowRGB = glow.ColorInterpolator(1, 0, 0, 0, 0, 1)

--- DOCME
-- @pgroup group Group to which arrows will be inserted.
-- @param from
-- @param to
-- @int width
-- @number alpha
-- @string dir
-- @treturn DisplayGroup H
-- @treturn TimerHandle TH
function M.PointFromTo (group, from, to, width, alpha, dir)
	--
	local sep, aline

	if dir == "forward" or dir == "backward" then
		sep, aline = 750, _WallOfArrows_(group, dir, from.x, from.y, to.x, to.y, width, 0)
	else
		sep, aline = 2500, _LineOfArrows_(group, from.x, from.y, to.x, to.y, width, 0)
	end

	--
	aline:SetColor(ArrowRGB())

	aline.alpha = alpha

	local delay = 25

	local atimer = timer.performWithDelay(delay, function(event)
		if display.isValid(aline) then
			local dt = (event.count * delay) % sep

			aline:SetColor(ArrowRGB())
			aline:SetEndPoints(from.x, from.y, to.x, to.y, dt / sep)
		else
			timer.cancel(event.source)
		end
	end, 0)

	return aline, atimer
end

--
--
--

local Arrows = {
	down = function(x, y) return x, y end,
	left = function(x, y) return -y, x end,
	right = function(x, y) return y, x end,
	up = function(x, y) return x, -y end
}

-- Curvature radius of tail --
local Radius = 5

-- Tail-to-head length --
local Stem = 10

-- Length from head vertex to center of nub --
local Head = 3

-- Curved nub on head wing --
local WingNub = 4

-- Number of curve segments per quadrant --
local N = 5

--
local function BuildArrow ()
	Index = 0

	-- Write the points directly into our arrows buffer.
	Arrows, Points = Points, Arrows

	-- Start with the tail point...
	AddPoint(0, 0)

	-- ...then do half of its curve...
	local half_pi = pi / 2

	for i = 1, N do
		local angle = half_pi * (1 + i / N)

		AddPoint(cos(angle) * Radius, (1 - sin(angle)) * Radius)
	end

	-- ...then proceed along the edge down to the head...
	local ystem = Radius + Stem

	AddPoint(-Radius, ystem)

	-- ...now go 45 degrees off to make the shorter side of one of the "wings" that
	-- make up the head...
	local x2, y2 = -(Radius + Head), ystem - Head

	AddPoint(x2, y2)

	-- ...traverse 180 degrees around the nub at the end...
	local ncx, ncy, dn = x2 - WingNub, y2 + WingNub, 2 * N

	for i = 1, dn do
		local angle = pi * i / dn
		local ca, sa = cos(angle), sin(angle)

		AddPoint(ncx + (ca - sa) * WingNub, ncy - (ca + sa) * WingNub)
	end

	-- ...and finally land on the point. (This last stretch is the hypotenuse of a
	-- 45 degree isoceles triangle, so -x will be our increment along y.)
	AddPoint(0, Points[Index] - Points[Index - 1])

	-- Restore the buffers' original roles. The arrow is symmetric, so read back all but
	-- the first and last points in reverse, appending flipped copies of them.
	Arrows, Points = Points, Arrows

	for i = Index - 3, 3, -2 do
		Arrows[#Arrows + 1] = -Arrows[i]
		Arrows[#Arrows + 1] = Arrows[i + 1]
	end
end

--
--
--

--- DOCME
-- @pgroup group Group to which arrow will be inserted.
-- @string dir
-- @number x
-- @number y
-- @treturn DisplayGroup I
function M.StraightArrow (group, dir, x, y)
	-- Lazily build the arrow geometry on first use.
	local n, xform = #Arrows, Arrows[dir]

	if n == 0 then
		BuildArrow()

		n = #Arrows
	end

	--
	Index = 0

	for i = 1, #Arrows, 2 do
		AddPoint(xform(Arrows[i], Arrows[i + 1]))
	end

	return MakePolygon(group, x, y)
end

--
--
--

-- Direction to feed to MakeColumn (since not available through ArrowGroupMaker) --
local Dir

-- Maker that creates a group of arrows in a column formation
local MakeColumn = ArrowGroupMaker(75, function(i, n, dx, dy, offset, agroup)
	if i == 1 then
		local dir = agroup.m_dir or Dir

		agroup.m_dir = dir

		local len = hypot(dx, dy) / 20
		local nx, ny = dx / len, dy / len

		if dir == "backward" then
			agroup.m_nx, agroup.m_ny = -ny, nx
		else
			agroup.m_nx, agroup.m_ny = ny, -nx
		end
	end

	local frac = (i - .5) / n

	return frac * dx + offset * agroup.m_nx, frac * dy + offset * agroup.m_ny
end)

--- DOCME
-- @pgroup group Group to which wall will be inserted.
-- @string dir
-- @number x1
-- @number y1
-- @number x2
-- @number y2
-- @int width
-- @number offset
-- @treturn DisplayGroup J
function M.WallOfArrows (group, dir, x1, y1, x2, y2, width, offset)
	Dir = dir

	return MakeColumn(group, dir == "backward" and "down" or "up", x1, y1, x2, y2, width, offset)
end

--
--
--

_LineOfArrows_ = M.LineOfArrows
_StraightArrow_ = M.StraightArrow
_WallOfArrows_ = M.WallOfArrows

return M