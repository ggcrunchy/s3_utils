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

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local pairs = pairs
local type = type
local unpack = unpack

-- Modules --
local require_ex = require("tektite_core.require_ex")
local loader = require("corona_shader.loader")

-- Corona globals --
local display = display
local graphics = graphics

-- Exports --
local M = {}

--
local Names = {
	{ "UpperLeft", "TopT", "UpperRight", "TopNub", "LeftNub", "Horizontal", "RightNub" },
	{ "LeftT", "FourWays", "RightT", "Vertical" },
	{ "LowerLeft", "BottomT", "LowerRight", "BottomNub" }
}

--
local NameToIndex, Rows, Cols = {}, #Names, -1

--
local ti = 1

for _, row in ipairs(Names) do
	local w = #row

	if w > Cols then
		Cols = w
	end

	for _, name in ipairs(row) do
		NameToIndex[name], ti = ti, ti + 1
	end
end

-- --
local Image

-- --
local Sheet

--- DOCME
function M.NewTile (group, name, x, y, w, h)
	local tile = display.newImageRect(group, Sheet, NameToIndex[name], w, h)

	tile.x, tile.y = x, y

	return tile
end

-- --
local TileCore = [[
	#ifndef INNER_RADIUS
		#error "Inner radius must be specified"
	#endif

	#define OUTER_RADIUS 1. - INNER_RADIUS
	#define MID_RADIUS .5 * (INNER_RADIUS + OUTER_RADIUS)
	#define HALF_RADIUS .5 * (OUTER_RADIUS - INNER_RADIUS)
	#define UL_TEXCOORD vec2(1. - uv.x, 1. - uv.y)
	#define UR_TEXCOORD vec2(uv.x, 1. - uv.y)
	#define LL_TEXCOORD vec2(uv.y, 1. - uv.x)
	#define LR_TEXCOORD uv.yx
	#define H_TEXCOORD uv
	#define V_TEXCOORD uv.yx
	
	P_COLOR vec4 GetColor (P_UV float offset, P_UV vec2 radius_t)
	{
		P_UV float p = 4. * radius_t.y * (1. - radius_t.y);

	#ifdef RADIAL_NOISE_INFLUENCE
		radius_t.x += (2. * IQ(sin(radius_t * (FIXED_OFFSET + offset))) - 1.) * (p * RADIAL_NOISE_INFLUENCE);
	#endif

		P_UV vec2 uv_rt = vec2(smoothstep(INNER_RADIUS, OUTER_RADIUS, radius_t.x), mix(p, radius_t.y, p * p * p * p));
		P_COLOR vec3 value = GetColorRGB(uv_rt);

		return mix(vec4(vec3(value), 1.), vec4(2.), step(HALF_RADIUS, abs(radius_t.x - MID_RADIUS)));
	}

	P_UV vec2 CornerCoords (P_UV vec2 uv)
	{
		P_UV float radius = length(uv), t = acos(uv.x / radius) / PI_OVER_TWO;

		return vec2(radius, t);
	}

	P_UV vec2 BeamCoords (P_UV vec2 uv)
	{
		return uv.yx;
	}

	P_UV vec2 NubCoords (P_UV vec2 uv)
	{
		P_UV float radius = uv.y, t = uv.x;
		P_UV float tnub = t - .5, in_x = step(abs(tnub), HALF_RADIUS);
		P_UV float r2 = HALF_RADIUS * HALF_RADIUS - tnub * tnub, nradius = sqrt(r2 * in_x);
		P_UV float rmin = MID_RADIUS - nradius;

		radius = mix(radius, mix(-1., INNER_RADIUS + (radius - rmin) / max(nradius, 1e-3) * HALF_RADIUS, in_x), step(0., tnub));

		return vec2(radius, t);
	}

	P_COLOR vec4 FinalColor (P_COLOR vec4 color)
	{
		return color * step(color.r, 1.5);
	}

	// https://math.stackexchange.com/a/601130, after some previous experiments with
	// http://iquilezles.org/www/articles/smin/smin.htm

	P_COLOR vec4 smin (P_COLOR vec4 a, P_COLOR vec4 b, P_COLOR vec4 c, P_COLOR float k)
	{
		P_COLOR vec4 ea = exp(a * k), eb = exp(b * k), ec = exp(c * k);

		return (a * ea + b * eb + c * ec) / (ea + eb + ec);
	}

	P_COLOR vec4 smin (P_COLOR vec4 a, P_COLOR vec4 b, P_COLOR vec4 c, P_COLOR vec4 d, P_COLOR float k)
	{
		P_COLOR vec4 ea = exp(a * k), eb = exp(b * k), ec = exp(c * k), ed = exp(d * k);

		return (a * ea + b * eb + c * ec + d * ed) / (ea + eb + ec + ed);
	}

]]

--  Tileset lookup table --
local TilesetList

-- --
local Dim = 64

-- --
local Groups = {}

-- --
local Kernel = {}

-- --
local NameID

-- --
local DatumPrefix

-- --
local NamePrefix

-- --
local VertexData = {}

