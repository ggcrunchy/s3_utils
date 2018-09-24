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

-- Extension imports --
local copy = table.copy

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
local Runtime = Runtime

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

local Shorthand = { "_H", "_V", "UL", "UR", "LL", "LR", "TT", "LT", "RT", "BT", "_4", "_T", "_L", "_R", "_B" }

local Expansions = {
	_H = "Horizontal", _V = "Vertical",
	UL = "UpperLeft", UR = "UpperRight", LL = "LowerLeft", LR = "LowerRight",
	TT = "TopT", LT = "LeftT", RT = "RightT", BT = "BottomT",
	_4 = "FourWays", _T = "TopNub", _L = "LeftNub", _R = "RightNub", _B = "BottomNub"
}

--- DOCME
function M.GetExpansions ()
	local expansions = {}

	for k, v in pairs(Expansions) do
		expansions[k] = v
	end

	return expansions
end

-- --
local TextureRects = {}

--
local function GetRect (name_or_index)
	return assert(TextureRects[NameToIndex[name_or_index] or name_or_index], "Invalid index or name")
end

--- DOCME
function M.GetFrameBounds (index)
	local rect = GetRect(index)

	return rect.u1, rect.v1, rect.u2, rect.v2
end

--- DOCME
function M.GetFrameCenter (index)
	local rect = GetRect(index)

	return (rect.u1 + rect.u2) / 2, (rect.v1 + rect.v2) / 2
end

--- DOCME
function M.GetFrameFromName (name)
	return NameToIndex[name]
end

