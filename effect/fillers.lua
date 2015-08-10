--- Various space-filling operations.
--
-- This module lays claim to the **"filler"** set, cf. @{s3_utils.effect.stash}.

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
local ceil = math.ceil
local format = string.format
local pairs = pairs

-- Modules --
local audio = require("corona_utils.audio")
local circle = require("s3_utils.fill.circle")
local color = require("corona_ui.utils.color")
local grid = require("tektite_core.array.grid")
local length = require("tektite_core.number.length")
local powers_of_2 = require("bitwise_ops.powers_of_2")
local sheet = require("corona_utils.sheet")
local stash = require("s3_utils.effect.stash")
local timers = require("corona_utils.timers")

-- Corona globals --
local display = display
local transition = transition

-- Exports --
local M = {}

-- Tile dimensions --
local TileW, TileH

-- Image sheets, cached from fill images used on this level --
local ImageCache



-- --
local Batch = {}

--- DOCME
-- @pgroup group
-- @param ... ARGS
function M.Begin_Color (group, ...)
	assert(not Batch.group, "Batch already begun")

	Batch.group, Batch.color = group, color.PackColor_Number(...)
end

--- DOCME
-- @pgroup group
-- @string name
function M.Begin_Image (group, name)
	assert(not Batch.group, "Batch already begun")
end

--- DOCME
-- @number ulx
-- @number uly
-- @number lrx
-- @number lry
function M.AddRegion (ulx, uly, lrx, lry)
	local group = assert(Batch.group, "No batch running")

	if display.isValid(group) then
		local color, name = Batch.color, Batch.name

		if color then
			--
		else
			--
		end
	end
end

