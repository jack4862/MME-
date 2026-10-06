float4x4 matWorld : WORLD;
float4x4 matView : VIEW;
float4x4 matViewInverse : VIEWINVERSE;
float4x4 matProj : PROJECTION;

#define BUFFER_HEIGHT 1

float uEdgeColorRP : CONTROLOBJECT<string name="(self)"; string item = "EdgeColorR+";>;
float uEdgeColorGP : CONTROLOBJECT<string name="(self)"; string item = "EdgeColorG+";>;
float uEdgeColorBP : CONTROLOBJECT<string name="(self)"; string item = "EdgeColorB+";>;
float uCenterColorRP : CONTROLOBJECT<string name="(self)"; string item = "CenterColorR+";>;
float uCenterColorGP : CONTROLOBJECT<string name="(self)"; string item = "CenterColorG+";>;
float uCenterColorBP : CONTROLOBJECT<string name="(self)"; string item = "CenterColorB+";>;

float uRedP : CONTROLOBJECT<string name="(self)"; string item = "R+";>;
float uGreenP : CONTROLOBJECT<string name="(self)"; string item = "G+";>;
float uBlueP : CONTROLOBJECT<string name="(self)"; string item = "B+";>;
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
float uBrightnessP : CONTROLOBJECT<string name="(self)"; string item = "Brightness+";>;
float uWidthP : CONTROLOBJECT<string name="(self)"; string item = "Width+";>;
float uWidthMM : CONTROLOBJECT<string name="(self)"; string item = "Width--";>;
float uLengthM : CONTROLOBJECT<string name="(self)"; string item = "Length-";>;

static float3 EdgeColor = float3(uEdgeColorRP, uEdgeColorGP, uEdgeColorBP);
static float3 CenterColor = float3(uCenterColorRP, uCenterColorGP, uCenterColorBP);

static float Hue = lerp(lerp(0.5, 1.0, uHueP), 0.0, uHueM);
static float Saturation = lerp(lerp(1.0, 2.0, uSaturationP), 0.0, uSaturationM);
static float Value = lerp(lerp(1.0, 2.0, uValueP), 0.0, uValueM);
static float Gamma = lerp(lerp(1.0, 10.0, uGammaP), 0.01, uGammaM);

float4x4 BoneTransformWS : CONTROLOBJECT < string name = "(self)"; string item = "‘S‚Ä‚Ìe"; >;

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
texture VertexMatBufTex : RenderColorTarget <
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

struct VertexData {
    float4 positionCS;
    float2 texcoord0;
    float3 normalWS;
    float4 color;
    float3 positionVS;
};

VertexData GetVertexData(int vertexID, float2 texcoord0, float maxAlpha) {
    VertexData data = (VertexData)0;

    int gindex = vertexID / 2.0;

    int maxGroupIndex = lerp(VERTEX_PAIR_COUNT - 1, 0, uLengthM);

    float width = lerp(0.1, 1, uWidthP) * (vertexID % 2 - 0.5);
    width *= gindex <= maxGroupIndex ? 1 : 0;
    
    int widthDescreaseBeginIndex = lerp(maxGroupIndex, 0, uWidthMM);
    if (widthDescreaseBeginIndex != maxGroupIndex) {
        float s = 1.0 - (float)max(0, gindex - widthDescreaseBeginIndex) / (float)(maxGroupIndex - widthDescreaseBeginIndex);
        s = smoothstep(0, 1, s);
        width *= s;
    }

    float alpha = maxAlpha - 1e-5;
    alpha *= 1.0 - uAlphaM;
    float endAlpha = lerp(alpha, 0, uAlphaMM);
    if (maxGroupIndex > 0) {
        float s = lerp(alpha, endAlpha, (float)gindex / (float)maxGroupIndex);
        s = smoothstep(0, 1, s);
        alpha *= s;
    }

    float4 positionWS = float4(0,0,0,1);

    if (gindex == 0) {
        positionWS.xyz = BoneTransformWS._41_42_43;
    } else {
        float px = (gindex - 1 + 0.5) / (float)VERTEX_PAIR_COUNT;
        positionWS.xyz = tex2Dlod(VertexMatBufSamp, float4(px, 0.5 / BUFFER_HEIGHT, 0, 0)).xyz;
    }

    float3 velocityWS = 0;
    float x = (gindex + 0.5) / (float)VERTEX_PAIR_COUNT;
    velocityWS = positionWS.xyz - tex2Dlod(VertexMatBufSamp, float4(x, 0.5 / BUFFER_HEIGHT, 0, 0)).xyz;
    velocityWS = normalize(velocityWS);

    float3 velocityVS = mul(velocityWS, (float3x3)matView);
    float2 velocityVSxy = normalize(velocityVS.xy);
    float2 widthDir = float2(-velocityVSxy.y, velocityVSxy.x);
    
    float4 positionVS = mul(positionWS, matView);
    positionVS.xy += widthDir * width;

    data.positionCS = mul(positionVS, matProj);
    data.texcoord0 = texcoord0;
    data.color = float4(1,1,1,alpha);
    data.normalWS = mul(float3(0,0,-1), (float3x3)matViewInverse);
    data.positionVS = positionVS.xyz;

    return data;
}

float4 GetColor(float2 texcoord0, float4 multiplier) {
    float4 color = float4(0,0,0,1);
    float2 uv = texcoord0;

    #ifdef COLOR_TEX_SRC
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

    color.rgb = hue_sat_value(color.rgb, Hue, Saturation, Value);
    color.rgb = pow(color.rgb, Gamma);
    #else
    color.rgb = lerp(CenterColor, EdgeColor, abs(uv.y * 2 - 1));
    #endif
    color *= multiplier;

    return color;
}

float GetBrightness() {
    return lerp(1.0, 10.0, uBrightnessP);
}

void MatVS(in int vertexID: _INDEX, out float4 positionCS: SV_POSITION) {
    int gindex = vertexID / 2.0;

    float x = gindex / (VERTEX_PAIR_COUNT - 1);
    float y = float(vertexID % 2);
    positionCS = float4(x * 2 - 1, y * 2 - 1, 0, 1);
}

float4 MatPS(in float4 positionCS: SV_POSITION): COLOR0 {
    float2 vpos = positionCS.xy;
    if (vpos.x < 0.5) {
        return BoneTransformWS._41_42_43_44;
    } else {
        float2 uv = (floor(vpos - float2(1, 0)) + 0.5) / float2(VERTEX_PAIR_COUNT, BUFFER_HEIGHT);
        return tex2D(VertexMatBufSamp, uv);
    }
}