--
local function Fragment (fcode, x, y, z, w)
	NameID, VertexData[1], VertexData[2], VertexData[3], VertexData[4] = NameID + 1, x, y, z, w

	--
	local vdata

	for i, coeff in ipairs(VertexData) do
		vdata = vdata or {}

		vdata[#vdata + 1] = { index = i - 1, name = DatumPrefix .. i, default = coeff }
	end

	--
	Kernel.name = ("tile_%i"):format(NameID)
	Kernel.vertexData = vdata
	Kernel.fragment = loader.FragmentShader(fcode)

	graphics.defineEffect(Kernel)

	return NamePrefix .. Kernel.name
end

local Corner = [[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		return FinalColor(GetColor(CoronaVertexUserData.x, CornerCoords(%s)));
	}
]]

local Beam = [[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		return FinalColor(GetColor(CoronaVertexUserData.x, BeamCoords(%s)));
	}
]]

local Nub = [[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		return FinalColor(GetColor(CoronaVertexUserData.x, NubCoords(%s)));
	}
]]

local TJunction = [[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		P_COLOR vec4 c1 = GetColor(CoronaVertexUserData.x, BeamCoords(%s));
		P_COLOR vec4 c2 = GetColor(CoronaVertexUserData.y, CornerCoords(%s));
		P_COLOR vec4 c3 = GetColor(CoronaVertexUserData.z, CornerCoords(%s));

		return FinalColor(smin(c1, c2, c3, -5.));
	}
]]

local FourWays = [[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		P_COLOR vec4 c1 = GetColor(CoronaVertexUserData.x, CornerCoords(UL_TEXCOORD));
		P_COLOR vec4 c2 = GetColor(CoronaVertexUserData.y, CornerCoords(UR_TEXCOORD));
		P_COLOR vec4 c3 = GetColor(CoronaVertexUserData.z, CornerCoords(LL_TEXCOORD));
		P_COLOR vec4 c4 = GetColor(CoronaVertexUserData.w, CornerCoords(LR_TEXCOORD));

		return FinalColor(smin(c1, c2, c3, c4, -5.));
	}
]]

-- --
local Makers = {
	UpperLeft = { Corner, "UL_TEXCOORD" },
	TopT = { TJunction, "H_TEXCOORD", "UL_TEXCOORD", "UR_TEXCOORD" },
	UpperRight = { Corner, "UR_TEXCOORD" },
	TopNub = { Nub, "vec2(1. - uv.y, uv.x)" },
	LeftNub = { Nub, "vec2(1. - uv.x, uv.y)" },
	LeftT = { TJunction, "V_TEXCOORD", "UL_TEXCOORD", "LL_TEXCOORD" },
	FourWays = { FourWays },
	Vertical = { Beam, "V_TEXCOORD" },
	RightT = { TJunction, "V_TEXCOORD", "UR_TEXCOORD", "LR_TEXCOORD" },
	Horizontal = { Beam, "H_TEXCOORD" },
	LowerLeft = { Corner, "LL_TEXCOORD" },
	BottomT = { TJunction, "H_TEXCOORD", "LL_TEXCOORD", "LR_TEXCOORD" },
	LowerRight = { Corner, "LR_TEXCOORD" },
	BottomNub = { Nub, "uv.yx" },
	RightNub = { Nub, "uv" }
}

--
function M.UseTileset (name)
	assert(not Image, "Tileset already loaded")

	local ts = assert(TilesetList[name], "Invalid tileset")
	local category, gname, prelude, datum_prefix = ts.category, ts.group, ts.prelude, ts.datum_prefix

	assert(category == "generator" or category == "filter" or category == "composite", "Invalid category")
	assert(type(gname) == "string", "Invalid group name")
	assert(type(prelude) == "string", "Invalid prelude")
	assert(datum_prefix == nil or type(datum_prefix) == "string", "Invalid prefix")

	prelude = prelude .. TileCore

	--
	local ex, ey = ts.extra_x or 0, ts.extra_y or 0
	local w, h = (Cols + ex) * Dim, (Rows + ey) * Dim

	Image = graphics.newTexture{ type = "canvas", width = w, height = h }

	--
	local config, effects = ts.config, Groups[gname]

	if not effects then
		NameID, DatumPrefix, NamePrefix = 0, datum_prefix or "", category .. "." .. gname .. "."

		Kernel.category, Kernel.group, effects = category, gname, {}

		for k, v in pairs(Makers) do
			local cparams = config[k]
			local fcode = prelude .. v[1]:format(unpack(v, 2))

			if type(cparams) == "table" then
				effects[k] = Fragment(fcode, unpack(cparams))
			else
				effects[k] = Fragment(fcode, cparams)
			end
		end

		Groups[gname] = effects
	end

	--
	local frames, x0, y0 = {}, (Dim - w) / 2, (Dim - h) / 2

	for ri, row in ipairs(Names) do
		local y = (ri - 1) * Dim

		for ci, name in ipairs(row) do
			local x = (ci - 1) * Dim
			local tile = display.newRect(x0 + x, y0 + y, Dim, Dim)

			tile.fill.effect = effects[name]

			Image:draw(tile)

			frames[#frames + 1] = { x = x + 1, y = y + 1, width = Dim, height = Dim }
		end
	end

	-- TODO: populate other spots if logic available

	Image:invalidate()

	--
	Sheet = graphics.newImageSheet(Image.filename, Image.baseDir, {
		frames = frames, sheetContentWidth = Image.width, sheetContentHeight = Image.height
	})
end

-- Install the tilesets.
TilesetList = require_ex.DoList("config.TileSets")

-- Listen to events.
for k, v in pairs{
	-- Leave Level --
	leave_level = function()
		if Image then
			Image:releaseSelf()
		end

		Image, Sheet = nil
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M