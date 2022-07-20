--- Tile texture mesh generator.

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
local ceil = math.ceil
local type = type

-- Modules --
local cap = require("s3_utils.tile_texture.cap")
local indexed = require("solar2d_utils.indexed")
local swept_arc = require("s3_utils.tile_texture.swept_arc")
local triangle = require("s3_utils.tile_texture.triangle")

-- Exports --
local M = {}

--
--
--

-- Goal:

-- ▓▓▓▓▓▓▓▓▓:▓▓▓▓▓▓▓▓▓▓▓:▓▓▓▓▓▓▓▓▓:▓▓▓▓▓▓▓
-- ▓▓▓▓     0           1     ▓▓▓▓:▓▓   ▓▓
-- ▓▓▓      :           :      ▓▓▓:▓     ▓
-- ▓▓  A    0     B     1    C  ▓▓:▓  D  ▓
-- ▓      ▓▓:▓▓       ▓▓:▓▓      ▓:▓     ▓
-- ▓     ▓▓▓:▓▓▓     ▓▓▓:▓▓▓     ▓:▓     ▓
-- ·1···1···+···1···0···+···0···0·+·0···0·
-- ▓     ▓▓▓:▓▓▓     ▓▓▓:▓▓▓     ▓:▓     ▓
-- ▓      ▓▓:▓▓       ▓▓:▓▓      ▓:▓     ▓
-- ▓        0           1        ▓:▓     ▓
-- ▓   E    :     F     :    G   ▓:▓  H  ▓
-- ▓        1           0        ▓:▓     ▓
-- ▓      ▓▓:▓▓       ▓▓:▓▓      ▓:▓     ▓
-- ▓     ▓▓▓:▓▓▓     ▓▓▓:▓▓▓     ▓:▓     ▓
-- ·0···0···+···0···1···+···1···1·+·1···1·
-- ▓     ▓▓▓:▓▓▓     ▓▓▓:▓▓▓     ▓:▓     ▓
-- ▓      ▓▓:▓▓       ▓▓:▓▓      ▓:▓     ▓
-- ▓▓  I    1     J     0    K  ▓▓:▓  L  ▓
-- ▓▓▓      :           :      ▓▓▓:▓     ▓
-- ▓▓▓▓     1           0     ▓▓▓▓:▓▓   ▓▓
-- ▓▓▓▓▓▓▓▓▓:▓▓▓▓▓▓▓▓▓▓▓:▓▓▓▓▓▓▓▓▓:▓▓▓▓▓▓▓
-- ·········+···········+·········+·······
-- ▓▓▓▓▓▓▓▓▓:▓▓▓▓▓▓▓▓▓▓▓:▓▓▓▓▓▓▓▓▓:▓▓▓▓▓▓▓
-- ▓▓       0           1       ▓▓:▓▓▓▓▓▓▓
-- ▓   M    :     N     :    O   ▓:▓▓▓▓▓▓▓
-- ▓▓       0           1       ▓▓:▓▓▓▓▓▓▓
-- ▓▓▓▓▓▓▓▓▓:▓▓▓▓▓▓▓▓▓▓▓:▓▓▓▓▓▓▓▓▓:▓▓▓▓▓▓▓

-- This is the layout of the mesh, as it would be rendered into a texture. (It
-- might still be worth preserving should we dispense with that indirection, say
-- if meshes could be shared.) The "·" and ":" symbols indicate horizontal and
-- vertical seams, respectively, with "+" where these meet. Most empty spots are
-- denoted by "▓", although seams cover a few.

-- This is a 4x4 configuration, as divvied up by the aforementioned seams, with
-- one spot unused. The numbers along the seams are the u-values at each endpoint
-- of the edge found there: these are a bit arbitrary but chosen for some variety,
-- with the lion's share of continuity meant to be handled on the shader side.

-- Tiles "H" and "N" are rectangular and axis-aligned. Tiles "D", "L", "M", and "O"
-- that abut them are "caps", i.e. a rectangle topped by a half-disk.

