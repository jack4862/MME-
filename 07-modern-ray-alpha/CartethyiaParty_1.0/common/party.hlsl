float4x4 matWorld : WORLD;
float4x4 matView : VIEW;
float4x4 matViewInverse : VIEWINVERSE;
float4x4 matProj : PROJECTION;

#define BUFFER_HEIGHT 2

float uEdgeColorRP : CONTROLOBJECT<string name="(self)"; string item = "EdgeColorR+";>;
float uEdgeColorGP : CONTROLOBJECT<string name="(self)"; string item = "EdgeColorG+";>;
float uEdgeColorBP : CONTROLOBJECT<string name="(self)"; string item = "EdgeColorB+";>;
float uEdgeHueNoiseP : CONTROLOBJECT<string name="(self)"; string item = "EdgeHueNoise+";>;
float uCenterColorRP : CONTROLOBJECT<string name="(self)"; string item = "CenterColorR+";>;
float uCenterColorGP : CONTROLOBJECT<string name="(self)"; string item = "CenterColorG+";>;
float uCenterColorBP : CONTROLOBJECT<string name="(self)"; string item = "CenterColorB+";>;
float uCenterHueNoiseP : CONTROLOBJECT<string name="(self)"; string item = "CenterHueNoise+";>;

float uRedP : CONTROLOBJECT<string name="(self)"; string item = "R+";>;
float uGreenP : CONTROLOBJECT<string name="(self)"; string item = "G+";>;
float uBlueP : CONTROLOBJECT<string name="(self)"; string item = "B+";>;
float uHueNoiseP : CONTROLOBJECT<string name="(self)"; string item = "HueNoise+";>;
float uHueP : CONTROLOBJECT<string name="(self)"; string item = "Hue+";>;
float uHueM : CONTROLOBJECT<string name="(self)"; string item = "Hue-";>;
float uSaturationP : CONTROLOBJECT<string name="(self)"; string item = "Saturation+";>;
float uSaturationM : CONTROLOBJECT<string name="(self)"; string item = "Saturation-";>;
float uValueP : CONTROLOBJECT<string name="(self)"; string item = "Value+";>;
float uValueM : CONTROLOBJECT<string name="(self)"; string item = "Value-";>;
float uGammaP : CONTROLOBJECT<string name="(self)"; string item = "Gamma+";>;
float uGammaM : CONTROLOBJECT<string name="(self)"; string item = "Gamma-";>;

float uAlphaM : CONTROLOBJECT<string name="(self)"; string item = "Alpha-";>;
float uAlphaMM : CONTROLOBJECT<string name="(self)"; string item = "Alpha--";>;
float uShapeP : CONTROLOBJECT<string name="(self)"; string item = "Shape";>;
float uBrightnessP : CONTROLOBJECT<string name="(self)"; string item = "Brightness+";>;
float uCountM : CONTROLOBJECT<string name="(self)"; string item = "Count-";>;
float uLifeTimeP : CONTROLOBJECT<string name="(self)"; string item = "LifeTime+";>;
float uLifeTimeM : CONTROLOBJECT<string name="(self)"; string item = "LifeTime-";>;
float uSizeP : CONTROLOBJECT<string name="(self)"; string item = "Size+";>;
float uHollowP : CONTROLOBJECT<string name="(self)"; string item = "Hollow+";>;
float uPosNoiseP : CONTROLOBJECT<string name="(self)"; string item = "PosNoise+";>;
float uRotateP : CONTROLOBJECT<string name="(self)"; string item = "Rotate+";>;
float uRotateNoiseP : CONTROLOBJECT<string name="(self)"; string item = "RotateNoise+";>;

float uRestart : CONTROLOBJECT<string name="(self)"; string item = "Restart";>;

static float3 EdgeColor = float3(uEdgeColorRP, uEdgeColorGP, uEdgeColorBP);
static float3 CenterColor = float3(uCenterColorRP, uCenterColorGP, uCenterColorBP);

static float Hue = lerp(lerp(0.5, 1.0, uHueP), 0.0, uHueM);
static float Saturation = lerp(lerp(1.0, 2.0, uSaturationP), 0.0, uSaturationM);
static float Value = lerp(lerp(1.0, 2.0, uValueP), 0.0, uValueM);
static float Gamma = lerp(lerp(1.0, 10.0, uGammaP), 0.01, uGammaM);

static float LifeTime = lerp(lerp(0.8, 0.9, uLifeTimeP), 0.0, uLifeTimeM);

float4x4 BoneTransformWS : CONTROLOBJECT < string name = "(self)"; string item = "‘S‚Ä‚Ìe"; >;