--- DOCME
function M.GetNames ()
	local names = {}

	for _, short in ipairs(Shorthand) do -- keep order in sync
		names[#names + 1] = Expansions[short]
	end

	return names
end

-- --
local TileShader

--- DOCME
function M.GetShader ()
	return TileShader and TileShader.name
end

-- --
local Sheet

--- DOCME
function M.GetSheet ()
	return Sheet
end

--- DOCME
function M.GetShorthands ()
	return copy(Shorthand)
end

--  Tileset lookup table --
local TilesetList

--- DOCME
function M.GetTypes ()
	local list = {}

	for name in pairs(TilesetList) do
		list[#list + 1] = name
	end

	return list
end

-- --
local VertexDataNames

--- DOCME
function M.GetVertexDataNames ()
	if VertexDataNames then
		return unpack(VertexDataNames, 1, 4)
	else
		return nil, nil, nil, nil
	end
end

local function SetShader (tile, name, index)
	tile.fill.effect = TileShader.name

	local set_vdata = TileShader.set_vdata

	if set_vdata then
		set_vdata(tile, name, index)
	end
end

--- DOCME
function M.NewTile (group, name, x, y, w, h)
	local index = NameToIndex[name]
	local tile = display.newImageRect(group, Sheet, index, w, h)

	tile.x, tile.y = x, y

	if TileShader then
		SetShader(tile, name, index)
	end

	return tile
end

--- DOCME
function M.SetTileShader (tile, name)
	local index = NameToIndex[name]

	if index and tile.fill and TileShader then
		SetShader(tile, name, index)
	end
end

-- --
local TileCore = [[
	#ifndef INNER_RADIUS
		#error Inner radius must be specified
	#endif

	//
	#define OUTER_RADIUS 1. - INNER_RADIUS
	#define MID_RADIUS .5 * (INNER_RADIUS + OUTER_RADIUS)
	#define HALF_RADIUS .5 * (OUTER_RADIUS - INNER_RADIUS)

	//
	#define UL_TEXCOORD vec4(1. - uv.x, 1. - uv.y, 3. * PI_OVER_TWO, -1.)
	#define UR_TEXCOORD vec4(uv.x, 1. - uv.y, PI_OVER_TWO, 1.)
	#define LL_TEXCOORD vec4(uv.y, 1. - uv.x, 0., -1.)
	#define LR_TEXCOORD vec4(uv.yx, 0., 1.)
	#define H_TEXCOORD vec3(uv, 0.)
	#define V_TEXCOORD vec3(uv.yx, PI_OVER_TWO)

	//
	#define LEFT_ANGLE 0.
	#define RIGHT_ANGLE PI
	#define TOP_ANGLE PI_OVER_TWO
	#define BOTTOM_ANGLE -PI_OVER_TWO

	//
	#define H_ANGLES LEFT_ANGLE, RIGHT_ANGLE
	#define V_ANGLES BOTTOM_ANGLE, TOP_ANGLE
	#define UL_ANGLES TOP_ANGLE, LEFT_ANGLE
	#define UR_ANGLES TOP_ANGLE, RIGHT_ANGLE
	#define LL_ANGLES LEFT_ANGLE, BOTTOM_ANGLE
	#define LR_ANGLES RIGHT_ANGLE, BOTTOM_ANGLE

	//
	const P_COLOR vec4 BlankPixel = vec4(vec3(1.), 2.);

	//
	#ifdef COORDS_NEED_ANGLE
		#define CTYPE vec3
		#define COORD(uv, angle) vec3(uv.xy, angle)
	#else
		#define CTYPE vec2
		#define COORD(uv, _) uv.xy
	#endif

	//
	P_UV vec4 AuxAverage (P_UV vec4 sum, P_UV float n)
	{
		return mix(BlankPixel, sum / max(n, 1.), min(n, 1.));
	}

	P_UV vec4 Average (P_UV vec4 a, P_UV vec4 b)
	{
		P_UV vec2 alpha = vec2(a.a, b.a), found = alpha * step(alpha, vec2(1.5));

		return AuxAverage(a * found.x + b * found.y, dot(found, vec2(1.)));
	}

	P_UV vec4 Average (P_UV vec4 a, P_UV vec4 b, P_UV vec4 c)
	{
		P_UV vec3 alpha = vec3(a.a, b.a, c.a), found = alpha * step(alpha, vec3(1.5));

		return AuxAverage(a * found.x + b * found.y + c * found.z, dot(found, vec3(1.)));
	}

	P_UV vec4 Average (P_UV vec4 a, P_UV vec4 b, P_UV vec4 c, P_UV vec4 d)
	{
		P_UV vec4 alpha = vec4(a.a, b.a, c.a, d.a), found = alpha * step(alpha, vec4(1.5));

		return AuxAverage(mat4(a, b, c, d) * found, dot(found, vec4(1.)));
	}

	//
	#ifndef FEATHER_CUTOFF
		#define FEATHER_CUTOFF .9
	#endif

	//
	P_COLOR vec4 GetColor (P_UV float offset, P_UV CTYPE radius_t, P_UV vec2 angle, bool bFeather)
	{
	#ifdef RADIAL_NOISE_INFLUENCE
		P_UV float p = 4. * radius_t.y * (1. - radius_t.y);

		radius_t.x += (2. * IQ(sin(radius_t * (FIXED_OFFSET + offset))) - 1.) * (p * RADIAL_NOISE_INFLUENCE);
	#endif

		P_UV float s = sin(mix(angle.x, angle.y, radius_t.y));
		P_UV vec2 uv = vec2(smoothstep(INNER_RADIUS, OUTER_RADIUS, radius_t.x), s * s);
		P_UV float feather = bFeather ? smoothstep(1., FEATHER_CUTOFF, uv.x) : 1.;

	#ifndef V_OK
		P_UV vec2 quarter = floor(uv * 4.), frac = uv * 4. - quarter;
		P_UV vec2 uv0 = mod(quarter, 2.), mixed = mix(uv0, 1. - uv0, frac);
		P_UV float on_edge = floor(abs(1.5 - quarter.y)), on_left = step(quarter.y, 2.);

		uv.x = mix(uv.x, mixed.x, mix(frac.y, 1. - frac.y, on_left) * on_edge);
	
		offset *= mixed.y;
	#endif
	
		P_UV float outside = step(HALF_RADIUS, abs(radius_t.x - MID_RADIUS));

		radius_t.xy = uv;

		P_COLOR vec3 value = GetColorRGB(radius_t, offset * s * s);

		return mix(vec4(value, feather), BlankPixel, outside);
	}

	//
	P_UV CTYPE CornerCoords (P_UV vec4 uv)
	{
		P_UV float radius = length(uv.xy), angle = atan(uv.y, max(uv.x, 2e-8)), t = angle / PI;

		return COORD(vec2(radius, t), angle * uv.w + uv.z);
	}

	P_UV CTYPE BeamCoords (P_UV vec3 uv)
	{
		return COORD(uv.yx, uv.z);
	}

	P_UV CTYPE NubCoords (P_UV vec3 uv)
	{
		P_UV float radius = uv.y, t = uv.x;
		P_UV float tnub = t - .5, in_x = step(abs(tnub), HALF_RADIUS);
		P_UV float r2 = HALF_RADIUS * HALF_RADIUS - tnub * tnub, nradius = sqrt(r2 * in_x);
		P_UV float rmin = MID_RADIUS - nradius;

		radius = mix(radius, mix(-1., INNER_RADIUS + (radius - rmin) / max(nradius, 1e-3) * HALF_RADIUS, in_x), step(0., tnub));

		return COORD(vec2(radius, t), uv.z);
	}

	//
	P_COLOR vec4 FinalColor (P_COLOR vec4 color)
	{
	#ifdef EMIT_COMPONENT
		color.a = step(color.a, 1.5);

		return color;
	#else
		return color * step(color.a, 1.5);
	#endif
	}

]]

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
local function AuxFragment (fcode, name, vdata)
	Kernel.name = name
	Kernel.vertexData = vdata
	Kernel.fragment = loader.FragmentShader(fcode)

	graphics.defineEffect(Kernel)
end

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
	AuxFragment(fcode, ("tile_%i"):format(NameID), vdata)

	return NamePrefix .. Kernel.name
end

local Corner = [[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		return FinalColor(GetColor(CoronaVertexUserData.x, CornerCoords(%s), vec2(%s), false));
	}
]]

local Beam = [[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		return FinalColor(GetColor(CoronaVertexUserData.x, BeamCoords(%s), vec2(%s), false));
	}
]]

