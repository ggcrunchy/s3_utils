--- Simplex noise mixins.

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
local includer = require("solar2d_utils.includer")
local qualifiers = require("s3_utils.snippets.utils.qualifiers")

-- Exports --
local M = {}

--
--
--

local Precision = qualifiers.DefaultPrecisionOr("P_POSITION")

--- DOCME
M.SIMPLEX_2D = includer.AddSnippet(([[

    // Uses 2D simplex noise from here: https://github.com/ashima/webgl-noise

    _PRECISION_ vec3 mod289 (_PRECISION_ vec3 x) {
      return x - floor(x * (1.0 / 289.0)) * 289.0;
    }

    _PRECISION_ vec2 mod289 (_PRECISION_ vec2 x) {
      return x - floor(x * (1.0 / 289.0)) * 289.0;
    }

    _PRECISION_ vec3 permute (_PRECISION_ vec3 x) {
      return mod289(((x*34.0)+1.0)*x);
    }

    _PRECISION_ float Simplex2 (_PRECISION_ vec2 v)
    {
      const _PRECISION_ vec4 C = vec4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0
                          0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
                         -0.577350269189626,  // -1.0 + 2.0 * C.x
                          0.024390243902439); // 1.0 / 41.0
    // First corner
      _PRECISION_ vec2 i  = floor(v + dot(v, C.yy) );
      _PRECISION_ vec2 x0 = v -   i + dot(i, C.xx);

    // Other corners
      _PRECISION_ vec2 i1;
      //i1.x = step( x0.y, x0.x ); // x0.x > x0.y ? 1.0 : 0.0
      //i1.y = 1.0 - i1.x;
      i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
      // x0 = x0 - 0.0 + 0.0 * C.xx ;
      // x1 = x0 - i1 + 1.0 * C.xx ;
      // x2 = x0 - 1.0 + 2.0 * C.xx ;
      _PRECISION_ vec4 x12 = x0.xyxy + C.xxzz;
      x12.xy -= i1;

    // Permutations
      i = mod289(i); // Avoid truncation effects in permutation
      _PRECISION_ vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
            + i.x + vec3(0.0, i1.x, 1.0 ));

      _PRECISION_ vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
      m = m*m ;
      m = m*m ;

    // Gradients: 41 points uniformly over a line, mapped onto a diamond.
    // The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)

      _PRECISION_ vec3 x = 2.0 * fract(p * C.www) - 1.0;
      _PRECISION_ vec3 h = abs(x) - 0.5;
      _PRECISION_ vec3 ox = floor(x + 0.5);
      _PRECISION_ vec3 a0 = x - ox;

    // Normalise gradients implicitly by scaling m
    // Approximation of: m *= inversesqrt( a0*a0 + h*h );
      m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );

    // Compute final noise value at P
      _PRECISION_ vec3 g;
      g.x  = a0.x  * x0.x  + h.x  * x0.y;
      g.yz = a0.yz * x12.xz + h.yz * x12.yw;
      return 130.0 * dot(m, g);
    }
]]):gsub("_PRECISION_", Precision))

