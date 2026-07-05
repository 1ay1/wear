// PHOSPHOR TRACE v5 — instrument-grade.
// Design language: high-end measurement gear, not neon toy.
//   • hairline beams: near-white hot core, color lives only in the halo
//   • desaturated phosphor palette, low blacks, filmic rolloff
//   • whisper grid, engraved labels, right-edge live value ticks
//   • one beam per lane: CPU / MEM / NET / GPU, fixed honest scales
// Buffer A: two history rows (VU-style asymmetric EMA):
//   bottom row (y<0.5): cpu, ram, netDown, netUp
//   top row    (y>0.5): gpu, vram, swap, load

// ============================ Buffer A ============================
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 px = 1.0 / iResolution.xy;

    bool shift = mod(float(iFrame), 4.0) < 0.5;
    vec4 prev = texture(iChannel0, uv + (shift ? vec2(px.x, 0.0) : vec2(0.0)));

    if (uv.x > 1.0 - px.x) {
        bool topRow = uv.y > 0.5;
        vec4 last = texture(iChannel0, vec2(1.0 - px.x * 0.5, topRow ? 0.75 : 0.25));
        vec4 now = topRow ? vec4(iNvGpu, iNvVram, iSwap, iLoad)
                          : vec4(iCpu, iRam, iNetDown, iNetUp);
        vec4 k = mix(vec4(0.05), vec4(0.25), step(last, now));
        prev = mix(last, now, k);
    }
    if (iFrame < 2) prev = vec4(0.0);
    fragColor = prev;
}

// ============================== Image =============================

float rnd(vec2 co){ return fract(sin(dot(co, vec2(12.9898,78.233)))*43758.5453); }

vec4 hist(float x){ return texture(iChannel1, vec2(clamp(x, 0.0, 1.0), 0.25)); }
vec4 hist2(float x){ return texture(iChannel1, vec2(clamp(x, 0.0, 1.0), 0.75)); }
float chan(vec4 h, int ch){ return ch==0 ? h.r : ch==1 ? h.g : ch==2 ? h.b : h.a; }

float sig(float x, int ch){
    float w = 3.0 / iResolution.x;
    return (chan(hist(x - 2.0*w), ch) + chan(hist(x - w), ch) + chan(hist(x), ch)
          + chan(hist(x + w), ch) + chan(hist(x + 2.0*w), ch)) * 0.2;
}

// top history row: gpu(r) vram(g) swap(b) load(a)
float sig2(float x, int ch){
    float w = 3.0 / iResolution.x;
    return (chan(hist2(x - 2.0*w), ch) + chan(hist2(x - w), ch) + chan(hist2(x), ch)
          + chan(hist2(x + w), ch) + chan(hist2(x + 2.0*w), ch)) * 0.2;
}
// swap lives in top row channel 2 (blue)
float sigS(float x){ return sig2(x, 2); }

float traceDist(vec2 fragCoord, int ch, float baseY, float amp){
    float x  = fragCoord.x / iResolution.x;
    float hx = 3.0 / iResolution.x;
    float f0 = sig(x, ch), fp = sig(x + hx, ch), fm = sig(x - hx, ch);
    float yPx  = (baseY + clamp(f0, 0.0, 1.0) * amp) * iResolution.y;
    float dydx = (fp - fm) * amp * iResolution.y / (2.0 * hx * iResolution.x);
    return abs(fragCoord.y - yPx) / sqrt(1.0 + dydx * dydx);
}

float traceDistS(vec2 fragCoord, float baseY, float amp){
    float x  = fragCoord.x / iResolution.x;
    float hx = 3.0 / iResolution.x;
    float f0 = sigS(x), fp = sigS(x + hx), fm = sigS(x - hx);
    float yPx  = (baseY + clamp(f0, 0.0, 1.0) * amp) * iResolution.y;
    float dydx = (fp - fm) * amp * iResolution.y / (2.0 * hx * iResolution.x);
    return abs(fragCoord.y - yPx) / sqrt(1.0 + dydx * dydx);
}

// generic top-row trace (gpu=0 vram=1 swap=2 load=3)
float traceDist2(vec2 fragCoord, int ch, float baseY, float amp){
    float x  = fragCoord.x / iResolution.x;
    float hx = 3.0 / iResolution.x;
    float f0 = sig2(x, ch), fp = sig2(x + hx, ch), fm = sig2(x - hx, ch);
    float yPx  = (baseY + clamp(f0, 0.0, 1.0) * amp) * iResolution.y;
    float dydx = (fp - fm) * amp * iResolution.y / (2.0 * hx * iResolution.x);
    return abs(fragCoord.y - yPx) / sqrt(1.0 + dydx * dydx);
}

// instrument beam: crisp tinted-white core, chromatic halo carries identity.
// `sd` is the SIGNED offset from the trace (fragY - traceY, in px) so we can
// fake CRT chromatic fringing for free: red bleeds below, blue above the trace.
vec3 beam(float d, float sd, vec3 tint){
    vec3 c = vec3(0.0);
    float core = smoothstep(0.95, 0.18, d);
    // hot core: tight, near-white — reads as a sharp scope trace, not a glow
    c += mix(tint, vec3(1.0), 0.78) * core * 1.55;
    // chromatic fringe: split the halo by sign so the edge shimmers R/B like glass
    float fringe = exp(-d * d / 11.0) * 0.44;
    vec3 chroma = tint + vec3(0.18, 0.0, -0.18) * clamp(sd * 0.18, -1.0, 1.0);
    c += chroma * fringe;
    c += tint * exp(-d / 34.0) * 0.075;                             // outer breath, wider glow
    return c;
}
// back-compat unsigned overload (fringe disabled)
vec3 beam(float d, vec3 tint){ return beam(d, 0.0, tint); }

