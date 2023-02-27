--- This module deals with the grid of tiles (and their metadata) underlying the level.

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
local remove = table.remove

-- Modules --
local builders = require("s3_utils.tile_texture.builders")
local enums = require("s3_utils.enums")
local movement = require("s3_utils.movement")
local numeric = require("s3_utils.numeric")
local tile_flags = require("s3_utils.tile_flags")
local tile_layout = require("s3_utils.tile_layout")
local tile_texture_utils = require("s3_utils.tile_texture.utils")

-- Solar2D globals --
local display = display

-- Module --
local M = {}

--
--
--

tile_texture_utils.SetProp("corner_count", 7)
tile_texture_utils.SetProp("layer_count", 10)
tile_texture_utils.SetProp("inside_curve_count", 6)
tile_texture_utils.SetProp("rectangle_count", 10)
tile_texture_utils.SetProp("outside_nub_count", 18)
tile_texture_utils.SetProp("offset", 8)
tile_texture_utils.SetProp("tangent", 15)
tile_texture_utils.SetProp("tangent_step", 16)

--
--
--

local Left, Right, Up, Down = enums.GetFlagByName("left"), enums.GetFlagByName("right"), enums.GetFlagByName("up"), enums.GetFlagByName("down")

local NameToFlags = {
	Horizontal = Left + Right, Vertical = Up + Down,

	UpperLeft = Right + Down, LowerLeft = Right + Up,
	UpperRight = Left + Down, LowerRight = Left + Up,

	LeftNub = Right, RightNub = Left,
	BottomNub = Up, TopNub = Down
}

NameToFlags.TopT = NameToFlags.Horizontal + Down
NameToFlags.LeftT = NameToFlags.Vertical + Right
NameToFlags.RightT = NameToFlags.Vertical + Left
NameToFlags.BottomT = NameToFlags.Horizontal + Up
NameToFlags.FourWays = NameToFlags.Horizontal + NameToFlags.Vertical

--
--
--

local function AuxBuildComponent (index, visited, names, id, sources, top, left)
  if visited[-index] == id then
		local x, y = tile_layout.GetPosition(index)
    local w, h = tile_layout.GetSizes()

    local hw, hh = w / 2, h / 2

    tile_texture_utils.SetProp("x1", x - hw)
    tile_texture_utils.SetProp("y1", y - hh)
    tile_texture_utils.SetProp("x2", x + hw - 1)
    tile_texture_utils.SetProp("y2", y + hh - 1)

    return builders.Call(names[index], sources, top, left)
  end
end

--
--
--

local function AuxGatherComponent (index, visited, names, ncols, id)
  if names[index] and not visited[-index] then
    visited[#visited + 1], id = index, id + 1

    while #visited > 0 do
      index = remove(visited)
      visited[-index] = id

      for dir in tile_flags.GetDirections(index) do
        local nindex = index + movement.GetTileDelta(dir, ncols)

        if not visited[-nindex] then
          visited[#visited + 1] = nindex
        end
      end
    end
  end

  return id
end

--
--
--

--- Add a set of tiles to the level, adding and resolving the associated flags.
--
-- Currently, this is assumed to be a one-time operation on level load.
-- @pgroup group Group to which tiles are added.
-- @callable tileset TODO
-- @array names Names of tiles, from upper-left to lower-right (left to right over each row).
--
-- Unrecognized names will be left blank (the editor names blank tiles **false**). The array
-- is padded with blanks to ensure its length is a multiple of the columns count.
-- @see s3_utils.tile_flags.Resolve
function M.AddTiles (group, tileset, names)
	local ncols, index, n = tile_layout.GetCounts(), 1, #names

	while index <= n do
		for _ = 1, ncols do
			local name = names[index]

			tile_flags.SetFlags(index, NameToFlags[name])

			index = index + 1
		end
	end

	tile_flags.Resolve()

  --
  --
  --

  local visited, max_id = {}, 0

  for i = 1, n do
    max_id = AuxGatherComponent(i, visited, names, ncols, max_id)
  end

  --
  --
  --

  local mg, mn = tileset.modify_geometry, tileset.merge_normals

  for id = 1, max_id do
    index = 1

    local vs, uvs = {}, {}
    local sources, tops, left = { indices = {}, vertices = vs, uvs = uvs }, {}

    if mn then
      sources.normals = {}
    end

    --
    --
    --

    while index <= n do
      for col = 1, ncols do
        index, tops[col], left = index + 1, AuxBuildComponent(index, visited, names, id, sources, tops[col], left)
      end

      left = nil
    end
    
    --
    --
    --

    if mg then
      mg(sources)
    end

    --
    --
    --

    for i = 2, #vs, 2 do
      local vnoise = numeric.SampleNoise(vs[i - 1], vs[i] * 3.1)

      uvs[i] = (vnoise % 1) * .725 + uvs[i] * .1625
    end

    --
    --
    --

    if mn then
      mn(sources)
    end

    --
    --
    --

    local mesh = display.newMesh{ parent = group, mode = "indexed", indices = sources.indices, vertices = vs, uvs = uvs }

    mesh:translate(mesh.path:getVertexOffset())

    mesh.fill.effect = tileset.name
  end
end

--
--
--

return M