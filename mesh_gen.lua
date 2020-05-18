--- Various mesh shape generators.

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
local abs = math.abs
local assert = assert
local cos = math.cos
local modf = math.modf
local pairs = pairs
local pi = math.pi
local random = math.random
local sin = math.sin
local sqrt = math.sqrt

-- Modules --
local soup = require("solar2d_utils.soup")

-- Cached module references --
local _NewQuadrantArc_
local _NewQuadrantRing_

-- Exports --
local M = {}

--
--
--

local function ScrubAndCopy (into, from)
	for k in pairs(into) do
		into[k] = nil
	end

	for k, v in pairs(from) do
		into[k] = v
	end
end

local function ScrubAndBind (from, params, map)
	ScrubAndCopy(map, from.index_map or map) -- if absent, "copy" from self once scrubbed
	ScrubAndCopy(params, from)

	params.index_map = map
end

local function StitchQuadrantArc (index, n, ncurve, overlap, params, map, kind, u1, u2, nkeep, nwrap, from)
	local arc1_base = index + ncurve + 1 -- (index - 1) + (ncurve + 1) + 1 - i

	index = index + n - overlap
	params.index, params.kind, params.u1, params.u2 = index, kind, u1, u2

	local arc2_base = index - 1 -- (index - 1) + (n - overlap) + i
	local ninc = overlap - (nwrap or 0)

	for i = 1, ninc do
		map[arc2_base + i] = arc1_base - i
	end

	if nwrap then
		local to = arc2_base + ninc

		from = from and from + nwrap or nwrap + 1

		for i = 1, nwrap do
			map[to + i] = from - i
		end
	end

	_NewQuadrantArc_(params)

	for i = 1, overlap - nkeep do
		map[arc2_base + i] = nil
	end

	return index
end

local CrossParams, CrossMap = {}, {}

--- DOCME
function M.NewCross (params)
	ScrubAndBind(params, CrossParams, CrossMap)

	local umid, u1, u2 = params.u_mid or .5, params.u1, params.u2

	CrossParams.kind = "lower_left"
	CrossParams.width, CrossParams.height = params.width / 2, params.height / 2
	CrossParams.u_corner, CrossParams.v_corner = params.u_corner or .25, params.v_corner or .25
	CrossParams.u1, CrossParams.u2, CrossParams.v = u1, umid, params.v or .5

	local index, uvs, verts, indices = params.index or 1, _NewQuadrantArc_(CrossParams)
	local start = index

	CrossParams.uvs, CrossParams.vertices, CrossParams.indices = uvs, verts, indices

	local ncurve = params.ncurve -- at this point any asserts will have fired
	local half, stride = ncurve / 2, params.stride or ncurve + 1
	local n, overlap = (params.nradius + 1) * stride, half + 1

	index = StitchQuadrantArc(index, n, ncurve, overlap, CrossParams, CrossMap, "lower_right", umid, u2, 1)
	index = StitchQuadrantArc(index, n, ncurve, overlap, CrossParams, CrossMap, "upper_right", u2, umid, 1)

	StitchQuadrantArc(index, n, ncurve, ncurve + 1, CrossParams, CrossMap, "upper_left", umid, u2, ncurve + 1, overlap - 1, start)

	return uvs, verts, indices
end

local function DefBeginRow () end

local DummyMap = M -- has no numerical keys

local function LatticeUVsAndVertices (ncols, nrows, w, h, opts)
	local add, begin_row, index_map, uvs, vertices = soup.AddVertex, DefBeginRow, DummyMap
	local x, y, dw, dh = -w / 2, -h / 2, w / ncols, h / nrows
	local ri, stride, context = 1, ncols + 1

	if opts then
		add, begin_row, index_map = opts.add_vertex or add, opts.begin_row or begin_row, opts.index_map or index_map
		context, uvs, vertices = opts.context, opts.uvs, opts.vertices
		ri, stride = (opts.index or ri) - 1, opts.stride or stride
	end

	uvs, vertices = uvs or {}, vertices or {}

	for row = 1, nrows + 1 do
		local index = ri + 1

		begin_row(row, index)

		for j = 1, ncols + 1 do
			if index_map[index] == nil then -- allow false
				add(uvs, vertices, x + (j - 1) * dw, y, w, h)
			end

			index = index + 1
		end

		y, ri = y + dh, ri + stride
	end

	return uvs, vertices
