// PHOSPHOR OPS v4 — legible mission control.
// Big 7-segment clock, labeled live readouts you can actually read:
//   C 42  = CPU %      t 49 = CPU temp °C      r 63 = RAM %
// Readouts turn amber/red when hot/full. Bottom: live audio EQ.
// Uses neowall reactive uniforms + stdlib sdSegment.

float rnd(vec2 co){ return fract(sin(dot(co, vec2(12.9898,78.233)))*43758.5453); }

// ---- 7-segment display -------------------------------------------------
// segment bits: a=1 b=2 c=4 d=8 e=16 f=32 g=64
float segOn(float pat, float bit){ return mod(floor(pat / pow(2.0, bit)), 2.0); }

float digPat(float d){
    if (d < 0.5) return 63.0;   // 0
    if (d < 1.5) return 6.0;    // 1
    if (d < 2.5) return 91.0;   // 2
    if (d < 3.5) return 79.0;   // 3
    if (d < 4.5) return 102.0;  // 4
    if (d < 5.5) return 109.0;  // 5
    if (d < 6.5) return 125.0;  // 6
    if (d < 7.5) return 7.0;    // 7
    if (d < 8.5) return 127.0;  // 8
    return 111.0;               // 9
}

float segGlow(vec2 p, vec2 a, vec2 b){
    float d = sdSegment(p, a, b);
    return smoothstep(0.055, 0.025, d) + 0.3 * smoothstep(0.16, 0.0, d);
}

// one character in local cell coords: x 0..0.7, y 0..1
float glyphChar(vec2 p, float pat){
    p.x += (p.y - 0.5) * 0.07;                    // slight italic slant
    float m = 0.0;
    m += segOn(pat, 0.0) * segGlow(p, vec2(0.10, 1.00), vec2(0.60, 1.00)); // a
    m += segOn(pat, 1.0) * segGlow(p, vec2(0.65, 0.95), vec2(0.65, 0.55)); // b
    m += segOn(pat, 2.0) * segGlow(p, vec2(0.65, 0.45), vec2(0.65, 0.05)); // c
    m += segOn(pat, 3.0) * segGlow(p, vec2(0.10, 0.00), vec2(0.60, 0.00)); // d
    m += segOn(pat, 4.0) * segGlow(p, vec2(0.05, 0.45), vec2(0.05, 0.05)); // e
    m += segOn(pat, 5.0) * segGlow(p, vec2(0.05, 0.95), vec2(0.05, 0.55)); // f
    m += segOn(pat, 6.0) * segGlow(p, vec2(0.10, 0.50), vec2(0.60, 0.50)); // g
    return m;
}

// two-digit number at pos, char height s. val clamped 0..99
float num2(vec2 q, vec2 pos, float s, float val){
    val = clamp(floor(val + 0.5), 0.0, 99.0);
    float tens = floor(val / 10.0);
    float ones = mod(val, 10.0);
    float m = 0.0;
    m += glyphChar((q - pos) / s, digPat(tens));
    m += glyphChar((q - pos - vec2(0.85 * s, 0.0)) / s, digPat(ones));
    return m;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 asp = vec2(iResolution.x / iResolution.y, 1.0);
    vec2 q = (uv - 0.5) * asp;                    // aspect-true, origin center
    float t = iTime;

    vec3 green = vec3(0.0, 1.0, 0.255);
    vec3 cyan  = vec3(0.0, 0.898, 1.0);
    vec3 amber = vec3(1.0, 0.69, 0.0);
    vec3 red   = vec3(1.0, 0.17, 0.29);

    // ---- base void + faint blueprint grid (pulses with music) ----
    vec3 col = vec3(0.002, 0.005, 0.003);
    vec2 g1 = abs(fract(fragCoord.xy / 48.0) - 0.5);
    vec2 g4 = abs(fract(fragCoord.xy / 192.0) - 0.5);
    float grid = smoothstep(0.48, 0.5, max(g1.x, g1.y)) * 0.010
               + smoothstep(0.485, 0.5, max(g4.x, g4.y)) * 0.016;
    col += green * grid * (1.0 + iAudioBeat * 1.2);

    // ---- BIG CLOCK  HH:MM  ----
    float secs = iDate.w;
    float hh = floor(secs / 3600.0);
    float mm = floor(mod(secs, 3600.0) / 60.0);
    float s  = 0.16;                              // char height
    vec2 c0 = vec2(-1.85 * s, 0.02);              // left edge of clock
    float clk = 0.0;
    clk += num2(q, c0, s, hh);
    clk += num2(q, c0 + vec2(2.05 * s, 0.0), s, mm);
    // colon, blinks each second
    float blink = step(fract(secs), 0.5);
    vec2 cp = q - (c0 + vec2(1.78 * s, 0.0));
    clk += blink * (smoothstep(0.018, 0.008, length(cp - vec2(0.0, 0.30 * s)))
                  + smoothstep(0.018, 0.008, length(cp - vec2(0.0, 0.62 * s))));
    col += green * clk * 0.55;

    // seconds, small, right of the clock
    float ss = floor(mod(secs, 60.0));
    col += green * num2(q, c0 + vec2(3.95 * s, 0.0), s * 0.45, ss) * 0.35;

    // ---- READOUTS under clock:  C nn   t nn   r nn ----
    float rs = 0.055;                              // readout char height
    float ry = -0.22;
    // labels via 7seg letter patterns: C=57  t=120  r=80
    float cpuV = iCpu * 100.0;
    float tmpV = iCpuTempC;
    float ramV = iRam * 100.0;

    // CPU block (label + number), turns red when slammed
    vec3 inkC = mix(green, red, smoothstep(0.75, 0.95, iCpu));
    col += inkC * glyphChar((q - vec2(-0.50, ry)) / rs, 57.0) * 0.4;
    col += inkC * num2(q, vec2(-0.50 + 1.1 * rs, ry), rs, cpuV) * 0.4;

    // temp block, green→amber→red over 60→90°C
    vec3 inkT = mix(green, mix(amber, red, smoothstep(78.0, 90.0, tmpV)),
                    smoothstep(60.0, 80.0, tmpV));
    col += inkT * glyphChar((q - vec2(-0.11, ry)) / rs, 120.0) * 0.4;
    col += inkT * num2(q, vec2(-0.11 + 1.1 * rs, ry), rs, tmpV) * 0.4;

    // RAM block, amber past 80%
    vec3 inkR = mix(green, amber, smoothstep(0.8, 0.95, iRam));
    col += inkR * glyphChar((q - vec2(0.28, ry)) / rs, 80.0) * 0.4;
    col += inkR * num2(q, vec2(0.28 + 1.1 * rs, ry), rs, ramV) * 0.4;

    // ---- bottom: live audio equalizer, mirrored from center ----
    if (uv.y < 0.055) {
        float x = abs(uv.x - 0.5) * 2.0;
        float sp = spectrum(x * 0.7);
        float bar = step(uv.y / 0.055, sp * (0.35 + 0.65 * iAudioLevel));
        float colq = step(0.18, fract(uv.x * 96.0));
        col += mix(green, cyan, x) * bar * colq * 0.13;
    }

    // ---- CRT dressing ----
    col *= 0.97 + 0.03 * sin(fragCoord.y * 3.14159);
    col *= 1.0 - 0.40 * dot(q, q);
    col *= 0.995 + 0.005 * rnd(vec2(floor(t * 60.0), 1.0));

    fragColor = vec4(col, 1.0);
}