--- DOCME
M.SIMPLEX_3D = includer.AddSnippet(([[

    // Uses 3D simplex noise from here: https://github.com/ashima/webgl-noise

    _PRECISION_ vec3 mod289 (_PRECISION_ vec3 x) {
      return x - floor(x * (1.0 / 289.0)) * 289.0;
    }

    _PRECISION_ vec4 mod289 (_PRECISION_ vec4 x) {
      return x - floor(x * (1.0 / 289.0)) * 289.0;
    }

    _PRECISION_ vec4 permute (_PRECISION_ vec4 x) {
         return mod289(((x*34.0)+1.0)*x);
    }

    _PRECISION_ vec4 taylorInvSqrt (_PRECISION_ vec4 r)
    {
      return 1.79284291400159 - 0.85373472095314 * r;
    }

    _PRECISION_ float Simplex3 (_PRECISION_ vec3 v)
    { 
      const _PRECISION_ vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
      const _PRECISION_ vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

    // First corner
      _PRECISION_ vec3 i  = floor(v + dot(v, C.yyy) );
      _PRECISION_ vec3 x0 =   v - i + dot(i, C.xxx) ;

    // Other corners
      _PRECISION_ vec3 g = step(x0.yzx, x0.xyz);
      _PRECISION_ vec3 l = 1.0 - g;
      _PRECISION_ vec3 i1 = min( g.xyz, l.zxy );
      _PRECISION_ vec3 i2 = max( g.xyz, l.zxy );

      //   x0 = x0 - 0.0 + 0.0 * C.xxx;
      //   x1 = x0 - i1  + 1.0 * C.xxx;
      //   x2 = x0 - i2  + 2.0 * C.xxx;
      //   x3 = x0 - 1.0 + 3.0 * C.xxx;
      _PRECISION_ vec3 x1 = x0 - i1 + C.xxx;
      _PRECISION_ vec3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
      _PRECISION_ vec3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y

    // Permutations
      i = mod289(i); 
      _PRECISION_ vec4 p = permute( permute( permute( 
                 i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
               + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) 
               + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

    // Gradients: 7x7 points over a square, mapped onto an octahedron.
    // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
      _PRECISION_ float n_ = 0.142857142857; // 1.0/7.0
      _PRECISION_ vec3  ns = n_ * D.wyz - D.xzx;

      _PRECISION_ vec4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,7*7)

      _PRECISION_ vec4 x_ = floor(j * ns.z);
      _PRECISION_ vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

      _PRECISION_ vec4 x = x_ *ns.x + ns.yyyy;
      _PRECISION_ vec4 y = y_ *ns.x + ns.yyyy;
      _PRECISION_ vec4 h = 1.0 - abs(x) - abs(y);

      _PRECISION_ vec4 b0 = vec4( x.xy, y.xy );
      _PRECISION_ vec4 b1 = vec4( x.zw, y.zw );

      //vec4 s0 = vec4(lessThan(b0,0.0))*2.0 - 1.0;
      //vec4 s1 = vec4(lessThan(b1,0.0))*2.0 - 1.0;
      _PRECISION_ vec4 s0 = floor(b0)*2.0 + 1.0;
      _PRECISION_ vec4 s1 = floor(b1)*2.0 + 1.0;
      _PRECISION_ vec4 sh = -step(h, vec4(0.0));

      _PRECISION_ vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
      _PRECISION_ vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

      _PRECISION_ vec3 p0 = vec3(a0.xy,h.x);
      _PRECISION_ vec3 p1 = vec3(a0.zw,h.y);
      _PRECISION_ vec3 p2 = vec3(a1.xy,h.z);
      _PRECISION_ vec3 p3 = vec3(a1.zw,h.w);

    //Normalise gradients
      _PRECISION_ vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
      p0 *= norm.x;
      p1 *= norm.y;
      p2 *= norm.z;
      p3 *= norm.w;

    // Mix final noise value
      _PRECISION_ vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
      m = m * m;
      return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), 
                                    dot(p2,x2), dot(p3,x3) ) );
      }
]]):gsub("_PRECISION_", Precision))

