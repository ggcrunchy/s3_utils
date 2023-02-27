--- Tile shape primitives, e.g. points and edges.

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
local tile_texture_flags = require("s3_utils.tile_texture.flags")
local tile_texture_norms = require("s3_utils.tile_texture.norms")

-- Cached module references --
local _AddLerpedPair_
local _AddPair_
local _AddU_
local _GetEdgeNormal_

-- Exports --
local M = {}

--
--
--

function M.AddIndexedTriangle (is, i1, i2, i3)
  is[#is + 1] = i1
  is[#is + 1] = i2
  is[#is + 1] = i3
end

--
--
--

local function Lerp (v1, v2, t)
  return v1 + (v2 - v1) * t
end

--
--
--

function M.AddLerpedPair (list, a1, b1, a2, b2, t)
  return _AddPair_(list, Lerp(a1, a2, t), Lerp(b1, b2, t))
end

--
--
--

function M.AddPair (list, a, b)
  list[#list + 1] = a
  list[#list + 1] = b

  return #list / 2
end

--
--
--

function M.AddU (uvs, u1, u2, t, do_parabola)
  local u = Lerp(u1, u2, t)

  _AddPair_(uvs, u, do_parabola and 4 * u * (1 - u) or 0)
end

--
--
--

function M.Edge (sources, x1, y1, u1, x2, y2, u2, nsegs, flags)
  local what, normals = "forward", sources.normals

  if normals then
    if not tile_texture_flags.HasFlag(flags, "DoNormals") then
      normals = nil
    elseif tile_texture_flags.HasFlag(flags, "ReverseEdge") then
      what = "backward"
    end
  end

  --
  --
  --

  local edge, vs, uvs, nx, ny = {}, sources.vertices, sources.uvs, _GetEdgeNormal_()

  if not tile_texture_flags.HasFlag(flags, "DummyFirst") then
    edge[1] = _AddPair_(vs, x1, y1)

    if normals then
      tile_texture_norms.Arc(normals, what, nx, ny, 1, nsegs + 1)
    end

    _AddPair_(uvs, u1, 0)
  else
    edge[1] = false
  end

  --
  --
  --

  local do_parabola = tile_texture_flags.HasFlag(flags, "Parabola")

  for i = 2, nsegs do
    local t = (i - 1) / nsegs

    edge[#edge + 1] = _AddLerpedPair_(vs, x1, y1, x2, y2, t)

    if normals then
      tile_texture_norms.Arc(normals, what, nx, ny, i, nsegs + 1)
    end

    _AddU_(uvs, u1, u2, t, do_parabola)
  end

  --
  --
  --

  if not tile_texture_flags.HasFlag(flags, "OmitLast") then
    edge[#edge + 1] = _AddPair_(vs, x2, y2)

    if normals then
      tile_texture_norms.Arc(normals, what, nx, ny, nsegs + 1, nsegs + 1)
    end

    _AddPair_(uvs, u2, 0)
  end

  --
  --
  --

  return edge
end

--
--
--

local Nx, Ny

--
--
--

function M.GetEdgeNormal ()
  return Nx, Ny
end

--
--
--

function M.GetPoint (sources, index)
  index = index * 2 -- resolve to pairs

  local vs, uvs = sources.vertices, sources.uvs

  return vs[index - 1], vs[index], uvs[index - 1]
end

--
--
--

function M.ReverseEdge (edge, n)
  local i, j = 1, n or #edge

  while i < j do
    edge[i], edge[j], i, j = edge[j], edge[i], i + 1, j - 1
  end
end

--
--
--

function M.SetEdgeNormal (nx, ny)
  Nx, Ny = nx, ny
end

--
--
--

_AddLerpedPair_ = M.AddLerpedPair
_AddPair_ = M.AddPair
_AddU_ = M.AddU
_GetEdgeNormal_ = M.GetEdgeNormal

return M