// ---- 3x5 bitmap font ----
float lrow(float ch, float r){
    if (ch < 0.5) return r<1.0?7.0 : r<2.0?4.0 : r<3.0?4.0 : r<4.0?4.0 : 7.0; // C 0
    if (ch < 1.5) return r<1.0?7.0 : r<2.0?5.0 : r<3.0?7.0 : r<4.0?4.0 : 4.0; // P 1
    if (ch < 2.5) return r<1.0?5.0 : r<2.0?5.0 : r<3.0?5.0 : r<4.0?5.0 : 7.0; // U 2
    if (ch < 3.5) return r<1.0?5.0 : r<2.0?7.0 : r<3.0?5.0 : r<4.0?5.0 : 5.0; // M 3
    if (ch < 4.5) return r<1.0?7.0 : r<2.0?4.0 : r<3.0?7.0 : r<4.0?4.0 : 7.0; // E 4
    if (ch < 5.5) return r<1.0?5.0 : r<2.0?7.0 : r<3.0?7.0 : r<4.0?5.0 : 5.0; // N 5
    if (ch < 6.5) return r<1.0?7.0 : r<2.0?2.0 : r<3.0?2.0 : r<4.0?2.0 : 2.0; // T 6
    if (ch < 7.5) return r<1.0?6.0 : r<2.0?5.0 : r<3.0?6.0 : r<4.0?5.0 : 5.0; // R 7
    if (ch < 8.5) return r<1.0?7.0 : r<2.0?4.0 : r<3.0?7.0 : r<4.0?1.0 : 7.0; // S 8
    if (ch < 9.5) return r<1.0?7.0 : r<2.0?4.0 : r<3.0?5.0 : r<4.0?5.0 : 7.0; // G 9
    // digits 10..19 -> 0..9
    float d = ch - 10.0;
    if (d < 0.5) return r<1.0?7.0 : r<2.0?5.0 : r<3.0?5.0 : r<4.0?5.0 : 7.0; // 0
    if (d < 1.5) return r<1.0?2.0 : r<2.0?6.0 : r<3.0?2.0 : r<4.0?2.0 : 7.0; // 1
    if (d < 2.5) return r<1.0?7.0 : r<2.0?1.0 : r<3.0?7.0 : r<4.0?4.0 : 7.0; // 2
    if (d < 3.5) return r<1.0?7.0 : r<2.0?1.0 : r<3.0?3.0 : r<4.0?1.0 : 7.0; // 3
    if (d < 4.5) return r<1.0?5.0 : r<2.0?5.0 : r<3.0?7.0 : r<4.0?1.0 : 1.0; // 4
    if (d < 5.5) return r<1.0?7.0 : r<2.0?4.0 : r<3.0?7.0 : r<4.0?1.0 : 7.0; // 5
    if (d < 6.5) return r<1.0?7.0 : r<2.0?4.0 : r<3.0?7.0 : r<4.0?5.0 : 7.0; // 6
    if (d < 7.5) return r<1.0?7.0 : r<2.0?1.0 : r<3.0?1.0 : r<4.0?1.0 : 1.0; // 7
    if (d < 8.5) return r<1.0?7.0 : r<2.0?5.0 : r<3.0?7.0 : r<4.0?5.0 : 7.0; // 8
    if (d < 9.5) return r<1.0?7.0 : r<2.0?5.0 : r<3.0?7.0 : r<4.0?1.0 : 7.0; // 9
    // hex letters, ids 20..25 -> A B C D E F
    float h = ch - 20.0;
    if (h < 0.5) return r<1.0?7.0 : r<2.0?5.0 : r<3.0?7.0 : r<4.0?5.0 : 5.0; // A
    if (h < 1.5) return r<1.0?6.0 : r<2.0?5.0 : r<3.0?6.0 : r<4.0?5.0 : 6.0; // B
    if (h < 2.5) return r<1.0?7.0 : r<2.0?4.0 : r<3.0?4.0 : r<4.0?4.0 : 7.0; // C
    if (h < 3.5) return r<1.0?6.0 : r<2.0?5.0 : r<3.0?5.0 : r<4.0?5.0 : 6.0; // D
    if (h < 4.5) return r<1.0?7.0 : r<2.0?4.0 : r<3.0?7.0 : r<4.0?4.0 : 7.0; // E
    if (h < 5.5) return r<1.0?7.0 : r<2.0?4.0 : r<3.0?7.0 : r<4.0?4.0 : 4.0; // F
    if (h < 6.5) return r<1.0?5.0 : r<2.0?5.0 : r<3.0?5.0 : r<4.0?5.0 : 2.0; // V 26
    if (h < 7.5) return r<1.0?5.0 : r<2.0?1.0 : r<3.0?2.0 : r<4.0?4.0 : 5.0; // % 27
    if (h < 8.5) return r<1.0?0.0 : r<2.0?2.0 : r<3.0?0.0 : r<4.0?2.0 : 0.0; // : 28
    if (h < 9.5) return r<1.0?5.0 : r<2.0?5.0 : r<3.0?2.0 : r<4.0?2.0 : 2.0; // Y 29
    if (h <10.5) return r<1.0?0.0 : r<2.0?5.0 : r<3.0?2.0 : r<4.0?5.0 : 0.0; // x 30
    return              r<1.0?5.0 : r<2.0?5.0 : r<3.0?5.0 : r<4.0?7.0 : 5.0; // W 31
}
// map an old lrow glyph-id to a real ASCII code, so all the legacy
// label/num/hex helpers can render through the crisp font atlas (iChannel2).
// ids: 0-9 = C P U M E N T R S G ; 10-19 = '0'-'9' ; 20-25 = A-F ;
//      26=V 27=% 28=: 29=Y 30=x 31=W
float glyphAscii(float ch){
    float c = floor(ch + 0.5);
    if (c < 9.5) {
        // C P U M E N T R S G
        if (c < 0.5) return 67.0;  if (c < 1.5) return 80.0;
        if (c < 2.5) return 85.0;  if (c < 3.5) return 77.0;
        if (c < 4.5) return 69.0;  if (c < 5.5) return 78.0;
        if (c < 6.5) return 84.0;  if (c < 7.5) return 82.0;
        if (c < 8.5) return 83.0;  return 71.0;
    }
    if (c < 19.5) return 48.0 + (c - 10.0);        // 0-9
    if (c < 25.5) return 65.0 + (c - 20.0);        // A-F
    if (c < 26.5) return 86.0;                     // V
    if (c < 27.5) return 37.0;                     // %
    if (c < 28.5) return 58.0;                     // :
    if (c < 29.5) return 89.0;                     // Y
    if (c < 30.5) return 120.0;                    // x
    return 87.0;                                   // W
}
float letterPx(vec2 p, float ch){
    // p spans one glyph cell with y increasing upward (GL), exactly what the
    // atlas helper expects (nwGlyph flips y internally). Render via iChannel2.
    return nwGlyph(iChannel2, glyphAscii(ch), p);
}
float label3(vec2 fragCoord, vec2 pos, float s, float c0, float c1, float c2){
    vec2 p = (fragCoord - pos) / vec2(s * 0.72, s);
    return letterPx(p, c0) + letterPx(p - vec2(1.45, 0.0), c1) + letterPx(p - vec2(2.9, 0.0), c2);
}
float label2(vec2 fragCoord, vec2 pos, float s, float c0, float c1){
    vec2 p = (fragCoord - pos) / vec2(s * 0.72, s);
    return letterPx(p, c0) + letterPx(p - vec2(1.45, 0.0), c1);
}