--- DOCME
M.FLOW_NOISE_2D = includer.AddSnippet(([[

    // GLSL implementation of 2D "flow noise" as presented
    // by Ken Perlin and Fabrice Neyret at Siggraph 2001.
    // (2D simplex noise with analytic derivatives and
    // in-plane rotation of generating gradients,
    // in a fractal sum where higher frequencies are
    // displaced (advected) by lower frequencies in the
    // direction of their gradient. For details, please
    // refer to the 2001 paper "Flow Noise" by Perlin and Neyret.)
    //
    // Author: Stefan Gustavson (stefan.gustavson@liu.se)
    // Distributed under the terms of the MIT license.
    // See LICENSE (above).

    // Helper constants
    #define F2 0.366025403
    #define G2 0.211324865
    #define K 0.0243902439 // 1/41

    // Permutation polynomial
    _PRECISION_ float permute (_PRECISION_ float x) {
      return mod((34.0 * x + 1.0)*x, 289.0);
    }

    // Gradient mapping with an extra rotation.
    _PRECISION_ vec2 grad2(vec2 p, float rot) {
    #ifdef ANISO_GRAD
    // Map from a line to a diamond such that a shift maps to a rotation.
      float u = permute(permute(p.x) + p.y) * K + rot; // Rotate by shift
      u = 4.0 * fract(u) - 2.0;
      return vec2(abs(u)-1.0, abs(abs(u+1.0)-2.0)-1.0);
    #else
    #define TWOPI 6.28318530718
    // For more isotropic gradients, sin/cos can be used instead.
      _PRECISION_ float u = permute(permute(p.x) + p.y) * K + rot; // Rotate by shift
      u = fract(u) * TWOPI;
      return vec2(cos(u), sin(u));
    #endif
    }

    _PRECISION_ float SimplexRD2 (_PRECISION_ vec2 P, _PRECISION_ float rot, $(D_OUT) vec2 grad)
    {
      // Transform input point to the skewed simplex grid
      _PRECISION_ vec2 Ps = P + dot(P, vec2(F2));

      // Round down to simplex origin
      _PRECISION_ vec2 Pi = floor(Ps);

      // Transform simplex origin back to (x,y) system
      _PRECISION_ vec2 P0 = Pi - dot(Pi, vec2(G2));

      // Find (x,y) offsets from simplex origin to first corner
      _PRECISION_ vec2 v0 = P - P0;

      // Pick (+x, +y) or (+y, +x) increment sequence
      _PRECISION_ vec2 i1 = (v0.x > v0.y) ? vec2(1.0, 0.0) : vec2 (0.0, 1.0);

      // Determine the offsets for the other two corners
      _PRECISION_ vec2 v1 = v0 - i1 + G2;
      _PRECISION_ vec2 v2 = v0 - 1.0 + 2.0 * G2;

      // Wrap coordinates at 289 to avoid float precision problems
      Pi = mod(Pi, 289.0);

      // Calculate the circularly symmetric part of each noise wiggle
      _PRECISION_ vec3 t = max(0.5 - vec3(dot(v0,v0), dot(v1,v1), dot(v2,v2)), 0.0);
      _PRECISION_ vec3 t2 = t*t;
      _PRECISION_ vec3 t4 = t2*t2;

      // Calculate the gradients for the three corners
      _PRECISION_ vec2 g0 = grad2(Pi, rot);
      _PRECISION_ vec2 g1 = grad2(Pi + i1, rot);
      _PRECISION_ vec2 g2 = grad2(Pi + 1.0, rot);

      // Compute noise contributions from each corner
      _PRECISION_ vec3 gv = vec3(dot(g0,v0), dot(g1,v1), dot(g2,v2)); // ramp: g dot v
      _PRECISION_ vec3 n = t4 * gv;  // Circular kernel times linear ramp

      // Compute partial derivatives in x and y
      _PRECISION_ vec3 temp = t2 * t * gv;
      _PRECISION_ vec3 gradx = temp * vec3(v0.x, v1.x, v2.x);
      _PRECISION_ vec3 grady = temp * vec3(v0.y, v1.y, v2.y);
      grad.x = -8.0 * (gradx.x + gradx.y + gradx.z);
      grad.y = -8.0 * (grady.x + grady.y + grady.z);
      grad.x += dot(t4, vec3(g0.x, g1.x, g2.x));
      grad.y += dot(t4, vec3(g0.y, g1.y, g2.y));
      grad *= 40.0;

      // Add contributions from the three corners and return
      return 40.0 * (n.x + n.y + n.z);
    }
]]):gsub("_PRECISION_", Precision))

return M