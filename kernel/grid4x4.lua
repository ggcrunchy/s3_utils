--- Shaders used to render parts of a 4x4 grid according to bit flags.

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

-- Common vertex userdata components --
local UberVertexData = {
	-- These indicate which cells in the underlying 4x4 grid are active. The following
	-- diagram shows the correspondence between cell and bit index:
	--
	-- +----+----+----+----+
	-- |  0 |  1 |  2 |  3 |
	-- +----+----+----+----+
	-- |  4 |  5 |  6 |  7 |
	-- +----+----+----+----+
	-- |  8 |  9 | 10 | 11 |
	-- +----+----+----+----+
	-- | 12 | 13 | 14 | 15 |
	-- +----+----+----+----+
	bits = { default = 0, min = 0, max = 65535 },

	-- These indicate which cells around the underlying 4x4 grid are active, for purposes
	-- of filtering. The following diagram shows cell / bit index correspondence:
	--
	--     |  0 |  1 |  2 |  3 |
	-- ----+----+----+----+----+----
	--   4 |    |    |    |    |  8
	-- ----+----+----+----+----+----
	--   5 |    |    |    |    |  9
	-- ----+----+----+----+----+----
	--   6 |    |    |    |    | 10
	-- ----+----+----+----+----+----
	--   7 |    |    |    |    | 11
	-- ----+----+----+----+----+----
	--     | 12 | 13 | 14 | 15 |
	neighbors = { default = 0, min = 0, max = 65535 },

	-- Center x, for image sheets...
	x = { default = 0, min = -65536, max = 65536 },

	-- ...and center y.
	y = { default = 0, min = -65536, max = 65536 }
}

-- Helper to add a new vertex userdatum
local function AddDatum (kernel, name)
	local ud = kernel.vertexData
	local index, from = #ud, UberVertexData[name]

	ud[index + 1] = { name = name, index = index, default = from.default, min = from.min, max = from.max }
end

-- Common vertex body --
local UberVertex = [[
#ifdef USE_NEIGHBORS
	varying P_UV float v_Top, v_Left, v_Right, v_Bottom;
#endif

#ifdef IMAGE_SHEET
	varying P_UV vec2 v_UV;
#endif

#if !defined(GL_FRAGMENT_PRECISION_HIGH) || defined(USE_NEIGHBORS)
	varying P_UV float v_Low, v_High;
#endif

	P_POSITION vec2 VertexKernel (P_POSITION vec2 pos)
	{
	#if !defined(GL_FRAGMENT_PRECISION_HIGH) || defined(USE_NEIGHBORS)
		// In devices lacking high-precision fragment shaders, break the bit pattern
		// into two parts. For simplicity, do this when using neighbors as well.
		v_Low = mod(CoronaVertexUserData.x, 256.); // x = bits
		v_High = (CoronaVertexUserData.x - v_Low) / 256.;
	#endif

	#ifdef IMAGE_SHEET
		v_UV = step(CoronaVertexUserData.zw, pos); // zw = center
	#endif

	#ifdef USE_NEIGHBORS
		v_Top = mod(CoronaVertexUserData.y, 16.); // y = neighbors
		v_Left = mod(floor(CoronaVertexUserData.y * (1. / 16.)), 16.);
		v_Right = mod(floor(CoronaVertexUserData.y * (1. / 256.)), 16.);
		v_Bottom = floor(CoronaVertexUserData.y * (1. / 4096.));
	#endif

		return pos; // when no defines were provided, this is just a vertex pass-through
	}
]]

