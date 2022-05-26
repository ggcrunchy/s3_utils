--- Loading, running, and unloading of game levels.

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
local ipairs = ipairs
local yield = coroutine.yield

-- Modules --
local _ = require("config.Directories")
local directories = require("s3_utils.directories")
local tile_layout = require("s3_utils.tile_layout")
local tile_maps = require("s3_utils.tile_maps")
local tilesets = require("s3_utils.tilesets")

-- Solar2D globals --
local display = display
local graphics = graphics
local Runtime = Runtime
local system = system

-- Exports --
local M = {}

--
--
--

local TypeToFactories = {}

local function FindModule (ttype)
	local sep, label, what = ttype:find("%.")

	if sep then
		assert(sep > 1 and sep < #ttype, "Missing prefix or suffix")

		label, what = ttype:sub(1, sep - 1), ttype:sub(sep) -- n.b. keep the separator...

		assert(label ~= "default", "Thing cannot explicitly have `default` label")
	else
		label, what = "default", "." .. ttype -- ...and manually add it here
	end

	for _, dir in directories.IterateForLabel(label) do
		local res = directories.TryRequire(dir .. what)

		if res then
			return res
		end
	end
end

local function AuxAddThing (info, params)
	local ttype = info.type
	local factories = TypeToFactories[ttype]

	if not factories then
		local mod = FindModule(ttype)

		factories, TypeToFactories[ttype] = mod, mod
	end

	factories.make(info, params)
end

--- DOCME
function M.AddThings (level, params)
	tilesets.UseTileset(level.tileset or "Tree")

	local tgroup = display.newGroup()

	params:GetLayer("tiles"):insert(tgroup)

	tile_maps.AddTiles(tgroup, tilesets.NewTile, level)

	local things = level.things

	for i = 1, #(things or "") do
		AuxAddThing(things[i], params)
	end
end

--
--
--

local Groups = { "game", "canvas", "game_dynamic", "hud", "borders" }

local function InvalidateCanvas (canvas_rect)
  local canvas = canvas_rect.m_canvas

  if canvas.invalidate then -- Cleanup() might be called before WipeCanvasRect()
    canvas:invalidate("cache")
  end
end

local function SetCanvasRectAlpha (canvas_rect, event)
	canvas_rect.alpha = event.alpha
end

local function WipeCanvasRect (event)
  Runtime:removeEventListener("enterFrame", event.target)
  Runtime:removeEventListener("set_canvas_alpha", event.target)
end

--- DOCME
function M.BeforeEntering (w, h)
	return function(view, current_level, level, level_list)
		local ncols, nrows = level.ncols, ceil(#level / level.ncols)

		tile_layout.SetCounts(ncols, nrows)
		tile_layout.SetSizes(w, h)

		current_level.groups = {}

		for _, name in ipairs(Groups) do
			current_level.groups[name] = display.newGroup()

			view:insert(current_level.groups[name])
		end

		-- Rig up a canvas that captures certain layers for use in post-processing.
    local cw, ch = display.contentWidth, display.contentHeight
		local canvas = graphics.newTexture{ type = "canvas", width = cw, height = ch }

		canvas:draw(current_level.groups.game)

		local canvas_rect = display.newImageRect(current_level.groups.canvas, canvas.filename, canvas.baseDir, cw, ch)

		canvas.anchorX, canvas_rect.x = -.5, display.contentCenterX
		canvas.anchorY, canvas_rect.y = -.5, display.contentCenterY

    canvas_rect.m_canvas = canvas

    canvas_rect.enterFrame = InvalidateCanvas
    canvas_rect.set_canvas_alpha = SetCanvasRectAlpha

		Runtime:addEventListener("enterFrame", canvas_rect)
    Runtime:addEventListener("set_canvas_alpha", canvas_rect)
		canvas_rect:addEventListener("finalize", WipeCanvasRect)

		-- Give it a frame to take hold, and finish up.
		yield()

    current_level.canvas = canvas

		-- Add game group layers and export them for things.
		current_level.layers = {}

		for i, name in ipairs{
      "background", "tiles", -- in "game" group
      "decals", -- shadows, etc.
      "things1", -- dots beneath player
      "things2", -- player, on ground
      "things3", -- dots above player (consumables)
      "things4", -- enemies, projectiles, player when jumping, etc.
      "markers" -- UI, etc.
    } do
			local layer = display.newGroup()

			current_level.layers[name] = layer

			current_level.groups[i > 2 and "game_dynamic" or "game"]:insert(layer)
		end

		-- Add the level background, falling back to a decent default if none was given.
		local background_func = level.background or level_list.DefaultBackground

		background_func(current_level.layers.background)

		-- Enforce true letterbox mode.
		if display.screenOriginX ~= 0 then
			for i = 1, 2 do
				local border = display.newRect(current_level.groups.borders, 0, display.contentCenterY, -display.screenOriginX, ch)

				border:setFillColor(0)

				border.anchorX, border.x = i == 1 and 1 or 0, i == 1 and 0 or cw
			end
		end
	end
end

--
--
--

--- DOCME
function M.Cleanup (current_level)
	for _, name in ipairs(Groups) do
		if name ~= "game" then -- not in canvas?
			display.remove(current_level and current_level.params:GetGroup(name))
		end
	end

	current_level.canvas:releaseSelf()
end

--
--
--

-- Tile names, expanded from two-character shorthands --
local Expansions = tilesets.GetExpansions()

--- DOCME
function M.DecodeTileLayout (level)
	level.ncols = level.main[1]
	level.start_col = level.player.col
	level.start_row = level.player.row

	for i, tile in ipairs(level.tiles.values) do
		level[i] = Expansions[tile] or false
	end
end

--
--
--

--- DOCME
function M.ReturnTo_Win (win_scene, alt_scene)
	return function(info)
		if info.why == "won" and info.which > (system.getPreference("app", "completed", "number") or 0) then
			return win_scene
		else
			return alt_scene
		end
	end
end

--
--
--

return M