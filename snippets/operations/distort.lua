--- Distortion mixins.

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
local includer = require("solar2d_utils.includer")

-- Solar2D globals --
local display = display

-- Exports --
local M = {}

--
--
--

--- DOCME
M.GET_DISTORT_INFLUENCE = includer.AddSnippet[[
	P_UV float GetDistortInfluence (P_UV vec2 uvn, P_UV float low, P_UV float scale)
	{
		return (1. - smoothstep(low, 1., dot(uvn, uvn))) * scale;
	}
]]

--- DOCME
M.GET_DISTORTED_RGB = includer.AddSnippet{
	vertex = [[

	void InitDistortion (P_POSITION vec2 pos)
	{
		v_DistortPos = pos;
	}
]],

    fragment = ([[

	P_COLOR vec3 GetDistortedRGB (sampler2D s, P_UV vec2 offset)
	{
		P_UV vec2 uv = (v_DistortPos + offset) / vec2(%f, %f);

		return texture2D(s, uv).rgb;
	}
]]):format(display.contentWidth, display.contentHeight),

	varyings = { v_DistortPos = "vec2" }
}

--- DOCME
function M.AttachCanvasToPaint (paint, canvas)
	paint.filename, paint.baseDir = canvas.filename, canvas.baseDir
end

--- DOCME
function M.BindCanvasEffect (object, fill, name)
    object.fill = fill
    object.fill.effect = name
end

return M