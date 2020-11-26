--- Module that builds up geometry via triangles, possibly with curved edges.
--
-- TODO CLEAN THIS UP A BIT
--
--	These might go:
--	
--	
--			  B
--	         / \
--	        K   L
--	       / \ / \
--	      J   U   M
--	     / \ / \ / \
--		I   S   T   N
--	   / \ / \ / \ / \
--	  H   P   Q   R   O
--	 / \ / \ / \ / \ / \
--	A - D - E - F - G - C
--
--	Sides / corners will appear multiple times, so this must be accommodated
--	Will pre-generate points along sides to dovetail with situations where we reuse them
--	To a lesser extent, same is true as we build up this bit, but internal
--	By traversing diagonally, we can add one triangle plus n rects
--	This introduces at most one new point per rect (none on the last)
--	Could have another scratch buffer for previous side, e.g. P-S-U-L
--
--	Example:
--	
--		AHD, HIDP (P new), IJPS (S new), JKSU (U new), KBUL
--		DPE, PSEQ (Q new), SUQT (T new), ULTM
--		EQF, QTFR (R new), TMRN
--		FRG, RNGO
--		GOC

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
local setmetatable = setmetatable
local sqrt = math.sqrt

-- Exports --
local M = {}

--
--
--

local TriangleState = {}

TriangleState.__index = TriangleState

--
--
--

local function GetEdge (opts, name, count)
	local arr = opts and opts[name]

	for i = #(arr or ""), count + 1, -1 do
		arr[i] = nil
	end

	return arr or {}
end

local function FillRange (into, nindices, i1, i2)
	for i = i1, i2 do
		nindices = nindices + 1
		into[i] = nindices
	end

	return nindices
end

local function LeftIndices (left, count, nindices, lli, ti)
	local i1 = 1

	if lli then
		left[1], i1 = lli, 2
	end

	local i2 = count

	if ti then
		i2 = i2 - 1
	end

	nindices = FillRange(left, nindices, i1, i2)

	if ti then
		left[count] = ti
	end

	return nindices
end

local function RightIndices (right, left, count, nindices, lri)
	right[1] = left[count]

	local i2 = count

	if lri then
		i2 = i2 - 1
	end

	nindices = FillRange(right, nindices, 2, i2)

	if lri then
		right[count] = lri
	end

	return nindices
end

local function BottomIndices (bottom, left, right, count, nindices)
	bottom[1] = left[1]
	nindices = FillRange(bottom, nindices, 2, count - 1)
	bottom[count] = right[count]

	return nindices
end

local function GetExistingEdge (indices, first, step, count, index1, index2)
	if indices or first then
		step = step or 1

		local index = first

		if not index then
			index = 1

			if step < 0 then
				index = 1 - (count - 1) * step -- i.e. finish on 1
			end
		end

		local edge, i1, i2 = {}, 1, count - (index2 and 1 or 0)

		if index1 then
			edge[1], i1 = index1, 2
		end

		for i = i1, i2 do
			if indices then
				edge[i] = assert(indices[index], "Hole in source indices")
			else
				edge[i] = index
			end

			index = index + step
		end

		if index2 then
			edge[count] = index2
		end

		return edge, edge[1], edge[count]
	end
end

local function ReconcileIndex (from_edge1, from_edge2, what)
	if from_edge1 and from_edge2 and from_edge1 ~= from_edge2 then
		assert(false, what .. "index from one edge disagrees with corresponding one in another")
	end

	return from_edge1 or from_edge2 -- any non-nil ones now known to agree
end

--- DOCME
function M.Indices (count, opts)
	assert(count >= 2, "Too few points")

	local left, right, bottom, lli, lri, ti

	if opts then
		lli, lri, ti = opts.lower_left_index, opts.lower_right_index, opts.top_index

		local left_lli, left_ti, right_lri, right_ti, bottom_lli, bottom_lri

		left, left_lli, left_ti = GetExistingEdge(opts.left_indices, opts.left_first, opts.left_step, count, lli, ti)
		right, right_ti, right_lri = GetExistingEdge(opts.right_indices, opts.right_first, opts.right_step, count, ti, lri)
		bottom, bottom_lli, bottom_lri = GetExistingEdge(opts.bottom_indices, opts.bottom_first, opts.bottom_step, count, lli, lri)

		lli = lli or ReconcileIndex(left_lli, bottom_lli, "Lower left ")
		lri = lri or ReconcileIndex(right_lri, bottom_lri, "Lower right ")
		ti = ti or ReconcileIndex(left_ti, right_ti, "Top ")
	end

	local nindices = opts and opts.nindices or 0 -- n.b. fallthrough okay

	if not left then
		left = GetEdge(opts, "left", count)
		nindices = LeftIndices(left, count, nindices, lli, ti)
	end

	if not right then
		right = GetEdge(opts, "right", count)
		nindices = RightIndices(right, left, count, nindices, lri)
	end

	if not bottom then
		bottom = GetEdge(opts, "bottom", count)
		nindices = BottomIndices(bottom, left, right, count, nindices)
	end

	return left, right, bottom, nindices
