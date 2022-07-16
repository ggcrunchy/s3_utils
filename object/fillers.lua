--- Various space-filling operations.

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
local assert = assert
local max = math.max
local min = math.min
local random = math.random
local select = select
local unpack = unpack

-- Extension imports --
local indexOf = table.indexOf

-- Modules --
local audio = require("solar2d_utils.audio")
local flood = require("s3_utils.fill.flood")
local tile_layout = require("s3_utils.tile_layout")

-- Effects --
local caustics_effect = require("s3_utils.effect.caustics")

-- Solar2D globals --
local display = display
local timer = timer

-- Exports --
local M = {}

--
--
--

local Batch

--- Add a region of tiles to the batch, to be filled in by the effect.
-- @uint ul Index of upper-left tile in region...
-- @uint lr ...and lower-left tile.
function M.AddRegion (ul, lr)
	assert(Batch.group, "No batch running")

	local n = Batch.n or 0

	Batch[n + 1], Batch[n + 2], Batch.n = ul, lr, n + 2
end

--
--
--

local Color = {}

--- Begin a fill batch in color mode.
-- @pgroup group Group which will receive fill components.
-- @param ... Color components, as per **object:setFillColor**.
function M.Begin_Color (group, ...)
	assert(not Batch.group, "Batch already in progress")

	Batch.group, Batch.ncomps, Color[1], Color[2], Color[3], Color[4] = group, select("#", ...), ...
end

--
--
--

--- Begin a fill batch in image mode.
-- @pgroup group Group which will receive fill components.
-- @string name Filename of image.
function M.Begin_Image (group, name)
	assert(not Batch.group, "Batch already in progress")

	Batch.group, Batch.name = group, name
end

--
--
--

local Methods = { flood_fill = flood }

local Sounds = audio.NewSoundGroup{
	path = "gfx/game/player",
	shape_filled = { file = "ShapeFilled.mp3", wait = 1000 }
}

local Running

local FillOpts = {
	on_done = function(timer)
		Sounds:PlaySound("shape_filled")

		local i, n = indexOf(Running, timer), #Running

		Running[i] = Running[n]
		Running[n] = nil
	end
}

--- Commit the batch, launching an effect.
-- @string[opt="flood_fill"] how Fill method applied to added regions.
function M.End (how)
	local n, method = Batch.n, assert(Methods[how or "flood_fill"], "Invalid fill method")

	assert(n and n > 0, "No regions added")

	-- Lazily load sounds on first fill.
	Sounds:Load()

	-- Find the extents of the amalgamated regions.
	local maxc, maxr, minc, minr = 1, 1, tile_layout.GetCounts()

	for i = 1, n, 2 do
		local ulc, ulr = tile_layout.GetCell(Batch[i])
		local lrc, lrr = tile_layout.GetCell(Batch[i + 1])

		minc, maxc = min(ulc, minc), max(lrc, maxc)
		minr, maxr = min(ulr, minr), max(lrr, maxr)
	end

	-- Get the cell-wise dimensions and prepare the effect.
	local nx, ny, back = maxc - minc, maxr - minr
	local minc2, minr2 = minc + 1, minr + 1

	method.Prepare(nx, ny)

	-- Turn each region into cells and submit them to the effect.
	local ncomps, w, h = Batch.ncomps, tile_layout.GetSizes()
	local x, y = (minc + maxc - 1) * w / 2, (minr + maxr - 1) * h / 2

	w, h = (maxc - minc) * w, (maxr - minr) * h

	if ncomps then
		back = display.newRect(Batch.group, x, y, w, h)

		back:setFillColor(unpack(Color, 1, ncomps))
	else
		back = display.newImageRect(Batch.group, Batch.name, w, h)

		back.x, back.y = x, y
	end

	back.fill.effect = caustics_effect

	back.fill.effect.seed = random(1024)

	for i = 1, display.isValid(back) and n or 0, 2 do
		local ul, lr = Batch[i], Batch[i + 1]
		local ulc, ulr = tile_layout.GetCell(ul)
		local lrc, lrr = tile_layout.GetCell(lr)

		for dr = ulr - minr, lrr - minr2 do
			for dc = ulc - minc, lrc - minc2 do
				method.Add(dc + 1, dr + 1, true)
			end
		end
	end

	-- Launch the effect and clear all temporary state.
	Running[#Running + 1] = method.Run(back, FillOpts)

	Batch.n, Batch.group, Batch.name, Batch.ncomps = 0
end

--
--
--

local function CancelRunning ()
	for i = 1, #Running do
		timer.cancel(Running[i])
	end
end

Runtime:addEventListener("leave_level", function()
	CancelRunning()

	Batch, Running = nil
end)

--
--
--

Runtime:addEventListener("reset", function()
	CancelRunning()

	Batch, Running = {}, {}
end)

--
--
--

Runtime:addEventListener("things_loaded", function()
	Batch, Running = {}, {}
end)

--
--
--

return M