-- Common fragment body --
local UberFragment = [[
#ifdef USE_NEIGHBORS
	varying P_UV float v_Top, v_Left, v_Right, v_Bottom;
#endif

#ifdef IMAGE_SHEET
	varying P_UV vec2 v_UV;
#endif
	
#if !defined(GL_FRAGMENT_PRECISION_HIGH) || defined(USE_NEIGHBORS)
	varying P_UV float v_Low, v_High;
#endif

#ifdef USE_NEIGHBORS
	P_UV float AddFactor (P_UV float neighbor, P_UV vec2 pos, P_UV float offset, P_UV float which)
	{
		P_UV float cell = dot(floor(pos), vec2(1., 4.));
		P_UV float high = step(8., cell);
		P_UV float n = mix(offset, cell - high * 8., which), v = mix(neighbor, mix(v_Low, v_High, high), which);
		P_UV float power = exp2(n);

		return step(power, mod(v, 2. * power));
	}
#endif

	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		// Fit the position to a 4x4 grid and flatten that to an index in [0, 15].
	#ifdef IMAGE_SHEET
		P_UV vec2 scaled = floor(v_UV * 4.);
	#else
		P_UV vec2 scaled = floor(uv * 4.);
	#endif

		P_UV float cell = dot(scaled, vec2(1., 4.));

	#if defined(GL_FRAGMENT_PRECISION_HIGH) && !defined(USE_NEIGHBORS)
		// With high precision available, it is safe to go up to 2^16, thus all integer
		// patterns are already representable.
		P_DEFAULT float power = exp2(cell), value = CoronaVertexUserData.x;
	#else
		// Since medium precision only promises integers up to 2^10, the vertex kernel
		// will have broken the bit pattern apart as two 8-bit numbers. Choose the
		// appropriate half and power-of-2. This path is also used in the presence of
		// neighbors, since the vertex kernel is then necessary anyhow and AddFactor()
		// can be implemented without much hassle if `value` is known to be mediump.
		P_UV float high = step(8., cell);
		P_UV float power = exp2(cell - high * 8.), value = mix(v_Low, v_High, high);
	#endif

		// Scale the sample: by 1, if the bit was set, otherwise, by 0.
		P_UV float factor = step(power, mod(value, 2. * power));

	#ifdef USE_NEIGHBORS
		factor *= .5;

		factor += .125 * AddFactor(v_Top, scaled - vec2(0., 1.), scaled.x, step(0., scaled.y - 1.));
		factor += .125 * AddFactor(v_Left, scaled - vec2(1., 0.), scaled.y, step(0., scaled.x - 1.));
		factor += .125 * AddFactor(v_Right, scaled + vec2(1., 0.), scaled.y, step(scaled.x + 1., 3.));
		factor += .125 * AddFactor(v_Bottom, scaled + vec2(0., 1.), scaled.x, step(scaled.y + 1., 3.));
	#endif

		return CoronaColorScale(texture2D(CoronaSampler0, uv) * factor);
	}
]]

local Kernels = {}

-- Common kernel setup
local function NewKernel (suffix, prelude)
	local kernel = { category = "filter", group = "filler", name = "grid4x4_" .. suffix, vertexData = {} }

	kernel.vertex = loader.VertexShader{ prelude = prelude, main = UberVertex }
	kernel.fragment = loader.FragmentShader{ prelude = prelude, main = UberFragment }

	AddDatum(kernel, "bits")

	Kernels[suffix] = kernel.category .. "." .. kernel.group .. "." .. kernel.name

	return kernel
end

-- Basic grid effect --
do
	local kernel = NewKernel("basic", "")

	graphics.defineEffect(kernel)
end

-- Image sheet-based variant --
do
	local kernel = NewKernel("frame", [[
		#define IMAGE_SHEET
	]])

	AddDatum(kernel, "x")
	AddDatum(kernel, "y")

	graphics.defineEffect(kernel)
end

-- Neighbor-based variant --
do
	local kernel = NewKernel("neighbors", [[
		#define USE_NEIGHBORS
	]])

	AddDatum(kernel, "neighbors")

	graphics.defineEffect(kernel)
end

-- Image sheet- and neighbor-based variant --
do
	local kernel = NewKernel("neighbors_frame", [[
		#define IMAGE_SHEET
		#define USE_NEIGHBORS
	]])

	AddDatum(kernel, "neighbors")
	AddDatum(kernel, "x")
	AddDatum(kernel, "y")

	graphics.defineEffect(kernel)
end

return Kernels