local Nub = [[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		return FinalColor(GetColor(CoronaVertexUserData.x, NubCoords(%s), vec2(%s), false));
	}
]]

local FourWayColor = [[
	P_COLOR vec4 FourWayColor (P_UV vec2 uv)
	{
		P_COLOR vec4 c1 = GetColor(CoronaVertexUserData.x, CornerCoords(UL_TEXCOORD), vec2(UL_ANGLES), true);
		P_COLOR vec4 c2 = GetColor(CoronaVertexUserData.y, CornerCoords(UR_TEXCOORD), vec2(UR_ANGLES), true);
		P_COLOR vec4 c3 = GetColor(CoronaVertexUserData.z, CornerCoords(LL_TEXCOORD), vec2(LL_ANGLES), true);
		P_COLOR vec4 c4 = GetColor(CoronaVertexUserData.w, CornerCoords(LR_TEXCOORD), vec2(LR_ANGLES), true);

		return Average(c1, c2, c3, c4);
	}

]]

local TJunction = FourWayColor ..[[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		P_COLOR vec4 c1 = GetColor(CoronaVertexUserData.x, BeamCoords(%s), vec2(%s), false);

	#ifdef FOUR_WAY_CORRECT
		c1.rgb = FourWayColor(uv).rgb;
	#endif

		P_COLOR vec4 c2 = GetColor(CoronaVertexUserData.y, CornerCoords(%s), vec2(%s), true);
		P_COLOR vec4 c3 = GetColor(CoronaVertexUserData.z, CornerCoords(%s), vec2(%s), true);

		return FinalColor(Average(c1, c2, c3));
	}
]]