// 2-digit numeric readout (00-99)
float num2(vec2 fragCoord, vec2 pos, float s, float val){
    val = clamp(floor(val + 0.5), 0.0, 99.0);
    vec2 p = (fragCoord - pos) / vec2(s * 0.72, s);
    return letterPx(p, 10.0 + floor(val / 10.0)) + letterPx(p - vec2(1.45, 0.0), 10.0 + mod(val, 10.0));
}

// 3-digit numeric readout (000-999)
float num3(vec2 fragCoord, vec2 pos, float s, float val){
    val = clamp(floor(val + 0.5), 0.0, 999.0);
    vec2 p = (fragCoord - pos) / vec2(s * 0.72, s);
    return letterPx(p, 10.0 + floor(val / 100.0))
         + letterPx(p - vec2(1.45, 0.0), 10.0 + floor(mod(val, 100.0) / 10.0))
         + letterPx(p - vec2(2.9, 0.0), 10.0 + mod(val, 10.0));
}

// hex glyph id for value 0..15
float hexId(float v){ return v < 9.5 ? 10.0 + v : 20.0 + (v - 10.0); }

// 2-digit HEX readout (00-FF)
float hex2(vec2 fragCoord, vec2 pos, float s, float val){
    val = clamp(floor(val + 0.5), 0.0, 255.0);
    vec2 p = (fragCoord - pos) / vec2(s * 0.72, s);
    return letterPx(p, hexId(floor(val / 16.0))) + letterPx(p - vec2(1.45, 0.0), hexId(mod(val, 16.0)));
}

// one hex nibble at a cell — building block for the live memory dump
float hex1(vec2 fragCoord, vec2 pos, float s, float nib){
    vec2 p = (fragCoord - pos) / vec2(s * 0.72, s);
    return letterPx(p, hexId(clamp(floor(nib + 0.5), 0.0, 15.0)));
}

// ---- opcode mnemonic table: id -> 3 glyph codes (for the disasm ticker) ----
// glyph ids (from lrow): C0 P1 U2 M3 E4 N5 T6 R7 S8 G9  A20 B21 C22 D23 E24 F25 V26
vec3 mnem(float id){
    id = mod(floor(id), 16.0);
    if (id < 0.5)  return vec3(20.0, 23.0, 23.0); // A D D
    if (id < 1.5)  return vec3(22.0,  3.0,  1.0); // C M P
    if (id < 2.5)  return vec3(22.0, 20.0,  8.0); // C A S
    if (id < 3.5)  return vec3(24.0,  5.0, 23.0); // E N D
    if (id < 4.5)  return vec3( 7.0,  4.0,  6.0); // R E T
    if (id < 5.5)  return vec3( 9.0,  4.0,  6.0); // G E T
    if (id < 6.5)  return vec3(21.0,  6.0,  8.0); // B T S
    if (id < 7.5)  return vec3(22.0,  6.0,  7.0); // C T R
    if (id < 8.5)  return vec3( 8.0,  4.0,  6.0); // S E T
    if (id < 9.5)  return vec3( 5.0, 26.0,  6.0); // N V T
    if (id <10.5)  return vec3(23.0,  4.0,  0.0); // D E C
    if (id <11.5)  return vec3(24.0,  5.0, 22.0); // E N C
    if (id <12.5)  return vec3(20.0,  5.0, 23.0); // A N D
    if (id <13.5)  return vec3( 8.0,  6.0,  7.0); // S T R
    if (id <14.5)  return vec3(22.0, 20.0,  7.0); // C A R
    return              vec3( 5.0, 26.0,  1.0);   // N V P
}

