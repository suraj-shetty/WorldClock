#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// The canvas sky's noise surfaces, as SwiftUI shaders. `turbulence` is SVG's feTurbulence,
// ported from the spec's reference code with the same seeded tables (SkyNoise.table), so
// the clouds, rock, snow, Milky Way and moon carry the canvas's own noise.
// Table layout: 514 lattice entries, then 4 channels × 514 gradients × (x, y).

constant int kLattice = 514;

static float2 gradientAt(device const float *t, int channel, int i) {
    int o = kLattice + (channel * kLattice + i) * 2;
    return float2(t[o], t[o + 1]);
}

static float noise2(device const float *t, int channel, float2 v) {
    float tx = v.x + 4096.0, ty = v.y + 4096.0;
    int ix = int(tx), iy = int(ty);
    int bx0 = ix & 255, bx1 = (bx0 + 1) & 255, by0 = iy & 255, by1 = (by0 + 1) & 255;
    float rx0 = tx - float(ix), rx1 = rx0 - 1.0, ry0 = ty - float(iy), ry1 = ry0 - 1.0;
    int i = int(t[bx0]), j = int(t[bx1]);
    int b00 = int(t[i + by0]), b10 = int(t[j + by0]), b01 = int(t[i + by1]), b11 = int(t[j + by1]);
    float sx = rx0 * rx0 * (3.0 - 2.0 * rx0), sy = ry0 * ry0 * (3.0 - 2.0 * ry0);
    float a = mix(dot(float2(rx0, ry0), gradientAt(t, channel, b00)), dot(float2(rx1, ry0), gradientAt(t, channel, b10)), sx);
    float b = mix(dot(float2(rx0, ry1), gradientAt(t, channel, b01)), dot(float2(rx1, ry1), gradientAt(t, channel, b11)), sx);
    return mix(a, b, sy);
}

/// One channel of feTurbulence at user-space `p`, 0…1. `fractal` is type="fractalNoise".
static float turbulence(device const float *t, int channel, float2 p, float2 freq, int octaves, bool fractal) {
    float sum = 0.0, ratio = 1.0;
    float2 v = p * freq;
    for (int o = 0; o < octaves; o++) {
        float n = noise2(t, channel, v);
        sum += (fractal ? n : abs(n)) / ratio;
        v *= 2.0;
        ratio *= 2.0;
    }
    return clamp(fractal ? (sum + 1.0) / 2.0 : sum, 0.0, 1.0);
}

/// Noise as coverage (feColorMatrix on one channel, then `in`): `color` where
/// clamp(map.x · noise + map.y) says so. `rotation` = (angle, pivot) undoes a rotated
/// shape, so the noise runs along it as it does inside the canvas's rotated group.
[[ stitchable ]] half4 skyNoise(float2 position, device const float *t, int count, float2 freq, float octaves,
                                float channel, float3 color, float2 map, float3 rotation) {
    float c = cos(rotation.x), s = sin(rotation.x);
    float2 d = position - rotation.yz;
    float2 local = rotation.yz + float2(c * d.x + s * d.y, -s * d.x + c * d.y);
    float a = clamp(map.x * turbulence(t, int(channel), local, freq, int(octaves), true) + map.y, 0.0, 1.0);
    return half4(half3(color * a), half(a));
}

/// feDiffuseLighting over a noise height field: the Sobel normal of surfaceScale · height
/// (a one-unit kernel), Lambert against a distant light, then `base + mixIn · lit`.
/// Clouds keep the height as coverage; rock relief (coverage 0) is an opaque light map.
[[ stitchable ]] half4 skyLitNoise(float2 position, device const float *t, int count, float2 freq, float octaves,
                                   float channel, float2 map, float surfaceScale, float diffuse, float3 lightDir,
                                   float3 lightColor, float3 base, float mixIn, float coverage) {
    float h[9];
    int k = 0;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            float n = turbulence(t, int(channel), position + float2(dx, dy), freq, int(octaves), true);
            h[k++] = clamp(map.x * n + map.y, 0.0, 1.0);
        }
    }
    float nx = -surfaceScale * 0.25 * ((h[2] + 2.0 * h[5] + h[8]) - (h[0] + 2.0 * h[3] + h[6]));
    float ny = -surfaceScale * 0.25 * ((h[6] + 2.0 * h[7] + h[8]) - (h[0] + 2.0 * h[1] + h[2]));
    float3 n = normalize(float3(nx, ny, 1.0));
    float3 lit = clamp(diffuse * max(dot(n, lightDir), 0.0) * lightColor, 0.0, 1.0);
    float3 col = clamp(base + mixIn * lit, 0.0, 1.0);
    float a = coverage > 0.5 ? h[4] : 1.0;
    return half4(half3(col * a), half(a));
}

/// The lake's ripple (feDisplacementMap over type="turbulence"): each reflected pixel
/// samples the scene a little to the side, by the noise's red and green. The canvas runs
/// it inside the mirrored group, so the noise is read in mirrored coordinates (y about
/// `mirrorY`) and its vertical push is flipped on screen.
[[ stitchable ]] float2 skyRipple(float2 position, device const float *t, int count, float2 freq, float scale, float mirrorY) {
    float2 local = float2(position.x, mirrorY - position.y);
    float r = turbulence(t, 0, local, freq, 2, false);
    float g = turbulence(t, 1, local, freq, 2, false);
    return position + scale * float2(r - 0.5, 0.5 - g);
}
