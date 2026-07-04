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

// instrument beam: crisp tinted-white core, chromatic halo carries identity
vec3 beam(float d, vec3 tint){
    vec3 c = vec3(0.0);
    // hot core: tight, near-white — reads as a sharp scope trace, not a glow
    c += mix(tint, vec3(1.0), 0.72) * smoothstep(0.95, 0.18, d) * 1.45;
    c += tint * exp(-d * d / 14.0) * 0.34;                          // inner halo (tighter)
    c += tint * exp(-d / 40.0) * 0.045;                             // outer breath
    return c;
}

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
float letterPx(vec2 p, float ch){
    if (p.x < 0.0 || p.x >= 1.0 || p.y < 0.0 || p.y >= 1.0) return 0.0;
    return floor(mod(lrow(ch, floor((1.0 - p.y) * 5.0)) / pow(2.0, 2.0 - floor(p.x * 3.0)), 2.0));
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

    // ---- ground: barely-lifted charcoal with a vertical grade ----
    L += vec3(0.012, 0.020, 0.015) * (0.75 + 0.25 * uv.y);

    // ---- whisper grid: 1px hairlines, majors only ----
    vec2 gm = abs(fract(fragCoord.xy / 160.0) - 0.5) * 160.0;
    float major = smoothstep(0.9, 0.2, min(gm.x, gm.y));
    L += sage * major * 0.014;

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

    // ---- beams ----
    // Each lane only lights pixels inside its own band (+halo). Gating the
    // expensive sig()/traceDist() texture fetches to that band cuts the
    // per-pixel fetch count ~4x on tall displays.
    float bpad = amp * 0.55;   // halo reach above/below the lane

    // CPU: sage, drifts to signal-red only when genuinely hot
    if (uv.y > baseC - bpad && uv.y < baseC + amp + bpad) {
        vec3 cpuInk = mix(sage, sred, smoothstep(72.0, 90.0, iCpuTempC));
        L += beam(traceDist(fragCoord, 0, baseC, amp), cpuInk);
        // fill: 4% film, fades in — barely a shadow of the curve
        float yC = baseC + clamp(sig(uv.x, 0), 0.0, 1.0) * amp;
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
        L += beam(traceDist(fragCoord, 1, baseM, amp), memInk);
        L += beam(traceDistS(fragCoord, baseM, amp), lilac) * 0.35;
        float yM = baseM + clamp(sig(uv.x, 1), 0.0, 1.0) * amp;
        if (uv.y < yM && uv.y > baseM)
            L += memInk * 0.035 * pow((uv.y - baseM) / max(yM - baseM, 1e-4), 3.0);
    }

    // NET: amber — download solid; upload = thin steel underline ghost
    if (uv.y > baseN - bpad && uv.y < baseN + amp + bpad) {
        L += beam(traceDist(fragCoord, 2, baseN, amp), brass);
        L += beam(traceDist(fragCoord, 3, baseN, amp), steel) * 0.30;
        float yN = baseN + clamp(sig(uv.x, 2), 0.0, 1.0) * amp;
        if (uv.y < yN && uv.y > baseN)
            L += brass * 0.028 * pow((uv.y - baseN) / max(yN - baseN, 1e-4), 3.0);
    }

    // GPU: violet util solid; VRAM = thin steel ghost underneath.
    //   drifts to signal-red as the die approaches its thermal ceiling
    if (uv.y > baseG - bpad && uv.y < baseG + amp + bpad) {
        vec3 gpuInk = mix(viol, sred, smoothstep(70.0, 84.0, iNvGpuTempC));
        L += beam(traceDist2(fragCoord, 0, baseG, amp), gpuInk);
        L += beam(traceDist2(fragCoord, 1, baseG, amp), steel) * 0.30;   // VRAM ghost
        float yG = baseG + clamp(sig2(uv.x, 0), 0.0, 1.0) * amp;
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

    // ---- sweep retrace: a dim vertical line drifts across every 20s ----
    // like a radar retrace / refresh pass; barely visible, pure geek texture
    float swX = fract(t / 20.0);
    float dS = abs(uv.x - swX) * iResolution.x;
    L += sage * exp(-dS * dS / 6.0) * 0.05;
    L += sage * exp(-max(swX - uv.x, 0.0) * 60.0) * 0.012;   // fading tail

    // ---- finish: subtle scan texture, grade, grain ----
    L *= 0.975 + 0.025 * sin(fragCoord.y * 3.14159);          // faint scan
    vec2 q = (uv - 0.5) * vec2(iResolution.x / iResolution.y, 1.0);
    L *= 1.0 - 0.30 * dot(q, q);                              // soft vignette
    L *= 1.0 + iAudioBeat * 0.05;                             // whisper of beat

    vec3 col = nwGamma(nwTonemap(L));
    // fine grain — makes gradients feel like film, not plastic
    col += (rnd(fragCoord.xy + fract(t)) - 0.5) * (1.8 / 255.0);
    fragColor = vec4(col, 1.0);
}