end

--
--
--

local function InterpolateNormals (state, t)
	local nx, ny = state.m_normal_x + t * state.m_normal_dx, state.m_normal_y + t * state.m_normal_dy

	if state.m_must_normalize then -- else assume z = sqrt(1 - nx^2 - ny^2)
		local nz = state.m_normal_z + t * state.m_normal_dz
		local len = sqrt(nx^2 + ny^2 + nz^2)

		nx, ny = nx / len, ny / len
	end

	return nx, ny
end

local function SetNormals (state, nx1, ny1, nx2, ny2, no_normalize)
	local nz1, nz2 = sqrt(1 - nx1^2 - ny1^2), sqrt(1 - nx2^2 - ny2^2)

	state.m_normal_x, state.m_normal_dx = nx1, nx2 - nx1
	state.m_normal_y, state.m_normal_dy = ny1, ny2 - ny1
	state.m_normal_z, state.m_normal_dz = nz1, nz2 - nz1
	state.m_must_normalize = not no_normalize and nx1 * nx2 + ny1 * ny2 >= 0 -- With 'no_normalize', we account for situations like flat triangles; normals in the
																			 -- plane, pointing away from one another, are like this. (TODO: are obtuse angles too
																			 -- broad? should be tighten this up to just dot products near -1, i.e. nearly-opposite
																			 -- directions?) Normalization breaks down in these cases, since we never pick up a z-
																			 -- component, so we use the lerp'd results as a compromise.
end

--- DOCME
function TriangleState:BottomEdge (params)
	local into_knots, into_normals, into_vertices = params.into_knots, params.into_normals, params.into_vertices
	local lli, lri = params.lower_left_index, params.lower_right_index
	local llx, lly, ll_nx, ll_ny, ll_knot, lrx, lry, lr_nx, lr_ny, lr_knot

	if lli then
		local ll_offset = (lli - 1) * 2

		llx, lly, ll_nx, ll_ny, ll_knot = into_vertices[ll_offset + 1], into_vertices[ll_offset + 2], into_normals[ll_offset + 1], into_normals[ll_offset + 2], into_knots[lli]
	else
		llx, lly, ll_nx, ll_ny, ll_knot = params.lower_left_x, params.lower_left_y, params.lower_left_nx, params.lower_left_ny, params.lower_left_knot
	end

	if lri then
		local lr_offset = (lri - 1) * 2

		lrx, lry, lr_nx, lr_ny, lr_knot = into_vertices[lr_offset + 1], into_vertices[lr_offset + 2], into_normals[lr_offset + 1], into_normals[lr_offset + 2], into_knots[lri]
	else
		lrx, lry, lr_nx, lr_ny, lr_knot = params.lower_right_x, params.lower_right_y, params.lower_right_nx, params.lower_right_ny, params.lower_right_knot
	end

	local dx, dy, dknot = lrx - llx, lry - lly, lr_knot - ll_knot
	local koffset, count = params.offset or #into_knots, params.count
	local offset, callback = 2 * koffset, params.callback

	SetNormals(self, ll_nx, ll_ny, lr_nx, lr_ny)

	if callback then
		callback("begin_bottom_edge", into_knots, into_normals, into_vertices)
	end

	for i = 1, count - 1 do
		local t = i / count

		into_knots[koffset + 1] = ll_knot + t * dknot
		into_normals[offset + 1], into_normals[offset + 2] = InterpolateNormals(self, t)
		into_vertices[offset + 1], into_vertices[offset + 2] = llx + t * dx, lly + t * dy

		if callback then
			callback("edge", koffset, offset, i, count)
		end

		koffset, offset = koffset + 1, offset + 2
	end

	if callback then
		callback("end_bottom_edge")
	end
end

--
--
--

