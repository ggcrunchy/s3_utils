--- Tileset-related routines.

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

-- Extension imports --
local copy = table.copy

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local pairs = pairs

-- Modules --
local directories = require("s3_utils.directories")
local mesh = require("s3_utils.tile_texture.mesh")
local tile_layout = require("s3_utils.tile_layout")

-- Solar2D globals --
local display = display
local graphics = graphics
local Runtime = Runtime
local timer = timer

-- Exports --
local M = {}

--
--
--

--
local Names = {
	{ "UpperLeft", "TopT", "UpperRight", "TopNub" },
	{ "LeftT", "FourWays", "RightT", "Vertical" },
	{ "LowerLeft", "BottomT", "LowerRight", "BottomNub" },
	{ "LeftNub", "Horizontal", "RightNub" }
}

local NameToIndex = {}

for ri, row in ipairs(Names) do
	for ci, name in ipairs(row) do
		NameToIndex[name] = (ri - 1) * 4 + ci
	end
end

local Shorthand = { "_H", "_V", "UL", "UR", "LL", "LR", "TT", "LT", "RT", "BT", "_4", "_T", "_L", "_R", "_B" }

local Expansions = {
	_H = "Horizontal", _V = "Vertical",
	UL = "UpperLeft", UR = "UpperRight", LL = "LowerLeft", LR = "LowerRight",
	TT = "TopT", LT = "LeftT", RT = "RightT", BT = "BottomT",
	_4 = "FourWays", _T = "TopNub", _L = "LeftNub", _R = "RightNub", _B = "BottomNub"
}

--- DOCME
function M.GetExpansions ()
	local expansions = {}

	for k, v in pairs(Expansions) do
		expansions[k] = v
	end

	return expansions
end

--
--
--

--- DOCME
function M.GetFrameFromName (name)
	return NameToIndex[name]
end

--
--
--

--- DOCME
function M.GetNames ()
	local names = {}

	for _, short in ipairs(Shorthand) do -- keep order in sync
		names[#names + 1] = Expansions[short]
	end

	return names
end

--
--
--

local Sheet

--- DOCME
function M.GetSheet ()
	return Sheet
end

--
--
--

--- DOCME
function M.GetShorthands ()
	return copy(Shorthand)
end

--
--
--

--- DOCME
function M.NewTile (group, name, x, y, w, h)
	local tile = display.newImageRect(group, Sheet, NameToIndex[name], w, h)

	tile.x, tile.y = x, y

	return tile
end

--
--
--

local Image

local function FindTileset (name)
	name = "." .. name

	for _, dir in directories.IterateForLabel("tilesets") do
		local res = directories.TryRequire(dir .. name)

		if res then
			return res
		end
	end
end

--- DOCME
-- TODO: de-globalize this, e.g. for hub level with mixed tile sets
function M.UseTileset (name)
	local ts = assert(FindTileset(name), "Invalid tileset" .. name)

	if not Image or Image.m_name ~= name then
		local cellw, cellh = tile_layout.GetSizes()
		local w, h, old_w, old_h, update = 4 * cellw, 4 * cellh, -1, -1

		if Image then
			old_w, old_h = Image.width, Image.height

			if w > old_w or h > old_h then
				Image:releaseSelf()

				update, Image = Image.m_update
			end
		end

		if not Image then
			Image = graphics.newTexture{ type = "canvas", width = w, height = h }

			if ts.update then
				update = timer.performWithDelay(ts.update_delay or 100, ts.update, 0)
			elseif ts.delay then
				update = timer.performWithDelay(ts.delay, function()
					if Image then
						Image:invalidate("cache")
					end
				end, 0)
			end
		end

		Image.m_name, Image.m_update, w, h = name, update, Image.width, Image.height

		local cache = Image.cache

		if cache.numChildren == 0 or old_w ~= w or old_h ~= h then
			for i = cache.numChildren, 1, -1 do
				cache:remove(i)
			end

			Sheet = graphics.newImageSheet(Image.filename, Image.baseDir, {
				width = cellw, height = cellh, numFrames = 15,

				sheetContentWidth = w,
				sheetContentHeight = h
			})

			if ts.init then
				ts.init()
			end

			local params, uvs, verts = ts.params

			params.cell_width, params.cell_height = cellw, cellh

			local indices, knots, normals, vertices = mesh.Build(params)

			if ts.prepare_mesh then
				uvs, verts = ts.prepare_mesh(knots, normals, vertices)
			end

			local tmesh = display.newMesh{ indices = indices, uvs = uvs, vertices = verts or vertices, mode = "indexed" }

			if ts.with_mesh then
				ts.with_mesh(tmesh, knots, normals, vertices)
			end

			tmesh.fill.effect = ts.name

			-- TODO: allow snapshot, followed by "real" effect

			Image:draw(tmesh)
		end

		Image:invalidate()

		Runtime:dispatchEvent{ name = "tileset_details_changed" }
	end
end

---
---
--

Runtime:addEventListener("leave_level", function()
	if Image then
		local update = Image.m_update

		if update then
			timer.cancel(update)
		end

		Image:releaseSelf()
	end

	Image, Sheet = nil
end)

--
--
--

Runtime:addEventListener("system", function(event)
	if event.type == "applicationResume" and Image then
		Image:invalidate("cache")
	end
end)

--
--
--

return M