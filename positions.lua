 --- Assorted functionality for positions, which serve mostly as auxiliaries for other
-- game objects.

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

-- Modules --
local tile_layout = require("s3_utils.tile_layout")

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.editor ()
	return {
		self = "position"
	}
end

--
--
--

--- DOCME
-- @ptable info
function M.make (info, params)
	local pos = { m_index = tile_layout.GetIndex(info.col, info.row) }

	tile_layout.PutObjectAt(pos.m_index, pos)

	local psl = params:GetPubSubList()

	psl:Publish(pos, info.uid, "pos")

	local positions = params:GetOrAddData("positions", "table")

	positions[#positions + 1] = pos
end

--
--
--

Runtime:addEventListener("reset", function(level)
	local positions = level.params:GetData("positions")

	for i = 1, #(positions or "") do
		local pos = positions[i]

		tile_layout.PutObjectAt(pos.m_index, pos)
	end
end)

--
--
--

return M