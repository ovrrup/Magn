#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

vec3 getBaseGradient(vec2 p) {
    vec3 deepRed = vec3(0.667, 0.0, 0.012);
    vec3 coralPink = vec3(1.0, 0.42, 0.42);
    vec3 warmCream = vec3(1.0, 0.929, 0.835);

    vec3 col;
    if (p.y < 0.5) {
        col = mix(deepRed, coralPink, clamp(p.y / 0.5, 0.0, 1.0));
    } else {
        col = mix(coralPink, warmCream, clamp((p.y - 0.5) / 0.5, 0.0, 1.0));
    }

    // Slowly drifting radial color orbs driven by uTime * 0.25
    float t = uTime * 0.25;
    vec2 orb1 = vec2(0.35 + 0.2 * sin(t), 0.35 + 0.15 * cos(t * 0.9));
    vec2 orb2 = vec2(0.65 + 0.18 * cos(t * 0.7), 0.65 + 0.18 * sin(t * 1.2));

    float d1 = length(p - orb1);
    float d2 = length(p - orb2);

    col += coralPink * (0.18 * exp(-d1 * 2.8));
    col += warmCream * (0.14 * exp(-d2 * 3.2));

    return col;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uSize;

    // Base background gradient
    vec3 baseColor = getBaseGradient(uv);

    // Square tile grid of 6 columns
    float gridCols = 6.0;
    vec2 gridUV = fragCoord / (uSize.x / gridCols);
    vec2 cellId = floor(gridUV);
    vec2 cellLocal = fract(gridUV) - 0.5;

    // Quantize background sampling coordinates combined with subtle lens refraction offset
    vec2 refractedUV = (cellId + 0.5 + cellLocal * 0.35) * (uSize.x / gridCols) / uSize;
    refractedUV = clamp(refractedUV, 0.0, 1.0);

    // Refracted tile color from the background gradient
    vec3 tileColor = getBaseGradient(refractedUV);

    // 2D rounded box Signed Distance Field
    vec2 d = abs(cellLocal) - vec2(0.45);
    float sdf = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - 0.08;

    // Crisp anti-aliased tile edges
    float tileAlpha = smoothstep(0.01, -0.01, sdf);

    // 3D pillowed glass inner bevel and top-left specular highlight
    float bevel = clamp((0.0 - cellLocal.x - cellLocal.y) * 0.6, -0.15, 0.25) * smoothstep(0.0, -0.15, sdf);

    // Bright 1px-equivalent inner rim highlight along the tile border
    float rim = smoothstep(-0.03, 0.0, sdf) * smoothstep(0.01, -0.01, sdf) * 0.35;

    // Subtle high-frequency procedural frost grain
    float grain = fract(sin(dot(fragCoord, vec2(12.9898, 78.233))) * 43758.5453) * 0.025;

    // Apply lighting and texture highlights
    tileColor += vec3(bevel);
    tileColor += vec3(rim);
    tileColor += vec3(grain);

    // Fade mask toward top and bottom edges
    float mask = smoothstep(0.05, 0.35, uv.y) * smoothstep(0.95, 0.65, uv.y);

    // Composite frosted tiles over the base gradient
    vec3 finalColor = mix(baseColor, tileColor, tileAlpha * mask);

    fragColor = vec4(finalColor, 1.0);
}