--- DOCME
-- @string[opt="flood_fill"] how X
function M.End (how)
	assert(#Batch > 0, "No regions added")

	--
	local color, group, name = Batch.color, Batch.group, Batch.name

	if color then
		--
	else
		--
	end

	Batch.color, Batch.group, Batch.name = nil
end


-- Current fill color for non-images --
local R, G, B = 1, 1, 1

-- Name of fill image --
local UsingImage

-- Fade-in transition --
local FadeInParams = {
	time = 300, alpha = 1, transition = easing.inOutExpo,

	onComplete = function(rect)
		local rgroup = rect.parent

		rgroup.m_unfilled = rgroup.m_unfilled - 1
	end
}

-- Sound played when shape is filled --
local Sounds = audio.NewSoundGroup{ _prefix = "SFX", shape_filled = { file = "ShapeFilled.mp3", wait = 1000 } }

-- Fill transition --
local FillParams = {
	time = 1350, transition = easing.outBounce,

	onComplete = function()
		Sounds:PlaySound("shape_filled")
	end
}

--
local function StashPixels (event)
	stash.PushRect("filler", event.m_object, "is_group")
end

do
	-- Kernel --
	local kernel = { category = "filter", group = "fill", name = "circle" }

	kernel.vertexData = {
		{
			name = "dist",
			default = 0, min = 0, max = math.sqrt(2),
			index = 0
		},
		{
			name = "upper",
			default = 0, min = 0, max = 1,
			index = 1
		},
	}

	kernel.fragment = [[
		P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
		{
			P_UV float len = length(uv - .5);

			return CoronaColorScale(texture2D(CoronaSampler0, uv) * smoothstep(-.017, CoronaVertexUserData.y, CoronaVertexUserData.x - len));
		}
	]]

	graphics.defineEffect(kernel)
end

--- Fills a rectangular region gradually over time, according to a fill process.
--
-- If an image has been assigned with @{SetImage}, it will be used to fill the region.
-- Otherwise, the region is filled with a solid rectangle, tinted according to @{SetColor}.
--
-- Calling @{SetColor} or @{SetImage} will not affect a fill already in progress.
-- @pgroup group Group into which fill graphics are loaded.
-- @string[opt="circle"] how The fill process, which currently may be **"circle"**.
-- @number ulx Upper-left x-coordinate...
-- @number uly ...and y-coordinate.
-- @number lrx Lower-right x-coordinate...
-- @number lry ...and y-coordinate.
-- @treturn DisplayObject "Final" result of fill. Changing its parameters during the fill
-- may lead to strange results. It can be removed to cancel the fill.
function M.Fill (group, how, ulx, uly, lrx, lry)
	-- Lazily load sounds on first fill.
	Sounds:Load()

	-- Prepare the "final" object, that graphically matches the composite fill elements
	-- and will be left behind in their place once the fill operation is complete. Kick
	-- off the fill transition; as the object scales, the fill process will update to
	-- track its dimensions.
	local filler

	if UsingImage then
		filler = display.newImage(group, UsingImage)
	else
		filler = display.newRect(group, 0, 0, 1, 1)
	end

	local cx, w = (ulx + lrx) / 2, TileW / 2
	local cy, h = (uly + lry) / 2, TileH / 2

	filler.x, filler.width = cx, w
	filler.y, filler.height = cy, h

	FillParams.width = lrx - ulx
	FillParams.height = lry - uly

	transition.to(filler, FillParams)

	-- Extract useful effect values from the fill dimensions.
	local tilew, tileh = TileW / 2.5, TileH / 2.5
	local halfx, halfy = ceil(FillParams.width / tilew - 1), ceil(FillParams.height / tileh - 1)
	local nx, ny = halfx * 2 + 1, halfy * 2 + 1
	local dw, dh = FillParams.width / nx, FillParams.height / ny

	-- Save the current fill color or image. In the image case, tile it, then cache the
	-- tiling, since it may be reused, e.g. on level reset; if a tiling already exists,
	-- use that.
	local r, g, b = R, G, B
	local cur_image

	if UsingImage then
		local key = format("%s<%i,%i>", UsingImage, nx, ny)

		cur_image = ImageCache[key]

		if not cur_image then
			cur_image = { mid = halfy * nx + halfx + 1 }

			cur_image.isheet = sheet.TileImage(UsingImage, nx, ny)

			ImageCache[key] = cur_image
		end
	else
		filler:setFillColor(r, g, b)
	end

	-- Circle --
	if how == "circle" then
		local rgroup = display.newGroup()

		group:insert(rgroup)

		rgroup.m_unfilled = nx * ny

		-- A circle, quantized into subrectangles, which are faded in as the radius grows.
		-- In the image case, the rect will be an unanimated (??) sprite generated by the
		-- image tiling; otherwise, we pull the rect from the stash, if available. On each
		-- addition, a "spots remaining" counter is decremented. 
		local spread = circle.SpreadOut(halfx, halfy, function(x, y)
			local rx, ry, rect = cx + (x - .5) * dw, cy + (y - .5) * dh

			if cur_image then
				local index = cur_image.mid + y * nx + x

				rect = sheet.NewImageAtFrame(rgroup, cur_image.isheet, index, rx, ry, dw, dh)

				rect.xScale = dw / rect.width
				rect.yScale = dh / rect.height
			else
				rect = stash.PullRect("filler", rgroup)

				rect.x, rect.width = rx + dw / 2, dw
				rect.y, rect.height = ry + dh / 2, dh

				rect:setFillColor(r, g, b)
			end

			rect.alpha = .05

			transition.to(rect, FadeInParams)
		end)

		-- The final object begins hidden, since it will be built up visually from the fill
		-- components. Over time, fit its current shape to a circle and act in that region.
--[[
		filler.isVisible = false

		timers.RepeatEx(function()
			if display.isValid(filler) then
				local radius = length.ToBin_RoundUp(filler.width / dw, filler.height / dh, 1.15, .01)

				spread(radius)

				-- If there are still spots in the region to fill, quit. Otherwise, show the
				-- final result and go on to the next steps.
				if rgroup.m_unfilled ~= 0 then
					return
				end

				filler.isVisible = true
			end

			-- If the fill finished or was cancelled, we remove the intermediate components.
			-- In the case of an image, it's too much work to salvage anything, so just remove
			-- the group. Otherwise, stuff the components back into the stash.
			timers.DeferIf(cur_image and "remove" or StashPixels, rgroup)

			return "cancel"
		end, 45)]]
		filler.fill.effect = "filter.fill.circle"

		transition.to(filler.fill.effect, { dist = math.sqrt(2), upper = .557, time = 1100 })

	-- Other options: random fill, cross-fade, Hilbert...
	else
		
	end

	return filler
end

--- Setter.
-- @byte r Red component of fill color. If absent, old value is retained (by default, 1).
-- @byte g ...green component, likewise...
-- @byte b ...and blue component.
function M.SetColor (r, g, b)
	R, G, B = r or R, g or G, b or B
end

--[[
	-- Version 2 API:

	M.Begin_Color (...) -- puts into tile collection mode, using a color (various Corona formats); asserts "Not begun"
	M.Begin_Image (name) -- alternative, using an image; asserts "Not begun"
	M.AddRegion (ulx, uly, lrx, lry) -- as in Fill(); populates underlying cells() structure, rather than via __index; asserts "Begun"
	M.End (how) -- commit all regions, use whatever method (at first, just flood fill); asserts "Begun", regions added and connected
]]

--- Setter.
-- @string name Filename of fill image, or **nil** to clear the image.
function M.SetImage (name)
	UsingImage = name
end

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		ImageCache = {}
		TileW = level.w
		TileH = level.h
	end,

	-- Leave Level --
	leave_level = function()
		ImageCache = nil
	end,

	-- Reset Level --
	reset_level = function()
		for k in pairs(ImageCache) do
			ImageCache[k] = nil
		end
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M

--[[
local Funcs = {
	-- Left --
	function(x, y, xoff, yoff, xmax)
		local index = grid.CellToIndex(x - 1, y, xmax)

		if xoff > 0 then
			return index
		elseif if x > 1 then
			return index, -1, 2^(4 + yoff), 2^(8 + yoff)
		end
	end,

	-- Right --
	function(x, y, xoff, yoff, xmax)
		local index = grid.CellToIndex(x + 1, y, xmax)

		if xoff < 3 then
			return index
		elseif x < xmax then
			return index, 1, 2^(8 + yoff), 2^(4 + yoff)
		end
	end,

	-- Up --
	function(x, y, xoff, yoff, xmax)
		local index = grid.CellToIndex(x, y - 1, xmax)

		if yoff > 0 then
			return index
		elseif y > 1 then
			return index, -nx, 2^xoff, 2^(12 + xoff)
		end
	end,

	-- Down --
	function(x, y, xoff, yoff, ymax)
		local index = grid.CellToIndex(x, y + 1, xmax)

		if yoff < 3 then
			return index
		elseif y < ymax then
			return index, nx, 2^(12 + xoff), 2^xoff
		end
	end
}

timer.performWithDelay(100, coroutine.wrap(function(e)
	--
	local cw, ch = display.contentWidth, display.contentHeight

	local cells = {}

	local nx, ny = math.ceil(cw / SpriteDim), math.ceil(ch / SpriteDim) -- use TileW, TileH, and... contentBounds?
	local xmax, ymax = nx * CellCount, ny * CellCount
	local xx, yy = math.floor(xmax / 2), math.floor(ymax / 2)

	setmetatable(cells, {
		__index = function(t, k)
			local rect = display.newRect(0, 0, SpriteDim, SpriteDim)

			rect.anchorX, rect.anchorY = 0, 0

			rect:setFillColor(...)

			rect.fill.effect = "filter.custom.grid4x4"

			local col, row = grid.IndexToCell(k, nx)
			rect.x, rect.y = (col - 1) * SpriteDim, (row - 1) * SpriteDim

			t[k] = rect

			return rect
		end
	})
	-- ^^^ Most, if not all, of this will be unneeded, on account of being done in AddRegion()

	local work, idle, used = {}, {}, {} -- Just keep a cache? match_id_slot on used?
	local i1 = grid.CellToIndex(xx, yy, xmax) -- better idea: choose middle-most of regions, then center of that

	work[#work + 1], used[i1] = i1, true

	--
	local max, random, ipairs = math.max, math.random, ipairs

	while true do -- TODO: Make this a boring old timer
		local nwork, nidle = #work, #idle

		for _ = 1, 35 do -- NumIterations
			--
			local to_process = random(40, 50) -- NumToProcess

			if nwork < to_process then
				for _ = nidle, max(1, nidle - to_process), -1 do
					local index = random(nidle)

					nwork, work[nwork + 1] = nwork + 1, s2[index]
					idle[index] = idle[nidle]
					nidle, idle[nidle] = nidle - 1
				end
			end

			--
			for _ = nwork, max(1, nwork - to_process), -1 do
				--
				local index = random(nwork)
				local x, y = grid.IndexToCell(work[index], xmax)
				local xb, yb = floor((x - 1) * .25), floor((y - 1) * .25)
				local xoff, yoff = x - xb * 4 - 1, y - yb * 4 - 1
				local bit = 2^(yoff * 4 + xoff)
				local ci = yb * nx + xb + 1
				local ceffect = cells[ci].fill.effect

				ceffect.bits = ceffect.bits + bit

				--
				for _, func in ipairs(Funcs) do
					local si, delta, nbit_self, nbit_other = func(x, y, xoff, yoff)

					if si then
						if delta then
							local neffect = cells[ci + delta].fill.effect
							local cn, nn = ceffect.neighbors, neffect.neighbors

							if not powers_of_2.IsSet(cn, nbit_self) then
								ceffect.neighbors = cn + nbit_self
							end

							if not powers_of_2.IsSet(nn, nbit_other) then
								neffect.neighbors = nn + nbit_other
							end
						end

						if not used[si] then
							idle[nidle + 1], used[si], nidle = si, true, nidle + 1
						end
					end
				end

				--
				work[index] = work[nwork]
				nwork, work[nwork] = nwork - 1
			end
		end

		coroutine.yield()
	end
end), 0)
]]