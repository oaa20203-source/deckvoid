#version 440

// Fluted glass: soft colour discs drifting over cream, seen through vertical flutes.
// Design: design/mockups/home-glass.html. Colours fade to distinct greys with `grey`.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;      // advances about 2.5 per second
    float grey;      // 0 = colour, 1 = greyscale (PC off)
    float seed;      // offsets the motion so two tiles do not move together
    float flutePx;   // flute width, a whole number of device pixels
    float radiusPx;  // corner radius in device pixels
    float variant;   // 0 hero, 1 app tile, 2 settings strip, 3 pairing page
    vec2 pixelSize;  // item size in device pixels
} ubuf;

const vec3 BASE   = vec3(239.0, 230.0, 210.0) / 255.0;
const vec3 ORANGE = vec3(247.0, 138.0, 31.0) / 255.0;
const vec3 SAGE   = vec3(127.0, 170.0, 140.0) / 255.0;
const vec3 BLUE   = vec3(60.0, 140.0, 175.0) / 255.0;
const vec3 AMBER  = vec3(240.0, 194.0, 74.0) / 255.0;
// Each colour's own grey, chosen so the shapes stay distinct without colour
const float G_BASE = 242.0 / 255.0;
const float G_ORANGE = 135.0 / 255.0;
const float G_SAGE = 195.0 / 255.0;
const float G_BLUE = 70.0 / 255.0;
const float G_AMBER = 220.0 / 255.0;

vec3 disc(vec3 col, vec2 p, float i, vec3 c, float g, vec2 centre, float r, vec2 amp)
{
    vec2 q = centre + amp * vec2(sin(ubuf.time * (0.23 + 0.05 * i) + ubuf.seed + i * 1.7),
                                 cos(ubuf.time * (0.19 + 0.04 * i) + ubuf.seed * 1.3 + i * 2.1));
    float d = length((p - q) * ubuf.pixelSize) / (r * ubuf.pixelSize.x);
    float a = d < 0.38 ? mix(1.0, 0.9, d / 0.38) : mix(0.9, 0.0, clamp((d - 0.38) / 0.62, 0.0, 1.0));
    return mix(col, mix(c, vec3(g), ubuf.grey), a);
}

void main()
{
    vec2 p = qt_TexCoord0;
    vec3 col = mix(BASE, vec3(G_BASE), ubuf.grey);

    if (ubuf.variant < 0.5) {
        vec2 amp = vec2(0.22, 0.22);
        col = disc(col, p, 0.0, ORANGE, G_ORANGE, vec2(0.32, 0.68), 0.72, amp);
        col = disc(col, p, 1.0, SAGE, G_SAGE, vec2(0.82, 0.22), 0.55, amp);
        col = disc(col, p, 2.0, BLUE, G_BLUE, vec2(0.04, 0.10), 0.34, amp);
        col = disc(col, p, 3.0, ORANGE, G_ORANGE, vec2(0.68, 0.88), 0.45, amp);
    }
    else if (ubuf.variant < 1.5) {
        vec2 amp = vec2(0.22, 0.22);
        col = disc(col, p, 0.0, SAGE, G_SAGE, vec2(0.60, 0.42), 0.78, amp);
        col = disc(col, p, 1.0, AMBER, G_AMBER, vec2(0.10, 0.90), 0.46, amp);
        col = disc(col, p, 2.0, ORANGE, G_ORANGE, vec2(0.96, 0.96), 0.30, amp);
    }
    else if (ubuf.variant < 2.5) {
        vec2 amp = vec2(0.16, 0.30);
        col = disc(col, p, 0.0, ORANGE, G_ORANGE, vec2(0.22, 0.75), 0.42, amp);
        col = disc(col, p, 1.0, SAGE, G_SAGE, vec2(0.78, 0.30), 0.40, amp);
        col = disc(col, p, 2.0, BLUE, G_BLUE, vec2(0.02, 0.10), 0.20, amp);
        col = disc(col, p, 3.0, AMBER, G_AMBER, vec2(0.55, 0.95), 0.22, amp);
        col = disc(col, p, 4.0, ORANGE, G_ORANGE, vec2(0.95, 0.90), 0.26, amp);
    }
    else {
        vec2 amp = vec2(0.20, 0.22);
        col = disc(col, p, 0.0, ORANGE, G_ORANGE, vec2(0.30, 0.70), 0.60, amp);
        col = disc(col, p, 1.0, SAGE, G_SAGE, vec2(0.82, 0.25), 0.50, amp);
        col = disc(col, p, 2.0, BLUE, G_BLUE, vec2(0.05, 0.10), 0.30, amp);
        col = disc(col, p, 3.0, AMBER, G_AMBER, vec2(0.60, 0.95), 0.30, amp);
        col = disc(col, p, 4.0, ORANGE, G_ORANGE, vec2(0.95, 0.85), 0.34, amp);
    }

    // Flutes: a soft highlight on the leading edge falling to a faint shadow, sampled
    // four times across the pixel so every flute is identical and stays soft.
    float xpx = p.x * ubuf.pixelSize.x;
    float w = 0.0;
    float dk = 0.0;
    for (int k = 0; k < 4; k++) {
        float u = fract((xpx - 0.5 + (float(k) + 0.5) / 4.0) / ubuf.flutePx);
        float wk;
        float dkk;
        if (u < 0.45) { wk = 0.5 * (1.0 - u / 0.45); dkk = 0.0; }
        else if (u < 0.91) { wk = 0.0; dkk = 0.12 * (u - 0.45) / 0.46; }
        else { float q = (u - 0.91) / 0.09; wk = 0.5 * q; dkk = 0.12 * (1.0 - q); }
        w += wk;
        dk += dkk * (1.0 - wk);
    }
    w *= 0.25;
    dk *= 0.25;
    col = col * (1.0 - w - dk) + vec3(w) + vec3(40.0, 50.0, 40.0) / 255.0 * dk;

    // Rounded corners
    vec2 hp = ubuf.pixelSize * 0.5;
    vec2 qd = abs(p * ubuf.pixelSize - hp) - hp + ubuf.radiusPx;
    float dist = length(max(qd, 0.0)) + min(max(qd.x, qd.y), 0.0) - ubuf.radiusPx;
    float alpha = clamp(0.5 - dist, 0.0, 1.0);

    fragColor = vec4(col, 1.0) * alpha * ubuf.qt_Opacity;
}