local FourWays = FourWayColor .. [[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		return FinalColor(FourWayColor(uv));
	}
]]

-- --
local Makers = {
	UpperLeft = { Corner, "UL_TEXCOORD", "UL_ANGLES" },
	TopT = { TJunction, "H_TEXCOORD", "H_ANGLES", "UL_TEXCOORD", "UL_ANGLES", "UR_TEXCOORD", "UR_ANGLES" },
	UpperRight = { Corner, "UR_TEXCOORD", "UR_ANGLES" },
	TopNub = { Nub, "vec3(1. - uv.y, uv.x, PI_OVER_TWO)", "BOTTOM_ANGLE, 0." },
	LeftNub = { Nub, "vec3(1. - uv.x, uv.y, 0.)", "RIGHT_ANGLE, PI_OVER_TWO" },
	LeftT = { TJunction, "V_TEXCOORD", "V_ANGLES", "UL_TEXCOORD", "UL_ANGLES", "LL_TEXCOORD", "LL_ANGLES" },
	FourWays = { FourWays },
	Vertical = { Beam, "V_TEXCOORD", "V_ANGLES" },
	RightT = { TJunction, "V_TEXCOORD", "V_ANGLES", "UR_TEXCOORD", "UR_ANGLES", "LR_TEXCOORD", "LR_ANGLES" },
	Horizontal = { Beam, "H_TEXCOORD", "H_ANGLES" },
	LowerLeft = { Corner, "LL_TEXCOORD", "LL_ANGLES" },
	BottomT = { TJunction, "H_TEXCOORD", "H_ANGLES", "LL_TEXCOORD", "LL_ANGLES", "LR_TEXCOORD", "LR_ANGLES" },
	LowerRight = { Corner, "LR_TEXCOORD", "LR_ANGLES" },
	BottomNub = { Nub, "vec3(uv.yx, PI_OVER_TWO)", "TOP_ANGLE, 0." },
	RightNub = { Nub, "vec3(uv, 0.)", "LEFT_ANGLE, PI_OVER_TWO" }
}

-- --
local EmitComponent = [[
	#define EMIT_COMPONENT
]]

--
local function LoadEffects (config, prelude)
	local effects = {}

	for k, v in pairs(Makers) do
		local cparams = config[k]
		local fcode = prelude .. v[1]:format(unpack(v, 2))

		if type(cparams) == "table" then
			effects[k] = Fragment(fcode, unpack(cparams))
		else
			effects[k] = Fragment(fcode, cparams)
		end
	end

	return effects
end

-- --
local Image

--
local function RenderTile (x, y, w, h, effect)
	local tile = display.newRect(x, y, w, h)

	tile.fill.effect = effect

	Image:draw(tile)
end

local function GetEffects (ts)
	local category, gname, prelude, datum_prefix = ts.category, ts.group, ts.prelude, ts.datum_prefix

	assert(category == "generator" or category == "filter" or category == "composite", "Invalid category")
	assert(type(gname) == "string", "Invalid group name")
	assert(type(prelude) == "string", "Invalid prelude")
	assert(datum_prefix == nil or type(datum_prefix) == "string", "Invalid prefix")

	prelude = prelude .. TileCore

	local config, effects = ts.config, Groups[gname]

	if not effects then
		--
		local filter, composite = ts.filter, ts.composite

		assert(filter == nil or type(filter) == "string", "Invalid filter")
		assert(composite == nil or type(composite) == "string", "Invalid composite")
		assert(not (filter and composite), "Cannot have both filter and composite")

		local shader = filter or composite

		--
		NameID, DatumPrefix, NamePrefix = 0, datum_prefix or "", category .. "." .. gname .. "."

		Kernel.category, Kernel.group, effects = category, gname, {}

		effects.raw = LoadEffects(config, prelude)

		if shader then
			effects.with_shader = LoadEffects(config, EmitComponent .. prelude)
		end

		--
		if shader then
			Kernel.category = filter and "filter" or "composite"
			Kernel.isTimeDependent = ts.isTimeDependent

			local vertex = ts.vertex

			if vertex then
				Kernel.vertex = loader.VertexShader(vertex)
			end

			AuxFragment(EmitComponent .. shader, "tile_shader", ts.vdata)

			effects.tile_shader, Kernel.isTimeDependent, Kernel.vertex = Kernel.category .. "." .. gname .. ".tile_shader"
		end

		--
		Groups[gname] = effects
	end

	return effects
