--- A shader used to render water-like movement.
--
-- Original Author: Predator106
-- Name of Shader: 2D Water Shader
-- [Link to original shader](https://www.shadertoy.com/view/ldXGz7), [Corona Shader Playground Link](http://goo.gl/fBSbWi)

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

local effect = { category = "filter", group = "icyspark",  name = "water" }

effect.fragment = [[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		uv.y += (cos((uv.y + (CoronaTotalTime * 0.04)) * 45.0) * 0.0019) + (cos((uv.y + (CoronaTotalTime * 0.1)) * 10.0) * 0.002);
		uv.x += (sin((uv.y + (CoronaTotalTime * 0.07)) * 15.0) * 0.0029) + (sin((uv.y + (CoronaTotalTime * 0.1)) * 15.0) * 0.002);

		return CoronaColorScale(texture2D(CoronaSampler0, uv));		
	}
]]

graphics.defineEffect(effect)

return "filter.icyspark.water"