end

local function AddCell (indices, index, stride)
	soup.AddQuadIndices(indices, index, index + 1, index + stride, index + stride + 1)

	return index + 1
end

local function ForEach (indices, base, stride, n, index_map)
	for offset = 0, n - 1 do
		AddCell(indices, base + offset, stride, index_map)
	end

	return base + n
end

local function BasicLattice (indices, ncols, nrows, index, stride, index_map)
	for _ = 1, nrows do
		index = ForEach(indices, index, stride, ncols, index_map) + 1
	end
end

local function ForEachDo (indices, base, stride, n, index_map, func, arg)
	for offset = 0, n - 1 do
		local index = base + offset

		AddCell(indices, index, stride, index_map)
		func(arg, index)
	end

	return base + n
end

local function AddToInterior (interior, index)
	interior[#interior + 1] = index
end

local function LatticeWithInterior (indices, ncols, nrows, index, stride, index_map)
	local interior = {}

	index = ForEach(indices, index, stride, ncols, index_map) - 1 -- first row

	for _ = 2, nrows - 1 do
		AddCell(indices, index + 1, stride, index_map) -- interior row, but first column

		index = ForEachDo(indices, index + 2, stride, ncols - 2, index_map, AddToInterior, interior) -- interior cells

		AddCell(indices, index, stride, index_map) -- interior row, but last column
	end

	return ForEach(indices, index, stride, ncols, index_map) -- last row
end

--- DOCME
function M.NewLattice (ncols, nrows, w, h, opts)
	local indices, op, index = {}, BasicLattice, 1

	if opts then
		if opts.has_interior then
			op = LatticeWithInterior
		end

		index = opts.index or index
	end

	local uvs, vertices = LatticeUVsAndVertices(ncols, nrows, w, h, opts)

	op(indices, ncols, nrows, index, ncols + 1, opts and opts.index_map)

	return uvs, vertices, indices
end

local ArcN = 100

local CosSin = (function(n)
	local cs, da, cosa, sina = { 1, 0 }, pi / (2 * n), 1, 0
	local cosda, sinda = cos(da), sin(da)

	-- a = cos(A), b = sin(A), c = cos(dA), d = sin(dA)
	-- P1 = ac, P2 = bd, P3 = (a + b)(c + d)
	local c_plus_d = cosda + sinda

	for _ = 1, n - 1 do
		local P1, P2, P3 = cosa * cosda, sina * sinda, (cosa + sina) * c_plus_d

		cosa, sina = P1 - P2, P3 - P2 - P1
		cs[#cs + 1] = cosa
		cs[#cs + 1] = sina
	end

	cs[#cs + 1] = 0
	cs[#cs + 1] = 1

	return cs
end)(ArcN)

local UVar, VVar

local function Displacement (fx, fy)
	local du = UVar and (2 * random() - 1) * UVar or 0
	local dv = VVar and (2 * random() - 1) * VVar or 0

	return fx * du - fy * dv, fy * du + fx * dv
end

local function DisplaceFromPrevious (ex, ey, prevx, prevy)
	if UVar or VVar then
		local fx, fy = ex - prevx, ey - prevy
		local len_sq = fx^2 + fy^2

		if 1 + len_sq ~= 1 then
			local len = sqrt(len_sq)
			local dx, dy = Displacement(fx / len, fy / len)

			return ex + dx, ey + dy
		end
	end

	return ex, ey
end

local Ox, Oy, Px, Py, Qx, Qy
local PrevRow, CurRow = {}, {}
local Index, RI, VI

local function FindIndex (index_map, index)
	local mindex, last = index_map[index]

	if mindex ~= nil then
		print("FOR ", index)
		repeat
			print("M",mindex)
			last, mindex = mindex, index_map[mindex]
		until not mindex -- false or nil
		print("")
	end

	return last
end

local function CheckIndex (index_map, di)
	local mindex = FindIndex(index_map, Index)

	CurRow[RI], RI, Index, VI = mindex or Index, RI + 1, Index + di, VI + 2 * di -- n.b. mindex == false will load Index

	return mindex == nil -- allow false
end

local function Add (uvs, verts, u, v, x, y)
	uvs[VI - 1], uvs[VI] = u, v
	verts[VI - 1], verts[VI] = x, y
end

local function PosOnCurve (pos, vx, vy, wx, wy)
	local offset, t = modf(pos) -- offset in [0, ArcN), frac in [0, 1)
	local csi, s = 2 * offset + 1, 1 - t
	local c1, c2 = CosSin[csi + 0], CosSin[csi + 2]
	local s1, s2 = CosSin[csi + 1], CosSin[csi + 3]
	local ca, sa = s * c1 + t * c2, s * s1 + t * s2

	return Ox + ca * vx + sa * wx, Oy + ca * vy + sa * wy
end

local UA, UB, V1, V2 -- A and B nomenclature as these (potentially) vary with v

local function CircularArc (index, ncurve, uvs, verts, index_map, di) -- in circles, arc length is proportional to angle
	Index, RI, VI = index, 1, 2 * (index - 1)

	if CheckIndex(index_map, di) then -- first point
		Add(uvs, verts, UA, V1, Px, Py)
	end

	local cpos, upos, vpos, dc, du, dv = 0, UA, V1, ArcN / ncurve, (UB - UA) / ncurve, (V2 - V1) / ncurve
	local vx, vy, wx, wy, prevx, prevy = Px - Ox, Py - Oy, Qx - Ox, Qy - Oy, Px, Py

	for _ = 1, ncurve - 1 do -- interior
		cpos, upos, vpos = cpos + dc, upos + du, vpos + dv

		local ex, ey = PosOnCurve(cpos, vx, vy, wx, wy)

		if CheckIndex(index_map, di) then
			Add(uvs, verts, upos, vpos, DisplaceFromPrevious(ex, ey, prevx, prevy))
		end

		prevx, prevy = ex, ey
	end

	if CheckIndex(index_map, di) then -- last point
		Add(uvs, verts, UB, V2, Qx, Qy)
	end
end

local Arc = {}

local function EllipticalArc (index, ncurve, uvs, verts, index_map, di) -- in ellipses, arc length-to-angle is rather complex
	--
end

local function GetMeshStructure (params)
	return params.index_map or DummyMap, params.indices or {}, params.uvs or {}, params.vertices or {}
end

local NubMap, NubParams = {}, {}

local function AuxResolveNubCoreDeltas (inner, outer, name, nradius)
	if inner then
		return inner / outer
	else
		local frac = 1 / (nradius + 1)

		NubParams[name] = outer * frac

		return frac
	end
end

local function ResolveNubCoreDeltas (params, kind)
	local nradius, xinner, xouter, yinner, youter = params.nradius -- inner are optional, outer required

	if params.inner_radius then
		xinner = params.inner_radius
		yinner = xinner
	else
		xinner = params.inner_x_radius
		yinner = params.inner_y_radius
	end

	if params.outer_radius then
		xouter = params.outer_radius
		youter = xouter
	else
		xouter = params.outer_x_radius
		youter = params.outer_y_radius
	end

	local xfrac = AuxResolveNubCoreDeltas(xinner, xouter, "inner_x_radius", nradius)
	local yfrac = AuxResolveNubCoreDeltas(yinner, youter, "inner_y_radius", nradius)

	if kind == "upper_left" or kind == "lower_right" then
		return xfrac, yfrac
	else
		return yfrac, xfrac
	end
end

local function NubRing (params, k1, k2, fx, fy, v2)
	v2 = params.v2 or v2

	local index, ncurve, nradius = params.index or 1, params.ncurve, params.nradius
	local u1, u2, v1 = params.u1 or 0, params.u2 or 1, params.v1 or 1 - v2
	local umid, stride = (u1 + u2) / 2, ncurve + 1
	local final = index + (nradius + 1) * stride

	NubParams.index, NubParams.ncurve, NubParams.stride = index, ncurve / 2, stride

	assert(ncurve > 0 and ncurve % 2 == 0, "Curve quantization must be even integer")

	local ufrac, vfrac = ResolveNubCoreDeltas(params, k1)
	local du, vmid = ufrac * abs(u1 - umid), (1 - vfrac) * v2 + vfrac * v1

	NubParams.u1a, NubParams.u1b, NubParams.u2a, NubParams.u2b = u1, umid, umid - du, umid
	NubParams.v1, NubParams.v2a, NubParams.v2b, NubParams.kind = v2, v1, vmid, k1

	local uvs, verts, indices = _NewQuadrantRing_(NubParams)

	index = index + NubParams.ncurve
	NubParams.index, NubParams.indices, NubParams.uvs, NubParams.vertices = index, indices, uvs, verts

	for _ = 1, nradius do
		local vi, dx, dy = 2 * index - 1, Displacement(fx, fy)

		verts[vi], verts[vi + 1], vi = verts[vi] + dx, verts[vi + 1] + dy, vi + 2
		NubMap[index], index = false, index + stride -- false = shadow this index as itself
	end

	final = NubMap[final] or final

	for i = 1, NubParams.ncurve do
		soup.AddTriangleIndices(indices, CurRow[i], CurRow[i + 1], final)
	end

	NubParams.u1a, NubParams.u1b, NubParams.u2a, NubParams.u2b = umid, u2, umid, umid + du
	NubParams.v1a, NubParams.v1b, NubParams.v2, NubParams.kind = v1, vmid, v2, k2
	NubParams.v2a, NubParams.v2b = nil

	_NewQuadrantRing_(NubParams)

	for i = 1, NubParams.ncurve do
		soup.AddTriangleIndices(indices, CurRow[i], CurRow[i + 1], final)
	end

	if CheckIndex(NubMap, 1) then
		Add(uvs, verts, umid, v2, NubParams.x or 0, NubParams.y or 0)
	end

	return uvs, verts, indices
end

--- DOCME
function M.NewNub (params)
	ScrubAndBind(params, NubParams, NubMap)

	local kind = params.kind

	if kind == "top" then
		return NubRing(params, "upper_left", "upper_right", 1, 0, 0)
	elseif kind == "left" then
		return NubRing(params, "lower_left", "upper_left", 0, -1, 0)
	elseif kind == "right" then
		return NubRing(params, "upper_right", "lower_right", 0, 1, 1)
	else
		return NubRing(params, "lower_right", "lower_left", -1, 0, 1)
	end
end

local QuadArcMap, QuadArcParams = {}, {}
local CornerU, CornerV

local function CornerSegmentPair (index, ncurve, uvs, verts, index_map, dir, params)
	Index, RI, VI = index, 1, 2 * (index - 1)
	ncurve, params.nradius = ncurve / 2, params.nradius - 1

	local dx1, dy1, du1, dv1 = (Qx - Ox) / ncurve, (Qy - Oy) / ncurve, (CornerU - UA) / ncurve, (CornerV - V1) / ncurve

	if CheckIndex(index_map, dir) then
		Add(uvs, verts, UA, V1, Px, Py)
	end

	local x, y, u, v = Px, Py, UA, V1

	for _ = 1, ncurve do
		x, y, u, v = x + dx1, y + dy1, u + du1, v + dv1

		if CheckIndex(index_map, dir) then
			Add(uvs, verts, u, v, x, y)
			-- TODO: displacement
		end
	end

	local dx2, dy2, du2, dv2 = (Ox - Px) / ncurve, (Oy - Py) / ncurve, (UB - CornerU) / ncurve, (V2 - CornerV) / ncurve

	for _ = 1, ncurve - 1 do
		x, y, u, v = x + dx2, y + dy2, u + du2, v + dv2

		if CheckIndex(index_map, dir) then
			Add(uvs, verts, u, v, x, y)
			-- TODO: displacement
		end
	end

	if CheckIndex(index_map, dir) then
		Add(uvs, verts, UB, V2, Qx, Qy)
		-- TODO: displacement
	end
end

--- DOCME
function M.NewQuadrantArc (params)
	ScrubAndBind(params, QuadArcParams, QuadArcMap)

	QuadArcParams.before = CornerSegmentPair

	local ncurve, nradius = params.ncurve, params.nradius

	assert(ncurve > 0 and ncurve % 2 == 0, "Curve quantization must be even integer")
	assert(nradius >= 1, "Radial quantization must be non-negative integer")

	local kind, w, h = params.kind, params.width, params.height
	local xr, yr = params.x_radius or params.radius, params.y_radius or params.radius

	assert(w > xr, "Width must exceed radius")
	assert(h > yr, "Height must exceed radius")

	QuadArcParams.inner_x_radius, QuadArcParams.outer_x_radius = xr, w
	QuadArcParams.inner_y_radius, QuadArcParams.outer_y_radius = yr, h

	-- TODO: we could allow configuring the u- and v-extents themselves... maybe if a use case comes up

	local x, y, v = params.x or 0, params.y or 0

	QuadArcParams.u1a, QuadArcParams.u2a = params.u1 or 1, 0
	QuadArcParams.u1b, QuadArcParams.u2b = params.u2 or 0, 1

	if kind == "upper_left" or kind == "upper_right" then
		QuadArcParams.y, v = y - h, params.v or 0
		QuadArcParams.v1b, QuadArcParams.v2b = 1, 1

		if kind == "upper_left" then
			QuadArcParams.x, QuadArcParams.kind = x - w, "lower_right"
			QuadArcParams.v1a, QuadArcParams.v2a = 1, v
		else
			QuadArcParams.x, QuadArcParams.kind = x + w, "lower_left"
			QuadArcParams.v1a, QuadArcParams.v2a = v, 1
		end
	else
		QuadArcParams.y, v = y + h, params.v or 1
		QuadArcParams.v1b, QuadArcParams.v2b = 0, 0

		if kind == "lower_right" then
			QuadArcParams.x, QuadArcParams.kind = x + w, "upper_left"
			QuadArcParams.v1a, QuadArcParams.v2a = 0, v
		else
			QuadArcParams.x, QuadArcParams.kind = x - w, "upper_right"
			QuadArcParams.v1a, QuadArcParams.v2a = v, 0
		end
	end

	CornerU, CornerV = params.u_corner or .5, params.v_corner or v

	return _NewQuadrantRing_(QuadArcParams)
end

local function GetRingParams (params)
	local xinner, xouter, yinner, youter

	if params.inner_radius then
		xinner = params.inner_radius
		yinner = xinner
	else
		xinner = params.inner_x_radius
		yinner = params.inner_y_radius
	end

	if params.outer_radius then
		xouter = params.outer_radius
		youter = xouter
	else
		xouter = params.outer_x_radius
		youter = params.outer_y_radius
	end

	assert(xouter > xinner)
	assert(youter > yinner)

	local afunc = (xinner == yinner and xouter == youter) and CircularArc or EllipticalArc

	return afunc, xinner, xouter, yinner, youter
end

local function AdvanceArc (dpx, dpy, dqx, dqy, dua, dub, dv1, dv2)
	Px, Py, Qx, Qy, PrevRow, CurRow = Px + dpx, Py + dpy, Qx + dqx, Qy + dqy, CurRow, PrevRow
	UA, UB, V1, V2 = UA + dua, UB + dub, V1 + dv1, V2 + dv2
end

local function GetUDomain (params)
	local u1a, u2a = params.u1a or params.u1 or 0, params.u2a or params.u2 or 1 -- n.b. assumed to be symmetric at edges
	local u1b, u2b = params.u1b or params.u1 or 0, params.u2b or params.u2 or 1

	return u1a, u2a, u1b, u2b
end

local function JoinRows (indices, ncurve)
	for i = 1, ncurve do
		soup.AddQuadIndices(indices, PrevRow[i], PrevRow[i + 1], CurRow[i], CurRow[i + 1])
	end
end

--- DOCME
function M.NewQuadrantRing (params)
	local kind, afunc, xinner, xouter, yinner, youter = params.kind, GetRingParams(params)
	local v1b, v2b, u1a, u2a, u1b, u2b = params.v1b, params.v2b, GetUDomain(params)

	UA, UB, UVar, VVar = u1a, u1b, params.uvar, params.vvar

	if kind == "upper_left" or kind == "lower_right" then
		V1, V2 = params.v1a or params.v1 or 0, params.v2a or params.v2 or 1
	else
		V1, V2 = params.v1a or params.v1 or 1, params.v2a or params.v2 or 0
	end

	local ncurve, nradius = params.ncurve or 1, params.nradius or 1
	local xthickness, ythickness, dpx, dpy, dqx, dqy = xouter - xinner, youter - yinner

	assert(ncurve >= 1, "Curve quantization must be positive integer")
	assert(nradius >= 0, "Radial quantization must be non-negative integer")

	Ox, Oy = params.x or 0, params.y or 0

	if kind == "upper_left" then
		Px, Py, dpx, dpy = Ox - xouter, Oy, xthickness / nradius, 0
		Qx, Qy, dqx, dqy = Ox, Oy - youter, 0, ythickness / nradius
	elseif kind == "upper_right" then
		Px, Py, dpx, dpy = Ox, Oy - youter, 0, ythickness / nradius
		Qx, Qy, dqx, dqy = Ox + xouter, Oy, -xthickness / nradius, 0
	elseif kind == "lower_right" then
		Px, Py, dpx, dpy = Ox + xouter, Oy, -xthickness / nradius, 0
		Qx, Qy, dqx, dqy = Ox, Oy + youter, 0, -ythickness / nradius
	else
		Px, Py, dpx, dpy = Ox, Oy + youter, 0, -ythickness / nradius
		Qx, Qy, dqx, dqy = Ox - xouter, Oy, xthickness / nradius, 0
	end

	local index, dir, stride = params.index or 1, params.dir or 1, params.stride or ncurve + 1
	local before, index_map, indices, uvs, verts = params.before, GetMeshStructure(params)
	local dua, dub = (u2a - u1a) / nradius, (u2b - u1b) / nradius -- ignored if nradius = 0
	local dv1, dv2 = v1b and (v1b - V1) / nradius or 0, v2b and (v2b - V2) / nradius or 0 -- ditto

	if before then
		before(index, ncurve, uvs, verts, index_map, dir, params)

		AdvanceArc(dpx, dpy, dqx, dqy, dua, dub, dv1, dv2)

		index = index + stride
	end

	afunc(index, ncurve, uvs, verts, index_map, dir)

	if before then
		JoinRows(indices, ncurve)
	end

	for _ = 1, params.nradius do -- if before() was called, this might now be different
		AdvanceArc(dpx, dpy, dqx, dqy, dua, dub, dv1, dv2)

		index = index + stride

		afunc(index, ncurve, uvs, verts, index_map, dir)

		JoinRows(indices, ncurve)
	end

	return uvs, verts, indices
end

local JunctionMap, JunctionParams = {}, {}

--- DOCME
function M.NewTJunction (params)
	ScrubAndBind(params, JunctionParams, JunctionMap)

	local kind, umid, u1, u2, k1, k2 = params.kind, params.u_mid or .5, params.u1, params.u2

	if kind == "top" then
		k1, k2 = "lower_left", "lower_right"
	elseif kind == "left" then
		k1, k2 = "upper_left", "lower_left"
	elseif kind == "right" then
		k1, k2 = "lower_right", "upper_right"
	else
		k1, k2 = "upper_right", "upper_left"
	end

	if kind == "left" or kind == "right" then
		JunctionParams.height = params.height / 2
		JunctionParams.v = params.v or .5
	else
		JunctionParams.width = params.width / 2
	end

	JunctionParams.kind = k1
	JunctionParams.u1, JunctionParams.u2 = u1, umid

	local index, uvs, verts, indices = params.index or 1, _NewQuadrantArc_(JunctionParams)
	local ncurve = params.ncurve -- at this point any asserts will have fired
	local half, stride = ncurve / 2, params.stride or ncurve + 1
	local n, overlap = (params.nradius + 1) * stride, half + 1
	local arc1_base = index + ncurve + 1 -- (index - 1) + (ncurve + 1) + 1 - i

	index = index + n - overlap
	JunctionParams.uvs, JunctionParams.vertices, JunctionParams.indices = uvs, verts, indices
	JunctionParams.index, JunctionParams.kind = index, k2
	JunctionParams.u1, JunctionParams.u2 = umid, u2

	local arc2_base = index - 1 -- (index - 1) + (n - overlap) + i

	for i = 1, overlap do
		JunctionMap[arc2_base + i] = arc1_base - i
	end

	_NewQuadrantArc_(JunctionParams)

	-- TODO: allow rectangle annex along junction edge (to fine-tune the uvs, basically)

	return uvs, verts, indices
end

_NewQuadrantArc_ = M.NewQuadrantArc
_NewQuadrantRing_ = M.NewQuadrantRing

return M