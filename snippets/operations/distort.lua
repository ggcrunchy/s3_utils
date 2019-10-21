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
local includer = require("corona_utils.includer")

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

local PosVarying, PosVaryingType = "v_Pos", "P_POSITION vec2"

--- DOCME
M.GET_DISTORTED_RGB = includer.AddSnippet{
    fragment = ([[

	P_COLOR vec3 GetDistortedRGB (sampler2D s, P_UV vec2 offset, P_UV vec3 divs_alpha)
	{
		P_UV vec2 uv = (%s + offset) * divs_alpha.xy;

		return texture2D(s, uv).rgb * divs_alpha.z;
	}

	P_COLOR vec3 GetDistortedRGB (sampler2D s, P_UV vec2 offset, P_UV vec4 divs_alpha)
	{
		return GetDistortedRGB(s, offset, divs_alpha.xyz);
	}
]]):format(PosVarying)

}
-- ^^ TODO: vertex textures...

--- DOCME
function M.BindCanvasEffect (object, fill, name)
    object.fill = fill
    object.fill.effect = name
    object.fill.effect.xdiv = 1 / display.contentWidth -- TODO...
    object.fill.effect.ydiv = 1 / display.contentHeight
end

--- DOCME
function M.CanvasToPaintAttacher (paint)
    return function(event)
        if event.canvas then
            paint.filename = event.canvas.filename
            paint.baseDir = event.canvas.baseDir
        end
    end
end

local PosVaryingDecl = ("%s %s"):format(PosVaryingType, PosVarying)

local PassThroughVertexKernel = ([[
	varying %s;

	P_POSITION vec2 VertexKernel (P_POSITION vec2 pos)
	{
		v_Pos = pos;

		return pos;
	}
]]):format(PosVaryingDecl)

--- DOCME
function M.GetPassThroughVertexKernelSource ()
	return PassThroughVertexKernel
end

--- DOCME
function M.GetPosVaryingName ()
	return PosVarying
end

--- DOCME
function M.GetPosVaryingType ()
	return PosVaryingType
end

local Prelude = ([[
	varying %s;

]]):format(PosVaryingDecl)

--- DOCME
function M.GetPrelude ()
	return Prelude
end

--- DOCME
function M.KernelParams ()
    return {
        { index = 0, name = "xdiv" },
        { index = 1, name = "ydiv" },
        { index = 2, name = "alpha", default = 1, min = 0, max = 1 }
    }
end

return M