-- Tiles "A", "C", "I", and "K" are curves, axis-aligned at the adjacent seams.

-- Tiles "B", "E", "G", and "J" are T-shaped. (TODO: two half-curve + quarter-diamond
-- parts, with a half-rectangle along one side; contra sed, no half-rectangle in my
-- notes, and in reality it would just run afoul of the same problems)

-- Tile "F" is a cross. (TODO: ditto)

-- Many edges and corners are shared.

-- Normals are computed assuming the objects are cylindrical or spherical, with
-- boundaries coincident with the xy-plane, z pointing up. (TODO: gaps)

--
--
--

--- DOCME
function M.Build (params)
	assert(type(params) == "table", "Expected params table")

	local quad_count_along_axis = assert(params.quad_count_along_axis, "Expected quad count")
	local layer_count = assert(params.layer_count, "Expected layer count")
	local slice_count = assert(params.slice_count, "Expected slice count")

	assert(quad_count_along_axis % 2 == 0, "Expected even quad count")
	assert(layer_count % 2 == 0, "Expected even layer count")

	--
	--
	--

	local cap_builder = indexed.NewLatticeBuilder(slice_count)
	local arc_builder = indexed.NewLatticeBuilder(quad_count_along_axis)
	local tri_builder = indexed.NewLatticeBuilder(quad_count_along_axis)

	local knots, normals, verts = {}, {}, {}

	local arc_state = swept_arc.NewState()

	arc_state:SetLayerCount(layer_count)

	--
	--
	--
	
	local cell_width, cell_height = params.cell_width, params.cell_height
	local used_width, used_height = ceil(params.diameter_fraction * cell_width), ceil(params.diameter_fraction * cell_height)
	local xoff, yoff = ceil((cell_width - used_width) / 2), ceil((cell_height - used_height) / 2)

	local function CellCorners (col, row)
		local lrx, lry = col * cell_width, row * cell_height

		return lrx - cell_width - 1, lry - cell_height - 1, lrx, lry
	end

	--
	--
	--

	local full_arc_params = {
		builder = arc_builder,
		into_knots = knots, into_normals = normals, into_vertices = verts,
		normals_group = params.normals_group, callback = params.arc_callback
	}

	local xstep, ystep = used_width / layer_count, used_height / layer_count
	local ax, ay, cx, cy -- arcs were originally implemented as quadratic Bézier curves, with endpoints A and C
	local ulx, uly, lrx, lry

	local points_along_axis, points_along_cap = quad_count_along_axis + 1, layer_count + 1
	local points_per_cylinder = points_along_axis * points_along_cap

	local npoints = 0

	--
	--
	--

	arc_state:SetOrientation("clockwise")
	arc_state:SetTangentScales(params.horizontal_tangent_scale, params.vertical_tangent_scale)

	--
	--
	--

	local function Corner (step1, step2)
		arc_state:SetKnots1(1, 1)
		arc_state:SetVertexAndStep1(ax, ay, step1)

		arc_state:SetKnots2(0, 0)
		arc_state:SetVertexAndStep2(cx, cy, step2)

		arc_state(full_arc_params)

		local p1, p2 = npoints + 1, npoints + points_along_axis

		npoints = npoints + points_per_cylinder

		return p1, p2, npoints, npoints - quad_count_along_axis
	end

	--
	--
	--

	-- -----------------
	-- | A |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------

	ulx, uly, lrx, lry = CellCorners(1, 1)
	ax, ay = lrx - xoff, lry
	cx, cy = lrx, lry - yoff

	local a_down, a_right, a_last, a_upper = Corner(xstep, ystep)

	--
	--
	--

	-- -----------------
	-- |   |   | C |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------

	ulx, uly, lrx, lry = CellCorners(3, 1)
	ax, ay = ulx, lry - yoff
	cx, cy = ulx + xoff, lry

	local c_left, c_down, c_last, c_upper = Corner(ystep, xstep)

	--
	--
	--

	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- | I |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------

	ulx, uly, lrx, lry = CellCorners(1, 3)
	ax, ay = lrx, uly + yoff
	cx, cy = lrx - xoff, uly

	local i_right, i_up, i_last, i_upper = Corner(ystep, xstep)

	--
	--
	--

	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   | K |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------

	ulx, uly, lrx, lry = CellCorners(3, 3)
	ax, ay = ulx + xoff, uly
	cx, cy = ulx, uly + yoff

	local k_up, k_left, k_last, k_upper = Corner(xstep, ystep)

	--
	--
	--

	local points_along_tjunction_cap = 2 * points_along_cap - 1 -- two neighboring caps sharing a point

	local function LeftHandCap (into, npoints)
		local index, step = npoints, points_along_axis - 1

		for i = 1, points_along_cap do
			index = index + step -- here we want the end of the arc...
			into[i] = index
		end

		return index
	end

	local function RightHandCap (into, npoints)
		local index, step = npoints, points_along_axis - 1

		for i = points_along_tjunction_cap, points_along_cap, -1 do
			into[i] = index + 1 -- ...whereas here we want the beginning
			index = index + step
		end

		return index - 1 -- omit shared point
	end

	local unshared_points_along_axis = points_along_axis - 2

	local to_first_on_shared_axis = -unshared_points_along_axis + 1

	--
	--
	--

	local function Junction (step, lhs_index, rhs_index)
		local into = {}

		-- Left-hand arc:
		arc_state:SetArcNormalHalfRange2(true)

		arc_state:SetIndexAndStep1(lhs_index, points_along_axis)
		arc_state:SetSources1(knots, verts)

		arc_state:SetKnots2(1, .5)
		arc_state:SetVertexAndStep2(cx, cy, step)

		arc_state(full_arc_params)

		npoints = LeftHandCap(into, npoints)

		local mid_index = npoints

		-- Right-hand arc: do all but the last layer first, i.e. the parts where cap #1 is unique....
		arc_state:SetArcNormalHalfRange2(false)
		arc_state:SetArcNormalHalfRange1(true)

		arc_state:SetKnots1(0, .5)
		arc_state:SetVertexAndStep1(ax, ay, step)

		arc_state:SetIndexAndStep2(rhs_index, points_along_axis)
		arc_state:SetSources2(knots, verts)

		full_arc_params.omit, full_arc_params.leave_updater2 = "last", true

		arc_state(full_arc_params)

		-- ...do the last layer, whose first point is the last one in the left-hand arc.
		full_arc_params.omit, full_arc_params.leave_updater2 = "rest"

		arc_state:SetIndexAndStep1(npoints, 0)
		arc_state:SetSources1(knots, verts)

		arc_state(full_arc_params)

		arc_state:SetArcNormalHalfRange1(false)

		full_arc_params.omit = nil

		npoints = RightHandCap(into, npoints)

		return into, mid_index, npoints + to_first_on_shared_axis
	end

	--
	--
	--

	-- -----------------
	-- |   | B |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------

	ulx, uly, lrx, lry = CellCorners(2, 1)
	cx, cy = ulx + xoff, lry
	ax, ay = lrx - xoff, lry

	local bx, by = (ulx + lrx) / 2, uly + yoff
	local b_down, b_mid, b_upper = Junction(xstep / 2, a_right, c_left)

	--
	--
	--

	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- | E |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------

	ulx, uly, lrx, lry = CellCorners(1, 2)
	cx, cy = lrx, lry - yoff
	ax, ay = lrx, uly + yoff

	local ex, ey = ulx + xoff, (uly + lry) / 2
	local e_right, e_mid, e_upper = Junction(ystep / 2, i_up, a_down)

	--
	--
	--

	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   | G |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------

	ulx, uly, lrx, lry = CellCorners(3, 2)
	cx, cy = ulx, uly + yoff
	ax, ay = ulx, lry - yoff

	local gx, gy = lrx - xoff, ey
	local g_left, g_mid, g_upper = Junction(ystep / 2, c_down, k_up)

	--
	--
	--

	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   | J |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------

	ulx, uly, lrx, lry = CellCorners(2, 3)
	cx, cy = lrx - xoff, uly
	ax, ay = ulx + xoff, uly 

	local jx, jy = bx, lry - yoff
	local j_up, j_mid, j_upper = Junction(xstep / 2, k_left, i_right)

	--
	--
	--

	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   | F |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------

	ulx, uly, lrx, lry = CellCorners(2, 2)
	
	local cylinder_points_with_two_shared_caps = points_per_cylinder - 2 * points_along_cap

	arc_state:SetArcNormalHalfRange1(true)
	arc_state:SetArcNormalHalfRange2(true)

	local function CrossCorner (from, to)
		arc_state:SetSources1(knots, verts, from)

		arc_state:SetIndexAndStep2(points_along_tjunction_cap, -1)
		arc_state:SetSources2(knots, verts, to)

		arc_state(full_arc_params)

		npoints = npoints + cylinder_points_with_two_shared_caps

		return npoints
	end

	local be_last = CrossCorner(b_down, e_right)
	local gb_last = CrossCorner(g_left, b_down)
	local jg_last = CrossCorner(j_up, g_left)
	local ej_last = CrossCorner(e_right, j_up)

	--
	--
	--

	arc_state:SetOrientation("counter_clockwise")
	arc_state:SetArcNormalHalfRange1(false)
	arc_state:SetArcNormalHalfRange2(false)

	local function Line (x1, y1, x2, y2, xstep, ystep)
		local p1, p2 = npoints + 1, npoints + points_along_axis

		arc_state:SetKnots1(0, 0)
		arc_state:SetLineVertexAndStep1(x1, y1, xstep, ystep)

		arc_state:SetKnots2(1, 1)
		arc_state:SetLineVertexAndStep2(x2, y2, xstep, ystep)

		arc_state(full_arc_params)

		npoints = npoints + points_per_cylinder

		return p1, p2
	end

	--
	--
	--

	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   | H |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------

	ulx, uly, lrx, lry = CellCorners(4, 2)

	local x = lrx - xoff
	local h_up, h_down = Line(x, uly, x, lry, -xstep, 0)

	--
	--
	--

	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   | N |   |   |
	-- -----------------

	ulx, uly, lrx, lry = CellCorners(2, 4)

	local y = uly + yoff
	local n_left, n_right = Line(ulx, y, lrx, y, 0, ystep)

	--
	--
	--

	local points_per_cap_with_shared_base = (slice_count + 1) * (layer_count / 2) + 1 - points_along_cap

	do
		local max_index = arc_builder:GetMaxIndex()
		local indices, offset = arc_builder:GetResult()

		cap_builder:SetIndices(indices)
		cap_builder:SetMaxIndex(max_index)
		cap_builder:SetOffset(offset)
	end

	local cap_params = {
		builder = cap_builder,
		into_knots = knots, into_normals = normals, into_vertices = verts,
		layer_count = layer_count / 2,
		normals_group = params.normals_group, callback = params.cap_callback
	}

	local cap_state = cap.NewState()

	local function Cap (from, ux, uy, offset, orientation)
		cap_state:SetOrientation(orientation)
		cap_state:SetIndexAndStep(from, points_along_axis)
		cap_state:SetSources(knots, verts)
		cap_state:SetDisplacementToTip(ux, uy, offset, offset * params.grow_fraction)

		cap_state(cap_params)

		npoints = npoints + points_per_cap_with_shared_base
	end

	--
	--
	--

	-- -----------------
	-- |   |   |   | D |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------

	-- ulx, uly, lrx, lry = CellCorners(4, 1)

	Cap(h_up, 0, -1, yoff, "clockwise")

	--
	--
	--

	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   | L |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------

	-- ulx, uly, lrx, lry = CellCorners(4, 3)

	Cap(h_down, 0, 1, yoff, "counter_clockwise")

	--
	--
	--

	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- | M |   |   |   |
	-- -----------------

	-- ulx, uly, lrx, lry = CellCorners(1, 4)

	Cap(n_left, -1, 0, xoff, "clockwise")

	--
	--
	--

	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   |   |   |
	-- -----------------
	-- |   |   | O |   |
	-- -----------------

	-- ulx, uly, lrx, lry = CellCorners(3, 4)

	Cap(n_right, 1, 0, xoff, "counter_clockwise")

	--
	--
	--

	local function SyncTriBuilder (from)
		local indices, offset = (from or tri_builder):GetResult()

		tri_builder:SetIndices(indices)
		tri_builder:SetMaxIndex(npoints) -- account for bottom points
		tri_builder:SetOffset(offset)
	end

	local edge_params, populate_opts = {
		into_knots = knots, into_normals = normals, into_vertices = verts,
		lower_left_nx = 0, lower_left_ny = 0, lower_left_knot = .5,
		count = quad_count_along_axis,
		callback = params.edge_callback
	}, { no_normalize = params.normalize, callback = params.triangle_callback }

	local triangle_state = triangle.NewState()

	local function JunctionTriangles (llx, lly, lhs_lri, mid_index, rhs_lri, right_first, opts)
		local bottom1, left, right, bottom = opts and opts.bottom1

		left, right, bottom, npoints = triangle.Indices(points_along_axis, {
			nindices = npoints,
			bottom_indices = bottom1,
			lower_right_index = lhs_lri, top_index = mid_index,
			right_first = opts and opts.lhs_right_index or mid_index - 1, right_step = -1
		})

		SyncTriBuilder(opts and opts.builder) -- on first use, sync to previous builder; subsequently will be nil, i.e. do a self-sync

		if bottom1 then
			edge_params.lower_left_index = bottom1[1]
		else
			edge_params.lower_left_x, edge_params.lower_left_y, edge_params.lower_left_index = llx, lly
		end

		edge_params.lower_right_index = right[#right] -- ignored by LeftEdge()...
		edge_params.top_index = right[1] -- ...and by BottomEdge()

		triangle_state:LeftEdge(edge_params)

		if not bottom1 then
			triangle_state:BottomEdge(edge_params)
		end

		triangle_state:Populate(tri_builder, left, right, bottom, knots, normals, verts, populate_opts)

		npoints = #knots -- n + (n - 1) + (n - 2) boundary points, interior of sum(1, 2, ..., n - 4, n - 3)

		local lhs_bottom = bottom

		left, right, bottom, npoints = triangle.Indices(points_along_axis, {
			nindices = npoints,
			bottom_indices = opts and opts.bottom2,
			left_indices = left,
			lower_right_index = rhs_lri, top_index = mid_index, 
			right_first = right_first,
		})

		SyncTriBuilder()

		edge_params.lower_right_index = right[#right]

		if not bottom1 then
			triangle_state:BottomEdge(edge_params)
		end

		triangle_state:Populate(tri_builder, left, right, bottom, knots, normals, verts, populate_opts)

		npoints = #knots

		return lhs_bottom, bottom
	end

	--
	--
	--

	JunctionTriangles(bx, by, a_last, b_mid, c_upper, b_upper, { builder = cap_builder })
	JunctionTriangles(ex, ey, i_last, e_mid, a_upper, e_upper)
	JunctionTriangles(gx, gy, c_last, g_mid, k_upper, g_upper)
	JunctionTriangles(jx, jy, k_last, j_mid, i_upper, j_upper)

	local bottom1, bottom2 = JunctionTriangles(bx, ey, e_mid, b_mid, g_mid, be_last + to_first_on_shared_axis, { lhs_right_index = gb_last })

	JunctionTriangles(0, 0, g_mid, j_mid, e_mid, jg_last + to_first_on_shared_axis, { lhs_right_index = ej_last, bottom1 = bottom2, bottom2 = bottom1 })

	--
	--
	--

	return tri_builder:GetResult(), knots, normals, verts
end

--
--
--

return M