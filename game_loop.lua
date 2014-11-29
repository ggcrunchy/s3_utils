--- Functionality for loading game components.

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
local ipairs = ipairs

-- Modules --
local persistence = require("corona_utils.persistence")

-- Exports --
local M = {}

-- Tile names, expanded from two-character shorthands --
local Names = {
	_H = "Horizontal", _V = "Vertical",
	UL = "UpperLeft", UR = "UpperRight", LL = "LowerLeft", LR = "LowerRight",
	TT = "TopT", LT = "LeftT", RT = "RightT", BT = "BottomT",
	_4 = "FourWays", _U = "Up", _L = "Left", _R = "Right", _D = "Down"
}

--- DOCME
function M.DecodeTileLayout (level)
	level.ncols = level.main[1]
	level.start_col = level.player.col
	level.start_row = level.player.row

	for i, tile in ipairs(level.tiles.values) do
		level[i] = Names[tile] or false
	end
end

--- DOCME
function M.ReturnTo_Win (win_scene, alt_scene)
	return function(info)
		if info.why == "won" and info.which > persistence.GetConfig().completed then
			return win_scene
		else
			return alt_scene
		end
	end
end

-- Export the module.
return M