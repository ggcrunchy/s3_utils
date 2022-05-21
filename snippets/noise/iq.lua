--- Mixins for "iq" noise. See also https://iquilezles.org/articles/.

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

local HashSnippet = includer.AddSnippet[[

    // Created by inigo quilez - iq/2013
    // License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
    #if !defined(GL_ES) || defined(GL_FRAGMENT_PRECISION_HIGH)
        #define IQ_HASH(n) fract(sin(n) * 43758.5453)
    #else
        #define IQ_HASH(n) fract(sin(n) * 43.7585453)
    #endif
]]
 
-- ^^ TODO: could refine this to vertex vs. fragment

local RequiresHash = { HashSnippet }

--- DOCME
M.IQ1 = includer.AddSnippet{
    requires = RequiresHash,

    any = ([[

    // Created by inigo quilez - iq/2013
    // License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
    _PRECISION_ float IQ (_PRECISION_ vec2 x)
    {
        _PRECISION_ vec2 p = floor(x);
        _PRECISION_ vec2 f = fract(x);

        f = f * f * (3.0 - 2.0 * f);

        _PRECISION_ float n = p.x + p.y * 57.0;

        return mix(mix(IQ_HASH(n +  0.0), IQ_HASH(n +  1.0), f.x),
                   mix(IQ_HASH(n + 57.0), IQ_HASH(n + 58.0), f.x), f.y);
    }
]]):gsub("_PRECISION_", Precision)

}

--
--
--

--- DOCME
M.OCTAVES = includer.AddSnippet{
    requires = { M.IQ1 },

    any = ([[

    _PRECISION_ vec2 IQ_Octaves (_PRECISION_ vec2 x, _PRECISION_ vec2 y)
    {
        return vec2(IQ(x) * .5, IQ(y) * .25);
    }
]]):gsub("_PRECISION_", Precision)

}

--
--
--

--- DOCME
M.IQ2 = includer.AddSnippet{
    requires = RequiresHash,

    any = ([[

    // Simplex Noise by IQ
    _PRECISION_ vec2 IQ2 (_PRECISION_ vec2 p)
    {
        p = vec2(dot(p, vec2(127.1, 311.7)),
                 dot(p, vec2(269.5, 183.3)));

        return -1. + 2. * IQ_HASH(p);
    }
]]):gsub("_PRECISION_", Precision)

}

--
--
--

local NoiseSnippet = includer.AddSnippet{
    requires = { M.IQ2 },

    any = ([[

    _PRECISION_ float noise (_PRECISION_ vec2 p)
    {
        const _PRECISION_ float K1 = 0.366025404; // (sqrt(3) - 1) / 2;
        const _PRECISION_ float K2 = 0.211324865; // (3 - sqrt(3)) / 6;

        _PRECISION_ vec2 i = floor(p + (p.x + p.y) * K1);
        
        _PRECISION_ vec2 a = p - i + (i.x + i.y) * K2;
        _PRECISION_ vec2 o = (a.x > a.y) ? vec2(1., 0.) : vec2(0., 1.); // vec2 of = 0.5 + 0.5*vec2(sign(a.x-a.y), sign(a.y-a.x));
        _PRECISION_ vec2 b = a - o + K2;
        _PRECISION_ vec2 c = a - 1. + 2. * K2;
        _PRECISION_ vec3 h = max(.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.);
        _PRECISION_ vec3 n = h * h * h * h * vec3(dot(a, IQ2(i)), dot(b, IQ2(i + o)), dot(c, IQ2(i + 1.)));

        return dot(n, vec3(70.0));
    }

    const _PRECISION_ mat2 NoiseMatrix = mat2(0.80,  0.60, -0.60,  0.80);
]]):gsub("_PRECISION_", Precision)

}

local RequiresNoise = { NoiseSnippet }

--- DOCME
M.FBM4 = includer.AddSnippet{
    requires = RequiresNoise,

    any = ([[

    _PRECISION_ float FBM4 (_PRECISION_ vec2 p)
    {
        _PRECISION_ float f = 0.0;

        f += 0.5000 * noise(p); p = NoiseMatrix * p * 2.02;
        f += 0.2500 * noise(p); p = NoiseMatrix * p * 2.03;
        f += 0.1250 * noise(p); p = NoiseMatrix * p * 2.01;
        f += 0.0625 * noise(p);

        return f;
    }
]]):gsub("_PRECISION_", Precision)

}

--
--
--

--- DOCME
M.TURB4 = includer.AddSnippet{
    requires = RequiresNoise,

    any = ([[

    _PRECISION_ float Turb4 (_PRECISION_ vec2 p)
    {
        _PRECISION_ float f = 0.0;

        f += 0.5000 * abs(noise(p)); p = NoiseMatrix * p * 2.02;
        f += 0.2500 * abs(noise(p)); p = NoiseMatrix * p * 2.03;
        f += 0.1250 * abs(noise(p)); p = NoiseMatrix * p * 2.01;
        f += 0.0625 * abs(noise(p));

        return f;
    }
]]):gsub("_PRECISION_", Precision)

}

--
--
--

return M