end

--
function M.UseTileset (name, prefer_raw)
	local ts = assert(TilesetList[name], "Invalid tileset")
	local effects = GetEffects(ts)
	local sname = not prefer_raw and effects.tile_shader

	if not Image or Image.m_name ~= name or Image.m_sname ~= sname then
		local ex, ey = ts.extra_x or 0, ts.extra_y or 0
		local w, h, old_w, old_h = (Cols + ex) * Dim, (Rows + ey) * Dim, -1, -1

		if Image then
			old_w, old_h = Image.width, Image.height

			if w > old_w or h > old_h then
				Image:releaseSelf()

				Image = nil
			end
		end

		Image = Image or graphics.newTexture{ type = "canvas", width = w, height = h }
		Image.m_name, Image.m_sname = name, sname

		local cache, list = Image.cache

		if sname then
			TileShader, list = {
				name = effects.tile_shader, set_vdata = ts.set_vdata
			}, effects.with_shader

			VertexDataNames = {}

			for i = 1, #(ts.vdata or "") do
				VertexDataNames[ts.vdata[i].index + 1] = ts.vdata[i].name
			end
		else
			list, TileShader, VertexDataNames = effects.raw
		end

		--
		w, h = Image.width, Image.height

		local changed = not TextureRects or old_w ~= w or old_h ~= h

		if changed or cache.numChildren == 0 then
			if changed then
				TextureRects = {}
			end

			for i = cache.numChildren, 1, -1 do
				cache:remove(i)
			end

			local frames, x0, y0 = {}, (Dim - w) / 2, (Dim - h) / 2

			for ri, row in ipairs(Names) do
				local y = (ri - 1) * Dim

				for ci, name in ipairs(row) do
					local x = (ci - 1) * Dim

					RenderTile(x0 + x, y0 + y, Dim, Dim, list[name])

					if changed then
						TextureRects[#TextureRects + 1] = { u1 = x / w, v1 = y / h, u2 = (x + Dim - 1) / w, v2 = (y + Dim - 1) / h }

						frames[#frames + 1] = { x = x + 1, y = y + 1, width = Dim, height = Dim }
					end
				end
			end

			if changed then
				Sheet = graphics.newImageSheet(Image.filename, Image.baseDir, {
					frames = frames, sheetContentWidth = Image.width, sheetContentHeight = Image.height
				})
			end

			if TileShader then
				local empty = display.newRect(x0 + 5 * Dim, y0 + 1.5 * Dim, w - 4 * Dim, h - Dim)

				empty:setFillColor(0, 0)

				Image:draw(empty)
			end
		else
			local index = 1

			for _, row in ipairs(Names) do -- can leave empty TileShader rect alone
				for ci, name in ipairs(row) do
					index, cache[index].fill.effect = index + 1, list[name]
				end
			end
		end

		--
		Image:invalidate()

		Runtime:dispatchEvent{ name = "tileset_details_changed" }
	end
end

-- Install the tilesets.
TilesetList = require_ex.DoList("config.TileSets")

--
local function Clear ()
	if Image then
		Image:releaseSelf()
	end

	Image, Sheet, TextureRects, TileShader, VertexDataNames = nil
end

-- Listen to events.
for k, v in pairs{
	-- Leave Level --
	leave_level = Clear,

	-- System --
	system = function(event)
		if event.type == "applicationResume" and Image then
			Image:invalidate("cache")
		end
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M