// corner bracket set for a rect (px coords), hud-style
float brackets(vec2 fragCoord, vec2 lo, vec2 hi, float len, float th){
    vec2 p = fragCoord;
    float m = 0.0;
    vec2 c;
    // distances to each corner's two arms
    for (int i = 0; i < 4; i++) {
        c = vec2(i == 0 || i == 2 ? lo.x : hi.x, i < 2 ? lo.y : hi.y);
        vec2 dir = vec2(c.x == lo.x ? 1.0 : -1.0, c.y == lo.y ? 1.0 : -1.0);
        vec2 d = (p - c) * dir;                    // both >=0 inside
        float armH = step(abs(p.y - c.y), th) * step(0.0, d.x) * step(d.x, len);
        float armV = step(abs(p.x - c.x), th) * step(0.0, d.y) * step(d.y, len);
        m = max(m, max(armH, armV));
    }
    return m;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float t = iTime;

    // lane identities — ONE color per lane, never shared:
    //   CPU = sage green · MEM = steel cyan · NET = amber
    vec3 sage  = vec3(0.35, 0.85, 0.48);
    vec3 steel = vec3(0.30, 0.72, 0.85);
    vec3 brass = vec3(0.85, 0.62, 0.25);
    vec3 sred  = vec3(0.90, 0.25, 0.30);
    vec3 lilac = vec3(0.62, 0.50, 0.88);   // swap / vmem ghost

    vec3 L = vec3(0.0);

    // ---- ground: slow-drifting aurora haze ----
    // Cheap: 4 sine lobes instead of multi-octave fbm (fbm ran on ALL 5M px/frame
    // — by far the heaviest cost). Same soft low-freq drift, a fraction of the ALU.
    vec2 nuv = uv * vec2(iResolution.x / iResolution.y, 1.0);
    float neb = 0.5 + 0.5 * sin(nuv.x * 2.3 + t * 0.06)
                          * sin(nuv.y * 1.9 - t * 0.043 + 1.7);
    neb = mix(neb, 0.5 + 0.5 * sin((nuv.x + nuv.y) * 1.4 - t * 0.035), 0.5);
    // palette shifts once per frame with load, not per pixel (constant across screen)
    vec3 nebInk = nwPalette(0.55 - iCpu * 0.06 + iTime * 0.004,
                            vec3(0.10, 0.10, 0.09), vec3(0.06, 0.09, 0.10),
                            vec3(1.0, 1.0, 1.0), vec3(0.30, 0.55, 0.70));
    L += vec3(0.010, 0.016, 0.013) * (0.72 + 0.28 * uv.y);
    L += nebInk * neb * neb * 0.055;                            // squared = softer, darker lows

    // ---- whisper grid: 1px hairlines, majors only ----
    vec2 gm = abs(fract(fragCoord.xy / 160.0) - 0.5) * 160.0;
    float major = smoothstep(0.9, 0.2, min(gm.x, gm.y));
    L += sage * major * 0.014;

    // ---- drifting starfield: tiny cold points, twinkling, deep background ----
    // single hash reused for both mask and twinkle phase
    float sh = rnd(floor(fragCoord.xy * 0.4));
    float star = step(0.9975, sh);
    L += vec3(0.55, 0.65, 0.70) * star * (0.5 + 0.5 * sin(t * 2.0 + sh * 40.0)) * 0.10;

    // ---- hex address ruler along the very top edge ----
    // ticks every 64px; every 4th tick tall + hex address glyphs (0x00..)
    if (fragCoord.y > iResolution.y - 26.0) {
        float tick = fract(fragCoord.x / 64.0);
        float t4   = fract(fragCoord.x / 256.0);
        float tickL = smoothstep(1.2, 0.3, tick * 64.0)
                    * (t4 * 256.0 < 1.5 ? 1.0 : 0.45);
        float ty = (iResolution.y - fragCoord.y) / 26.0;   // 0 top..1
        L += sage * tickL * step(ty, t4 * 256.0 < 1.5 ? 0.9 : 0.45) * 0.12;
        // hex address label at every major tick — REAL hex: 00,01..0A,0B..
        float blk = floor(fragCoord.x / 256.0);
        L += sage * hex2(fragCoord, vec2(blk * 256.0 + 5.0, iResolution.y - 22.0), 7.0, blk) * 0.10;
    }

    // ---- lanes ----
    float amp = 0.155;
    float baseC = 0.755, baseM = 0.525, baseN = 0.295, baseG = 0.065;
    vec3 viol = vec3(0.72, 0.42, 0.95);   // GPU beam identity

    // ---- panel chrome: corner brackets around each lane ----
    float mgx = iResolution.x * 0.006;
    for (int i = 0; i < 4; i++) {
        float by = i==0 ? baseC : i==1 ? baseM : i==2 ? baseN : baseG;
        vec3 ink = i==0 ? sage : i==1 ? steel : i==2 ? brass : viol;
        vec2 lo = vec2(mgx, (by - 0.012) * iResolution.y);
        vec2 hi = vec2(iResolution.x - mgx, (by + amp + 0.012) * iResolution.y);
        L += ink * brackets(fragCoord, lo, hi, 18.0, 0.7) * 0.16;
    }

    for (int i = 0; i < 4; i++) {
        float by = i==0 ? baseC : i==1 ? baseM : i==2 ? baseN : baseG;
        vec3 ink = i==0 ? sage : i==1 ? steel : i==2 ? brass : viol;

        // engraved baseline: dark cut + light line (chiseled look)
        float dB = fragCoord.y - by * iResolution.y;
        L += ink * smoothstep(1.0, 0.2, abs(dB)) * 0.09;
        L -= vec3(0.010) * smoothstep(2.2, 0.6, abs(dB + 1.5));

        // right-aligned 100% tick + mid dashes, barely there
        float topY = (by + amp) * iResolution.y;
        L += ink * smoothstep(0.8, 0.2, abs(fragCoord.y - topY))
                 * step(0.982, uv.x) * 0.10;
        float midY = (by + amp * 0.5) * iResolution.y;
        L += ink * smoothstep(0.8, 0.2, abs(fragCoord.y - midY))
                 * step(0.5, fract(uv.x * 90.0)) * 0.016;

        // scale markers on the left: 50 at mid, 100 rendered as 99-tick top
        float sSz = max(iResolution.y * 0.0075, 7.0);
        L += ink * num2(fragCoord, vec2(mgx + 4.0, midY - sSz * 0.5), sSz, 50.0) * 0.10;
        L += ink * num3(fragCoord, vec2(mgx + 4.0, topY - sSz * 0.5), sSz, 100.0) * 0.10;
    }

    // ---- labels + live numeric readouts:  CPU 42 — bright, unmissable ----
    float lblSz = max(iResolution.y * 0.018, 13.0);
    float lx = iResolution.x * 0.010;
    float vC = clamp(sig(1.0 - 1.5 / iResolution.x, 0), 0.0, 1.0);
    float vM = clamp(sig(1.0 - 1.5 / iResolution.x, 1), 0.0, 1.0);
    float vN = clamp(sig(1.0 - 1.5 / iResolution.x, 2), 0.0, 1.0);
    float vG = clamp(sig2(1.0 - 1.5 / iResolution.x, 0), 0.0, 1.0);
    float lyC = (baseC + amp) * iResolution.y - lblSz * 1.3;
    float lyM = (baseM + amp) * iResolution.y - lblSz * 1.3;
    float lyN = (baseN + amp) * iResolution.y - lblSz * 1.3;
    float lyG = (baseG + amp) * iResolution.y - lblSz * 1.3;
    // BOUNDING BOX for the whole label/legend/number cluster: it lives in a
    // left-hand vertical strip. Skip its ~24 glyph samples everywhere else.
    {
      float tbL = lx - lblSz*0.3;
      float tbR = lx + lblSz * 0.72 * 11.5;
      float tbB = lyG - lblSz*0.4;
      float tbT = lyC + lblSz*1.2;
      if (fragCoord.x >= tbL && fragCoord.x <= tbR &&
          fragCoord.y >= tbB && fragCoord.y <= tbT) {
        L += sage  * label3(fragCoord, vec2(lx, lyC), lblSz, 0.0, 1.0, 2.0) * 0.60;
    L += steel * label3(fragCoord, vec2(lx, lyM), lblSz, 3.0, 4.0, 3.0) * 0.60;
    L += brass * label3(fragCoord, vec2(lx, lyN), lblSz, 5.0, 4.0, 6.0) * 0.60;
    L += viol  * label3(fragCoord, vec2(lx, lyG), lblSz, 9.0, 1.0, 2.0) * 0.60;  // GPU
    // NET legend: D (download, amber) / U (upload, steel) after the label
    float lgSz = lblSz * 0.55;
    vec2 lgPos = vec2(lx + lblSz * 0.72 * 8.2, lyN);
    L += brass * letterPx((fragCoord - lgPos) / vec2(lgSz * 0.72, lgSz), 23.0) * 0.50;  // D
    L += steel * letterPx((fragCoord - lgPos - vec2(lgSz * 1.6, 0.0)) / vec2(lgSz * 0.72, lgSz), 2.0) * 0.50; // U
    // MEM legend: R (ram, steel) / S (swap, lilac) after the label
    vec2 lgPosM = vec2(lx + lblSz * 0.72 * 8.2, lyM);
    L += steel * letterPx((fragCoord - lgPosM) / vec2(lgSz * 0.72, lgSz), 7.0) * 0.50;  // R
    L += lilac * letterPx((fragCoord - lgPosM - vec2(lgSz * 1.6, 0.0)) / vec2(lgSz * 0.72, lgSz), 8.0) * 0.50; // S
    // GPU legend: V (vram, violet-dim) + live vram %
    vec2 lgPosG = vec2(lx + lblSz * 0.72 * 8.2, lyG);
    L += viol * 0.7 * letterPx((fragCoord - lgPosG) / vec2(lgSz * 0.72, lgSz), 26.0) * 0.50; // V
    float vVr = clamp(sig2(1.0 - 1.5 / iResolution.x, 1), 0.0, 1.0);
    L += viol * 0.7 * num2(fragCoord, lgPosG + vec2(lgSz * 1.3, 0.0), lgSz, vVr * 100.0) * 0.50;
    // numbers, brighter still — the data is the star
    float nx = lx + lblSz * 0.72 * 4.6;
    L += sage  * num2(fragCoord, vec2(nx, lyC), lblSz, vC * 100.0) * 0.85;
    L += steel * num2(fragCoord, vec2(nx, lyM), lblSz, vM * 100.0) * 0.85;
    L += brass * num2(fragCoord, vec2(nx, lyN), lblSz, vN * 100.0) * 0.85;
    L += viol  * num2(fragCoord, vec2(nx, lyG), lblSz, vG * 100.0) * 0.85;
    // percent unit tag after CPU / GPU numbers (util is a true %)
    float pctSz = lblSz * 0.62;
    vec2 pctOff = vec2(lblSz * 0.72 * 2.35, lblSz * 0.30);
    L += sage * 0.55 * letterPx((fragCoord - vec2(nx, lyC) - pctOff) / vec2(pctSz * 0.72, pctSz), 27.0);
    L += viol * 0.55 * letterPx((fragCoord - vec2(nx, lyG) - pctOff) / vec2(pctSz * 0.72, pctSz), 27.0);
      } // end label cluster bounding box
    }

    // ---- beams ----
    // Each lane only lights pixels inside its own band (+halo). Gating the
    // expensive sig()/traceDist() texture fetches to that band cuts the
    // per-pixel fetch count ~4x on tall displays.
    float bpad = amp * 0.55;   // halo reach above/below the lane
    // beams flash a touch brighter on every audio beat — the panel "breathes"
    float beamGain = 1.0 + iAudioBeat * 0.35;

    // CPU: sage, drifts to signal-red only when genuinely hot
    if (uv.y > baseC - bpad && uv.y < baseC + amp + bpad) {
        vec3 cpuInk = mix(sage, sred, smoothstep(72.0, 90.0, iCpuTempC));
        float yC = baseC + clamp(sig(uv.x, 0), 0.0, 1.0) * amp;
        float sdC = (uv.y - yC) * iResolution.y;                    // signed px offset
        L += beam(traceDist(fragCoord, 0, baseC, amp), sdC, cpuInk) * beamGain;
        // fill: 4% film, fades in — barely a shadow of the curve
        if (uv.y < yC && uv.y > baseC)
            L += cpuInk * 0.035 * pow((uv.y - baseC) / max(yC - baseC, 1e-4), 3.0);
        // peak-hold marker: thin dash at the max of visible history
        float pkC = 0.0;
        for (int i = 0; i < 12; i++) pkC = max(pkC, sig((float(i) + 0.5) / 12.0, 0));
        float pkYC = (baseC + pkC * amp) * iResolution.y;
        L += cpuInk * smoothstep(0.8, 0.2, abs(fragCoord.y - pkYC))
                    * step(0.6, fract(uv.x * 30.0)) * 0.10;
    }

    // MEM: steel-cyan ram solid; swap/vmem = thin lilac ghost underneath
    if (uv.y > baseM - bpad && uv.y < baseM + amp + bpad) {
        vec3 memInk = mix(steel, sred, smoothstep(0.85, 0.97, iRam));
        float yM = baseM + clamp(sig(uv.x, 1), 0.0, 1.0) * amp;
        float sdM = (uv.y - yM) * iResolution.y;
        L += beam(traceDist(fragCoord, 1, baseM, amp), sdM, memInk) * beamGain;
        L += beam(traceDistS(fragCoord, baseM, amp), lilac) * 0.35;
        if (uv.y < yM && uv.y > baseM)
            L += memInk * 0.035 * pow((uv.y - baseM) / max(yM - baseM, 1e-4), 3.0);
    }

    // NET: amber — download solid; upload = thin steel underline ghost
    if (uv.y > baseN - bpad && uv.y < baseN + amp + bpad) {
        float yN = baseN + clamp(sig(uv.x, 2), 0.0, 1.0) * amp;
        float sdN = (uv.y - yN) * iResolution.y;
        L += beam(traceDist(fragCoord, 2, baseN, amp), sdN, brass) * beamGain;
        L += beam(traceDist(fragCoord, 3, baseN, amp), steel) * 0.30;
        if (uv.y < yN && uv.y > baseN)
            L += brass * 0.028 * pow((uv.y - baseN) / max(yN - baseN, 1e-4), 3.0);
    }

    // GPU: violet util solid; VRAM = thin steel ghost underneath.
    //   drifts to signal-red as the die approaches its thermal ceiling
    if (uv.y > baseG - bpad && uv.y < baseG + amp + bpad) {
        vec3 gpuInk = mix(viol, sred, smoothstep(70.0, 84.0, iNvGpuTempC));
        float yG = baseG + clamp(sig2(uv.x, 0), 0.0, 1.0) * amp;
        float sdG = (uv.y - yG) * iResolution.y;
        L += beam(traceDist2(fragCoord, 0, baseG, amp), sdG, gpuInk) * beamGain;
        L += beam(traceDist2(fragCoord, 1, baseG, amp), steel) * 0.30;   // VRAM ghost
        if (uv.y < yG && uv.y > baseG)
            L += gpuInk * 0.035 * pow((uv.y - baseG) / max(yG - baseG, 1e-4), 3.0);
        // GPU peak-hold dash
        float pkG = 0.0;
        for (int i = 0; i < 12; i++) pkG = max(pkG, sig2((float(i) + 0.5) / 12.0, 0));
        float pkYG = (baseG + pkG * amp) * iResolution.y;
        L += gpuInk * smoothstep(0.8, 0.2, abs(fragCoord.y - pkYG))
                   * step(0.6, fract(uv.x * 30.0)) * 0.10;
    }

    // ---- audio spectrogram ghost: faint waterfall in the GPU/NET gap ----
    // frequency left→right, brightness = band energy; only lights up with sound
    if (uv.y > 0.235 && uv.y < 0.275 && iAudioActive > 0.5) {
        float band = spectrum(uv.x * 0.8);
        float rowFade = 1.0 - abs((uv.y - 0.255) / 0.020);
        L += mix(viol, steel, uv.x) * band * band * rowFade * 0.16;
    }

    // ---- LIVE DISASSEMBLY: a scrolling opcode stream inside the CPU lane ----
    //   ADDR OP MNE  — rendered with the crisp bitmap font atlas bound to
    //   iChannel2 ("font" in the manifest). One nwChar call per pixel, so it's
    //   legible AND cheap. New instruction each second, newest row brightest.
    {
        float ds   = max(iResolution.y * 0.016, 13.0);    // glyph cell height (px)
        float cw   = ds * 0.62;                            // monospace advance
        float rowH = ds * 1.35;
        float nRows = 5.0;                                 // live disasm window
        float nCols = 11.0;                                // "AAAA OO MNE"
        // left side, but dropped below the CPU lane label into the open gap
        // above the MEM lane so it never collides with "CPU nn%".
        float rx   = iResolution.x * 0.045;
        float baseRowY = (baseC + amp) * iResolution.y - rowH * 2.6;
        // BOUNDING BOX: the whole block only touches a small rectangle. Skip
        // the 75 glyph samples for every pixel outside it — near-free elsewhere.
        float boxL = rx - cw*0.8, boxR = rx + cw*(nCols+0.5);
        float boxT = baseRowY + ds*1.2, boxB = baseRowY - rowH*(nRows-0.4);
        // dim inset rule on the left
        L += sage * 0.20 * smoothstep(1.8, 0.3, abs(fragCoord.x - (rx - cw*0.6)))
                  * step(baseRowY - rowH*(nRows-0.6), fragCoord.y)
                  * step(fragCoord.y, baseRowY + ds*1.1);

      if (fragCoord.x >= boxL && fragCoord.x <= boxR &&
          fragCoord.y >= boxB && fragCoord.y <= boxT) {
        // live load buckets steer WHICH instruction class scrolls by, so the
        // trace reads like the box's real activity, not random noise:
        //   idle       -> NOP / HLT / PAUSE
        //   cpu busy   -> ALU + branch (ADD SUB XOR CMP JNZ ...)
        //   ram/swap   -> memory moves (MOV PUSH POP LEA)
        //   net active -> port I/O (IN OUT) + syscall
        float busy = clamp(vC, 0.0, 1.0);
        float mem  = clamp(max(iRam, iSwap * 2.0), 0.0, 1.0);
        float net  = clamp(max(iNetDown, iNetUp) * 3.0, 0.0, 1.0);

        // rows: 0 = newest at top, older/dimmer below
        for (int r = 0; r < 5; r++) {
            float y  = baseRowY - float(r) * rowH;
            float ip = floor(t) - float(r);
            float seed = fract(sin(ip*12.9898)*43758.5453);
            float seed2= fract(sin(ip*78.233 + 1.7)*24634.6345);
            // monotonic PC: advance by each instruction's real byte length
            float pc = mod(16384.0 + ip*3.0 + floor(seed*4.0), 65536.0);
            float bri = (r == 0 ? 1.0 : max(0.7 - float(r)*0.14, 0.22));

            // choose an instruction class from the live load mix
            float pick = seed;
            float cls;
            if      (pick < 0.10 + 0.55*(1.0-busy))  cls = 0.0; // idle: NOP/HLT/PAUSE
            else if (pick < 0.42 + 0.30*net)          cls = 3.0; // I/O + syscall
            else if (pick < 0.62 + 0.25*mem)          cls = 2.0; // memory move
            else                                      cls = 1.0; // ALU / branch

            // real single-byte x86 opcode + its correct mnemonic, by class
            float opb; vec3 mc;
            float k = floor(seed2 * 8.0);
            if (cls < 0.5) {
                // idle-ish
                if      (k < 2.5) { opb = 144.0; mc = vec3(78.0,79.0,80.0); } // 90 NOP
                else if (k < 5.0) { opb = 244.0; mc = vec3(72.0,76.0,84.0); } // F4 HLT
                else              { opb = 243.0; mc = vec3(80.0,83.0,69.0); } // F3(90) PSE
            } else if (cls < 1.5) {
                // ALU / branch
                if      (k < 1.0) { opb =  1.0; mc = vec3(65.0,68.0,68.0); } // 01 ADD
                else if (k < 2.0) { opb = 41.0; mc = vec3(83.0,85.0,66.0); } // 29 SUB
                else if (k < 3.0) { opb = 49.0; mc = vec3(88.0,79.0,82.0); } // 31 XOR
                else if (k < 4.0) { opb = 33.0; mc = vec3(65.0,78.0,68.0); } // 21 AND
                else if (k < 5.0) { opb = 57.0; mc = vec3(67.0,77.0,80.0); } // 39 CMP
                else if (k < 6.0) { opb =117.0; mc = vec3(74.0,78.0,90.0); } // 75 JNZ
                else if (k < 7.0) { opb =116.0; mc = vec3(74.0,90.0,32.0); } // 74 JZ
                else              { opb =235.0; mc = vec3(74.0,77.0,80.0); } // EB JMP
            } else if (cls < 2.5) {
                // memory move
                if      (k < 2.0) { opb =137.0; mc = vec3(77.0,79.0,86.0); } // 89 MOV
                else if (k < 4.0) { opb =139.0; mc = vec3(77.0,79.0,86.0); } // 8B MOV
                else if (k < 5.0) { opb =141.0; mc = vec3(76.0,69.0,65.0); } // 8D LEA
                else if (k < 6.5) { opb = 80.0; mc = vec3(80.0,83.0,72.0); } // 50 PUSH->PSH
                else              { opb = 88.0; mc = vec3(80.0,79.0,80.0); } // 58 POP
            } else {
                // port I/O + syscall
                if      (k < 2.0) { opb =236.0; mc = vec3(73.0,78.0,32.0); } // EC IN
                else if (k < 4.0) { opb =238.0; mc = vec3(79.0,85.0,84.0); } // EE OUT
                else if (k < 5.5) { opb =205.0; mc = vec3(73.0,78.0,84.0); } // CD INT
                else if (k < 7.0) { opb =232.0; mc = vec3(67.0,65.0,76.0); } // E8 CALL->CAL
                else              { opb =195.0; mc = vec3(82.0,69.0,84.0); } // C3 RET
            }

            // alarm-red flash when CPU is pinned, on the newest branch ops
            vec3 ink = mix(sage, sred, step(0.90, busy) * step(0.5, seed2) * (r < 1 ? 1.0 : 0.4));

            // 4-hex address
            float a0 = mod(floor(pc/4096.0),16.0), a1 = mod(floor(pc/256.0),16.0);
            float a2 = mod(floor(pc/16.0),16.0),   a3 = mod(pc,16.0);
            L += ink*bri*nwChar(iChannel2, nwHexDigit(a0), fragCoord, vec2(rx,          y), ds);
            L += ink*bri*nwChar(iChannel2, nwHexDigit(a1), fragCoord, vec2(rx+cw*1.0,   y), ds);
            L += ink*bri*nwChar(iChannel2, nwHexDigit(a2), fragCoord, vec2(rx+cw*2.0,   y), ds);
            L += ink*bri*nwChar(iChannel2, nwHexDigit(a3), fragCoord, vec2(rx+cw*3.0,   y), ds);
            // opcode byte (the REAL byte for this mnemonic)
            L += ink*bri*nwChar(iChannel2, nwHexDigit(floor(opb/16.0)), fragCoord, vec2(rx+cw*5.0, y), ds);
            L += ink*bri*nwChar(iChannel2, nwHexDigit(mod(opb,16.0)),   fragCoord, vec2(rx+cw*6.0, y), ds);
            // mnemonic (correct decode of that byte)
            L += ink*bri*nwChar(iChannel2, mc.x, fragCoord, vec2(rx+cw*8.0,  y), ds);
            L += ink*bri*nwChar(iChannel2, mc.y, fragCoord, vec2(rx+cw*9.0,  y), ds);
            L += ink*bri*nwChar(iChannel2, mc.z, fragCoord, vec2(rx+cw*10.0, y), ds);
        }
      } // end ticker bounding box
    }

    // ---- tracking reticle: crosshair locks onto the newest CPU sample ----
    //   thin cross + gap in the middle, like a scope cursor tracking live data
    {
        float ry = (baseC + vC * amp) * iResolution.y;
        float rx = iResolution.x - 14.0;
        vec2 rd = fragCoord - vec2(rx, ry);
        float ring = smoothstep(1.4, 0.4, abs(length(rd) - 6.0));         // circle
        float armH = smoothstep(1.2, 0.3, abs(rd.y)) * step(3.0, abs(rd.x)) * step(abs(rd.x), 10.0);
        float armV = smoothstep(1.2, 0.3, abs(rd.x)) * step(3.0, abs(rd.y)) * step(abs(rd.y), 10.0);
        L += sage * (ring + armH + armV) * 0.45;
    }

    // ---- live value ticks: small bright carets at the right edge ----
    for (int i = 0; i < 4; i++) {
        float by = i==0 ? baseC : i==1 ? baseM : i==2 ? baseN : baseG;
        float v = i==3 ? clamp(sig2(1.0 - 1.5 / iResolution.x, 0), 0.0, 1.0)
                       : clamp(sig(1.0 - 1.5 / iResolution.x, i==2 ? 2 : i), 0.0, 1.0);
        vec3 ink = i==0 ? sage : i==1 ? steel : i==2 ? brass : viol;
        vec2 d = fragCoord - vec2(iResolution.x - 6.0, (by + v * amp) * iResolution.y);
        float caret = smoothstep(4.5, 1.5, abs(d.y) + max(d.x, 0.0) * 2.0) * step(-5.0, d.x);
        L += ink * caret * 0.55;
    }

    // ---- session timer: HH MM engraved bottom-right corner ----
    float sT = iDate.w;
    float tSz = max(iResolution.y * 0.011, 9.0);
    vec2 tPos = vec2(iResolution.x - tSz * 5.2, iResolution.y * 0.018);
    L += sage * num2(fragCoord, tPos, tSz, floor(sT / 3600.0)) * 0.28;
    // blinking separator dot
    L += sage * smoothstep(1.5, 0.5, length(fragCoord - (tPos + vec2(tSz * 1.7, tSz * 0.5))))
              * step(fract(sT), 0.5) * 0.35;
    L += sage * num2(fragCoord, tPos + vec2(tSz * 2.2, 0.0), tSz, floor(mod(sT, 3600.0) / 60.0)) * 0.28;

    // ---- status footer, bottom-left — every value tagged so it reads itself:
    //   UP uptime_h · PS processes · CT cpu°C · GT gpu°C · PW gpu power % ----
    float fSz = max(iResolution.y * 0.009, 8.0);
    float fy = iResolution.y * 0.018;
    float fx = iResolution.x * 0.008;
    vec3 ctInk = mix(sage, sred, smoothstep(72.0, 90.0, iCpuTempC));
    vec3 gtInk = mix(viol, sred, smoothstep(70.0, 84.0, iNvGpuTempC));
    // BOUNDING BOX: single bottom-left row of tags+numbers.
    if (fragCoord.y >= fy - fSz*0.4 && fragCoord.y <= fy + fSz*1.2 &&
        fragCoord.x >= fx - fSz*0.3 && fragCoord.x <= fx + fSz*33.5) {
    L += sage * 0.45 * label2(fragCoord, vec2(fx, fy), fSz, 2.0, 1.0);                       // UP
    L += sage * num3(fragCoord, vec2(fx + fSz * 2.5, fy), fSz, min(iUptimeHours, 999.0)) * 0.26;
    L += sage * 0.45 * label2(fragCoord, vec2(fx + fSz * 7.5, fy), fSz, 1.0, 8.0);           // PS
    L += sage * num3(fragCoord, vec2(fx + fSz * 10.0, fy), fSz, min(float(iProcCount), 999.0)) * 0.26;
    L += ctInk * 0.45 * label2(fragCoord, vec2(fx + fSz * 15.0, fy), fSz, 0.0, 6.0);         // CT
    L += ctInk * num2(fragCoord, vec2(fx + fSz * 17.5, fy), fSz, min(iCpuTempC, 99.0)) * 0.26;
    L += gtInk * 0.45 * label2(fragCoord, vec2(fx + fSz * 21.5, fy), fSz, 9.0, 6.0);         // GT
    L += gtInk * num2(fragCoord, vec2(fx + fSz * 24.0, fy), fSz, min(iNvGpuTempC, 99.0)) * 0.26;
    L += viol * 0.45 * label2(fragCoord, vec2(fx + fSz * 28.0, fy), fSz, 1.0, 31.0);         // PW
    L += viol * num2(fragCoord, vec2(fx + fSz * 30.5, fy), fSz, clamp(iNvPower * 100.0, 0.0, 99.0)) * 0.26;
    } // end footer bounding box

    // ---- STATUS WORD: a live hex flag byte, top-right — the geek centerpiece ----
    //   bit0 CPU>70%   bit1 GPU>70%   bit2 CPUhot   bit3 GPUhot
    //   bit4 SWAP>5%   bit5 NETactive bit6 RAM>85%   bit7 AUDIO
    float flags = 0.0;
    flags += step(0.70, vC)                    * 1.0;
    flags += step(0.70, vG)                    * 2.0;
    flags += step(72.0, iCpuTempC)             * 4.0;
    flags += step(70.0, iNvGpuTempC)           * 8.0;
    flags += step(0.05, iSwap)                 * 16.0;
    flags += step(0.08, max(iNetDown, iNetUp)) * 32.0;
    flags += step(0.85, iRam)                  * 64.0;
    flags += step(0.5,  iAudioActive)          * 128.0;
    float swSz = max(iResolution.y * 0.013, 10.0);
    // colour reddens as more alarm bits latch
    vec3 swInk = mix(sage, sred, clamp(flags / 255.0 * 2.0, 0.0, 1.0));
    vec2 swPos = vec2(iResolution.x - swSz * 9.5, iResolution.y - swSz * 2.6);
    // "SYS" tag
    L += swInk * label3(fragCoord, swPos, swSz, 8.0, 29.0, 8.0) * 0.42;
    // "0x" prefix + two hex nibbles = the live flag byte
    vec2 hxPos = swPos + vec2(swSz * 0.72 * 4.2, 0.0);
    L += swInk * 0.42 * letterPx((fragCoord - hxPos) / vec2(swSz*0.72, swSz), 10.0);          // 0
    L += swInk * 0.42 * letterPx((fragCoord - hxPos - vec2(swSz*0.72*1.1, 0.0)) / vec2(swSz*0.72, swSz), 30.0); // x
    L += swInk * hex2(fragCoord, hxPos + vec2(swSz * 0.72 * 2.3, 0.0), swSz, flags) * 0.90;

    // ---- binary LED row: the same byte as 8 physical bit-cells (MSB left) ----
    // lit cell = condition latched; watch bits flip in real time
    if (fragCoord.x > swPos.x - swSz && fragCoord.y > swPos.y - swSz * 2.0
     && fragCoord.y < swPos.y + swSz) {
        float cellW = swSz * 0.85;
        vec2 ledO = swPos + vec2(0.0, -swSz * 1.15);
        for (int b = 7; b >= 0; b--) {
            float bit = floor(mod(flags / pow(2.0, float(b)), 2.0));
            vec2 c = ledO + vec2(float(7 - b) * cellW + cellW * 0.5, swSz * 0.30);
            vec2 dl = abs(fragCoord - c);
            float cell = step(dl.x, cellW * 0.32) * step(dl.y, swSz * 0.26);
            // frame: dim outline always; core: lit only when bit set
            float frame = cell * (1.0 - step(dl.x, cellW * 0.22) * step(dl.y, swSz * 0.16));
            float core  = step(dl.x, cellW * 0.22) * step(dl.y, swSz * 0.16);
            L += swInk * frame * 0.18;
            L += (bit > 0.5 ? swInk * 0.85 : swInk * 0.05) * core;
        }
    }

    // ---- heartbeat LED: iPulse-driven dot, beats faster as the box works ----
    {
        vec2 hbC = swPos + vec2(-swSz * 2.2, swSz * 0.5);
        float hb = length(fragCoord - hbC);
        float glow = iPulse;
        L += mix(sage, sred, iActivity) * (smoothstep(4.0, 1.0, hb) * (0.15 + glow * 0.75)
                                         + exp(-hb * hb / 40.0) * glow * 0.30);
    }

    // ---- time axis: T-minus ruler along the bottom gap ----
    // history scrolls 1px / 4 frames @60fps = 15 px/s; label real seconds-ago
    float axY = iResolution.y * 0.036;
    if (abs(fragCoord.y - axY) < iResolution.y * 0.014) {
        float axSz = max(iResolution.y * 0.0075, 7.0);
        for (int k = 1; k <= 4; k++) {
            float fx2 = float(k) / 5.0;
            float tickX = fx2 * iResolution.x;
            float secs = (1.0 - fx2) * iResolution.x / 15.0;   // true seconds-ago
            L += sage * smoothstep(1.2, 0.3, abs(fragCoord.x - tickX))
                      * step(abs(fragCoord.y - axY), 4.0) * 0.14;
            // "-NNN" seconds label right of each tick
            L += sage * num3(fragCoord, vec2(tickX + 5.0, axY - axSz * 0.4), axSz, secs) * 0.13;
        }
        // minor dashes every 1/40 width
        float mtick = smoothstep(0.9, 0.2, abs(fract(fragCoord.x / (iResolution.x / 40.0)) - 0.5) * (iResolution.x / 40.0));
        L += sage * mtick * step(abs(fragCoord.y - axY), 1.6) * 0.05;
    }

    // ---- sweep retrace: a drifting color-cycled line every 20s ----
    // like a radar retrace / refresh pass; tinted by the live palette.
    // sweepInk depends only on time — constant across the screen, so the
    // palette call is effectively per-frame, not per-pixel.
    float swX = fract(t / 20.0);
    float dS = abs(uv.x - swX) * iResolution.x;
    vec3 sweepInk = nwPalette(swX * 1.3 + t * 0.03, vec3(0.4, 0.4, 0.4), vec3(0.3, 0.3, 0.3),
                             vec3(1.0, 1.0, 1.0), vec3(0.0, 0.33, 0.60));
    L += sweepInk * exp(-dS * dS / 6.0) * 0.09;
    L += sweepInk * exp(-max(swX - uv.x, 0.0) * 60.0) * 0.022;   // fading tail

    // ---- load glitch: brief horizontal tears when the box is slammed ----
    // only fires when CPU or GPU is genuinely pinned — rare, so it stays a treat.
    float stress = smoothstep(0.82, 0.97, max(iCpu, iNvGpu));
    if (stress > 0.01) {
        // per-scanline random, gated by a fast time hash so tears flicker
        float band = floor(uv.y * 48.0);
        float g = rnd(vec2(band, floor(t * 18.0)));
        float fire = step(0.86, g) * stress;
        // shove this row's sampled luminance sideways a few px — a datamosh streak
        float shove = (rnd(vec2(band, 7.0)) - 0.5) * 0.03 * fire;
        L += vec3(0.9, 0.3, 0.35) * fire * 0.10 * step(0.5, fract(uv.x * 60.0 + shove * 200.0));
        L *= 1.0 - fire * 0.25 * step(0.5, fract(uv.x * 8.0));      // dropout comb
    }

    // ---- finish: subtle scan texture, grade, grain, beat bloom ----
    L *= 0.975 + 0.025 * sin(fragCoord.y * 3.14159);          // faint scan
    vec2 q = (uv - 0.5) * vec2(iResolution.x / iResolution.y, 1.0);
    float vig = 1.0 - 0.34 * dot(q, q);
    L *= vig;
    L += nebInk * (1.0 - vig) * 0.05;                          // cool tint bleeding in at edges
    L *= 1.0 + iAudioBeat * 0.21;                             // beat bloom (single multiply)

    vec3 col = nwGamma(nwTonemap(L));
    // fine grain — makes gradients feel like film, not plastic
    col += (rnd(fragCoord.xy + fract(t)) - 0.5) * (1.8 / 255.0);
    fragColor = vec4(col, 1.0);
}
