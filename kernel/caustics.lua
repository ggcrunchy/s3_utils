--- A shader used to render some effects on filled regions.

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
local loader = require("corona_shader.loader")

--
--
--

local kernel = { language = "glsl", category = "filter", group = "filler", name = "caustics" }

kernel.vertexData = {
	{ name = "seed", index = 0, default = 0, min = 0, max = 1023 }
}

kernel.isTimeDependent = true

local Code = [[
	_POS_ vec2 GetPosition (_UV_ float epoch)
	{
		_POS_ vec2 p = vec2(epoch) + vec2(0., -3.1);
		
		return vec2(IQ(p.xy), IQ(p.yx));
	}

	_UV_ float GetContribution (_UV_ vec2 uv, P_UV float epoch)
	{
		_POS_ vec2 p = GetPosition(epoch);

		return smoothstep(.375, 0., distance(p, uv));
	}

	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		_UV_ float epoch = (CoronaVertexUserData.x + CoronaTotalTime) / 2., contrib = 0.;

		contrib += GetContribution(uv, epoch) * .125;
		contrib += GetContribution(uv, epoch + 1.) * .125;
		contrib += GetContribution(uv, epoch + 2.) * .125;

		P_COLOR vec4 color = CoronaColorScale(texture2D(CoronaSampler0, uv + contrib * .00625));

		color.rgb *= pow(.87 + contrib, 1.43);
		
		return min(color, vec4(1.));
	}
]]

if system.getInfo("gpuSupportsHighPrecisionFragmentShaders") then
	Code = Code:gsub([[_UV_]], [[P_DEFAULT]])
	Code = Code:gsub([[_POS_]], [[P_DEFAULT]])
else
	Code = Code:gsub([[_UV_]], [[P_UV]])
	Code = Code:gsub([[_POS_]], [[P_POSITION]])
end

kernel.fragment = loader.FragmentShader(Code)

graphics.defineEffect(kernel)

return "filter.filler.caustics"