--- DOCME
function TriangleState:LeftEdge (params)
	local into_knots, into_normals, into_vertices = params.into_knots, params.into_normals, params.into_vertices -- TODO: allow separate from / to??
	local lli, ti = params.lower_left_index, params.top_index
	local llx, lly, ll_nx, ll_ny, ll_knot, tx, ty, t_nx, t_ny, t_knot

	if lli then
		local ll_offset = (lli - 1) * 2

		llx, lly, ll_nx, ll_ny, ll_knot = into_vertices[ll_offset + 1], into_vertices[ll_offset + 2], into_normals[ll_offset + 1], into_normals[ll_offset + 2], into_knots[lli]
	else
		llx, lly, ll_nx, ll_ny, ll_knot = params.lower_left_x, params.lower_left_y, params.lower_left_nx, params.lower_left_ny, params.lower_left_knot
	end

	if ti then
		local t_offset = (ti - 1) * 2

		tx, ty, t_nx, t_ny, t_knot = into_vertices[t_offset + 1], into_vertices[t_offset + 2], into_normals[t_offset + 1], into_normals[t_offset + 2], into_knots[ti]
	else
		tx, ty, t_nx, t_ny, t_knot = params.top_x, params.top_y, params.top_nx, params.top_ny, params.top_knot
	end

	SetNormals(self, ll_nx, ll_ny, t_nx, t_ny)
	
	local dx, dy, dknot = tx - llx, ty - lly, t_knot - ll_knot
	local koffset, count = params.offset or #into_knots, params.count
	local offset, callback = 2 * koffset, params.callback

	if callback then
		callback("begin_left_edge", into_knots, into_normals, into_vertices)
	end

	for i = lli and 1 or 0, count - (ti and 1 or 0) do
		local t = i / count

		into_normals[offset + 1], into_normals[offset + 2] = InterpolateNormals(self, t)
		into_vertices[offset + 1], into_vertices[offset + 2] = llx + t * dx, lly + t * dy
		into_knots[koffset + 1] = ll_knot + t * dknot

		if callback then
			callback("edge", koffset, offset, i, count)
		end

		koffset, offset = koffset + 1, offset + 2
	end

	if callback then
		callback("end_left_edge")
	end
end

--
--
--

--- DOCME
function TriangleState:Populate (builder, ledge, redge, bedge, knots, normals, vertices, opts)
	local n = #redge

	assert(#ledge == n and n == #bedge)

	builder:SetLowerLeft(ledge[1])

	for i = 2, n do
		builder:SetLowerRight(ledge[i])
		builder:EmitBottomEdge()
	end

	local koffset, no_normalize = (opts and opts.offset) or #knots, opts and opts.no_normalize
	local offset, callback = 2 * koffset, opts and opts.callback

	if callback then
		callback("begin_populate", knots, normals, vertices)
	end

	for i = 1, n - 1 do
		for _ = 2, i do
			builder:Skip()
		end

		local bi, ri = bedge[i + 1], redge[i + 1]
		local boffset, roffset = 2 * (bi - 1), 2 * (ri - 1)

		builder:SetLowerRight(bi)
		builder:EmitTriangle()

		SetNormals(self, normals[boffset + 1], normals[boffset + 2], normals[roffset + 1], normals[roffset + 2], no_normalize)

		local knot1, x1, y1 = knots[bi], vertices[boffset + 1], vertices[boffset + 2]
		local nbins, dx, dy, dknot = n - i, vertices[roffset + 1] - x1, vertices[roffset + 2] - y1, knots[ri] - knot1

        if nbins > 1 then -- triangle always gets one, any remaining are quads
            local t, dt = 0, 1 / (nbins - 1)

            for _ = 2, nbins - 1 do -- quads that introduce a new index
                t = t + dt

				normals[offset + 1], normals[offset + 2] = InterpolateNormals(self, t)
                vertices[offset + 1], vertices[offset + 2] = x1 + t * dx, y1 + t * dy
				knots[koffset + 1] = knot1 + t * dknot

				if callback then
					callback("triangle", koffset, offset)
				end

				koffset, offset = koffset + 1, offset + 2

                builder:EmitQuad()
            end

            builder:SetLowerRight(ri) -- quads that only uses old indices
            builder:EmitQuad()
        end
	end

	if callback then
		callback("end_populate")
	end
end

--
--
--

--- DOCME
function TriangleState:RightEdge (params)
	local from_knots, from_normals, from_vertices = params.from_knots, params.from_normals, params.from_vertices
	local into_knots, into_normals, into_vertices = params.into_knots, params.into_normals, params.into_vertices

	local koffset, ki, step = params.offset or #into_knots, params.midpoint_offset, params.step or 1
	local offset, pi, pstep = 2 * koffset, 2 * ki, 2 * step
	local count, callback = params.count, params.callback

	if callback then
		callback("begin_right_edge", into_knots, into_normals, into_vertices)
	end

	for i = 1, count do
		ki, pi = ki + step, pi + pstep

		into_normals[offset + 1], into_vertices[offset + 1] = from_normals[pi + 1], from_vertices[pi + 1]
		into_normals[offset + 2], into_vertices[offset + 2] = from_normals[pi + 2], from_vertices[pi + 2]
		into_knots[koffset + 1] = from_knots[ki + 1]

		if callback then
			callback("edge", koffset, offset, i, count)
		end

		offset, koffset = offset + 2, koffset + 1
	end

	if callback then
		callback("end_right_edge")
	end
end

--
--
--

--- DOCME
function M.NewState ()
	return setmetatable({}, TriangleState)
end

--
--
--

-- The triangle logic assumes this canonical arrangement:

--	 B
--	| \
--	|  \
--	|   \
--	|    \
--	|     \
--	|	   \
--	|       \
--	|        \
--	|         \_
--	|           \_
--	|             \_
--	|               \
--	|                \
--  A - - - - - - - - C

-- The left edge goes A -> B, the right edge B -> C, and the bottom A -> C.

--
--
--

return M