float time : TIME;

#ifdef COLOR_TEX_SRC
texture ColorTex<string ResourceName = COLOR_TEX_SRC;>;

sampler ColorTexSamp = sampler_state
{
    texture = ColorTex;
    MAXANISOTROPY = 16;
    MINFILTER = ANISOTROPIC; MAGFILTER = ANISOTROPIC; MIPFILTER = ANISOTROPIC;
    ADDRESSU = CLAMP; ADDRESSV = CLAMP;
};
#endif

texture DepthBuffer : RenderDepthStencilTarget <
   int Width = VERTEX_PAIR_COUNT;
   int Height = BUFFER_HEIGHT;
    string Format = "D24S8";
>;
texture VertexMatBufTex : RenderColorTarget
<
    int Width = VERTEX_PAIR_COUNT;
    int Height = BUFFER_HEIGHT;
    bool AntiAlias = false;
    int Miplevels = 1;
    string Format="A32B32G32R32F";
>;
sampler VertexMatBufSamp = sampler_state
{
   Texture = (VertexMatBufTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

float2 RotateVector(float2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float2(c * v.x - s * v.y, s * v.x + c * v.y);
}

struct VertexData {
    float4 positionCS;
    float2 texcoord0;
    float3 normalWS;
    float4 noise;
    float3 positionVS;
};

VertexData GetVertexData(int vertexID, float2 texcoord0, float maxAlpha) {
    VertexData data = (VertexData)0;

    int gindex = vertexID / 4;
    int index = vertexID % 4;

    int maxGroupIndex = lerp(VERTEX_PAIR_COUNT, 0, uCountM);
    bool show = ((gindex * 7) % VERTEX_PAIR_COUNT) < maxGroupIndex;

    float x = (gindex + 0.5) / (float)VERTEX_PAIR_COUNT;
    float y = 0.5 / BUFFER_HEIGHT;
    float4 p = tex2Dlod(VertexMatBufSamp, float4(x, y, 0, 0));
    float size = p.a;
    size *= lerp(0.1, 1, uSizeP);
    size *= show ? 1 : 0;

    y = 1.5 / BUFFER_HEIGHT;
    float4 noise = tex2Dlod(VertexMatBufSamp, float4(x, y, 0, 0));
    float angle = 2 * 3.1415926535 * uRotateP;
    angle += noise.r * uRotateNoiseP;
    
    float4 positionWS = float4(p.xyz, 1);
    float4 positionVS = mul(positionWS, matView);

    float dx = index % 2 ? 1 : -1;
    float dy = index < 2 ? -1 : 1;
    float2 dir = float2(dx, dy) * size;
    dir = RotateVector(dir, angle);
    positionVS.xy += dir;

    data.positionCS = mul(positionVS, matProj);
    data.texcoord0 = texcoord0;
    data.noise = noise;
    data.normalWS = mul(float3(0,0,-1), (float3x3)matViewInverse);
    data.positionVS = positionVS.xyz;

    return data;
}

float4 GetColor(float2 texcoord0, float4 noise) {
    float2 uv = texcoord0;
    float2 coord = float2(uv.x, 1.0 - uv.y) * 2 - 1;
    float4 color = float4(1,1,1,1);

    float radius2 = dot(coord, coord);
    float radius = sqrt(radius2);

    #ifdef COLOR_TEX_SRC
    {
        color = tex2D(ColorTexSamp, uv);
        color.rgb = pow(color.rgb, 2.2);

        float maxColorP = max(max(uRedP, uGreenP), uBlueP);
        float minColorP = min(min(uRedP, uGreenP), uBlueP);
        float minmaxColorDiff = maxColorP - minColorP;
        if (minmaxColorDiff > 1e-5) {
            float3 colorRatio = (float3(uRedP, uGreenP, uBlueP) - minColorP) / minmaxColorDiff;
            float3 colorTint = colorRatio * minmaxColorDiff + 1.0 - minmaxColorDiff;
            color.rgb *= colorTint;
        }
        float hue = frac(Hue + uHueNoiseP * noise.g * 0.5);
        color.rgb = hue_sat_value(color.rgb, hue, Saturation, Value);
        color.rgb = pow(color.rgb, Gamma);
    }
    #elif MAX_POLY_SIDE_COUNT
    {
        float pi2 = 3.1415926535 * 2;
        int n = lerp(3, max(MAX_POLY_SIDE_COUNT, 3), uShapeP);
        float theta = atan2(coord.x, coord.y);
        if (theta < 0) theta += pi2;
        float delta = pi2 / (float)n;
        theta = fmod(theta, delta);

        float len = length(coord);
        float2 rcoord = RotateVector(float2(0, len), -theta);

        float2 v1 = float2(0, 1);
        float2 v2 = float2(sin(delta), cos(delta));

        float2 v = rcoord - v1;
        float3 co = cross(float3(v, 0), float3(v2 - v1, 0)); 
        clip(co.z > 0 ? 1 : -1);

        v1 = v1 * uHollowP;
        v2 = v2 * uHollowP;

        v = rcoord - v1;
        co = cross(float3(v, 0), float3(v2 - v1, 0));
        clip(co.z <= 0 ? 1 : -1);

        float2 vl = RotateVector(float2(0, 1), -delta * 0.5);
        float pl = dot(rcoord, vl);

        float h = cos(0.5 * delta);
        float hh = h * uHollowP;
        float s = (pl - hh) / (h - hh);
        s = smoothstep(0, 1, s);

        float3 c = CenterColor;
        c = hue_sat_value(c, 0.5 + uCenterHueNoiseP * noise.g * 0.5, 1, 1);
        float3 e = EdgeColor;
        e = hue_sat_value(e, 0.5 + uEdgeHueNoiseP * noise.g * 0.5, 1, 1);

        color.rgb = lerp(c, e, smoothstep(0, 1, s));
    }
    #else
    {
        clip(radius2 > 1 ? -1 : 1);
        float hollow2 = uHollowP * uHollowP;
        clip(radius2 < hollow2 ? -1 : 1);

        float s = (radius - uHollowP) / (1.0 - uHollowP);
        float3 c = CenterColor;
        c = hue_sat_value(c, 0.5 + uCenterHueNoiseP * noise.g * 0.5, 1, 1);
        float3 e = EdgeColor;
        e = hue_sat_value(e, 0.5 + uEdgeHueNoiseP * noise.g * 0.5, 1, 1);
        color.rgb = lerp(c, e, smoothstep(0, 1, s));
    }
    #endif

    color.a *= 1.0 - uAlphaM;
    float endAlpha = 1.0 - uAlphaMM;
    {
        float s = lerp(1.0, endAlpha, radius);
        s = smoothstep(0, 1, s);
        color.a *= s;
    }
    return color;
}

float GetBrightness() {
    return lerp(1.0, 10.0, uBrightnessP);
}

void MatVS(in int vertexID: _INDEX, out float4 positionCS: SV_POSITION) {
    int gindex = vertexID / 4;
    int index = vertexID % 4;

    float x = index % 2 ? 0 : 1;
    float y = index < 2 ? 1 : 0;

    x += gindex;
    x /= (float)VERTEX_PAIR_COUNT;

    positionCS = float4(x * 2 - 1, y * 2 - 1,0,1);
}

float4 MatPS(in float4 positionCS: SV_POSITION): COLOR0 {
    float2 vpos = positionCS.xy;
    float2 uv = (vpos + 0.5) / float2(VERTEX_PAIR_COUNT, BUFFER_HEIGHT);
    float4 p = tex2D(VertexMatBufSamp, float2(uv.x, 0.5 / BUFFER_HEIGHT));
    if (dot(1, p) == 0 || uRestart >= 0.5) {
        if (uv.y < 0.5) {
            float size = 1.0 - vpos.x / (float)VERTEX_PAIR_COUNT;
            return float4(BoneTransformWS._41_42_43, size);
        } else {
            float4 h = time * float4(1.0,1.1,1.2,1.3);
            float4 noise = frac(sin(h) * float4(66666.6666, 44444.4444, 88888.8888, 11111.1111));
            return noise * 2 - 1;
        }
    } else {
        float size = p.a;
        size -= (1.0 - LifeTime) * 0.1;
        if (size <= 0) {
            if (uv.y < 0.5) {
                float3 h = time * float3(1, 1.1, 1.2);
                float3 noise = frac(sin(h) * float3(43758.5453, 22578.1456, 19642.3497));
                noise = noise * 2 - 1;
                noise *= lerp(0.0, 1, uPosNoiseP);
                return float4(BoneTransformWS._41_42_43 + noise, 1);
            } else {
                float4 h = time * float4(1.0,1.1,1.2,1.3);
                float4 noise = frac(sin(h) * float4(66666.6666, 44444.4444, 88888.8888, 11111.1111));
                return noise * 2 - 1;
            }
        } else {
            if (uv.y < 0.5) {
                return float4(p.xyz, size);
            } else {
                return tex2D(VertexMatBufSamp, uv.xy);
            }
        }
    }
}