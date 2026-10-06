#include "../common/hsv.hlsl"
#include "../common/trail.hlsl"

#define SHADINGMODELID_EMISSIVE   2

#define MIDPOINT_8_BIT (127.0f / 255.0f)
#define MAX_FRACTIONAL_8_BIT (255.0f / 256.0f)
#define TWO_BITS_EXTRACTION_FACTOR (3.0f + MAX_FRACTIONAL_8_BIT)
#define EMISSIVE_EPSILON (2.0f / 255.0f)

#define ALPHA_THRESHOLD 0.999

shared texture Gbuffer2RT: RENDERCOLORTARGET;
shared texture Gbuffer3RT: RENDERCOLORTARGET;
shared texture Gbuffer4RT: RENDERCOLORTARGET;
shared texture Gbuffer5RT: RENDERCOLORTARGET;
shared texture Gbuffer6RT: RENDERCOLORTARGET;
shared texture Gbuffer7RT: RENDERCOLORTARGET;
shared texture Gbuffer8RT: RENDERCOLORTARGET;

struct MaterialParam {
	float3 normal;
	float3 albedo;
	float3 specular;
	float3 emissive;
	float smoothness;
	float metalness;
	float emissiveIntensity;
	float alpha;
	float visibility;
	float customDataA;
	float3 customDataB;
	int lightModel;
};

struct GbufferParam {
	float4 buffer1 : COLOR0;
	float4 buffer2 : COLOR1;
	float4 buffer3 : COLOR2;
	float4 buffer4 : COLOR3;
};

float3 EncodeNormal(float3 normal) {
	float p = sqrt(-normal.z * 8 + 8);
	float2 enc = normal.xy / p + 0.5f;
	float2 enc255 = enc * 255;
	float2 residual = floor(frac(enc255) * 16);
	return float3(floor(enc255), residual.x * 16 + residual.y) / 255;
}

GbufferParam EncodeGbuffer(MaterialParam material, float linearDepth) {
	GbufferParam gbuffer;
	gbuffer.buffer1.xyz = material.albedo * (1 - material.metalness);
	gbuffer.buffer1.w = material.smoothness;

	material.normal = mul(material.normal, (float3x3)matView);
	material.normal = normalize(material.normal);

	gbuffer.buffer2.xyz = EncodeNormal(material.normal);
	gbuffer.buffer2.w = material.customDataA;

	gbuffer.buffer3.xyz = lerp(material.specular, max(0.02, material.albedo), material.metalness);
	gbuffer.buffer3.w = 0;

    material.lightModel = SHADINGMODELID_EMISSIVE;

	material.customDataB = material.emissive;
	gbuffer.buffer3 = float4(0, material.customDataB);

	gbuffer.buffer4 = float4(linearDepth, material.emissiveIntensity, material.visibility, material.lightModel);
	gbuffer.buffer4.w += material.alpha * MAX_FRACTIONAL_8_BIT;

	return gbuffer;
}

struct Attributes {
    float2 texcoord0 : TEXCOORD0;
    int vertexID : _INDEX;
};

struct Varyings {
    float4 positionCS : SV_POSITION;
    float2 texcoord0 : TEXCOORD0;
    float3 normalWS: TEXCOORD1;
    float4 color: TEXCOORD2;
    float depth: TEXCOORD3;
};

Varyings MainVS(in Attributes input) {
    Varyings output = (Varyings)0;

    VertexData data = GetVertexData(input.vertexID, input.texcoord0, ALPHA_THRESHOLD);

    output.positionCS = data.positionCS;
    output.texcoord0 = data.texcoord0;
    output.color = data.color;
    output.normalWS = data.normalWS;
    output.depth = data.positionVS.z;

    return output;
}

GbufferParam MainPS(Varyings input) {
    float4 color = GetColor(input.texcoord0, input.color);

    MaterialParam material;
	material.albedo = 0;
	material.normal = normalize(input.normalWS);
	material.smoothness = 0;
	material.metalness = 0;
	material.specular = 0;
	material.customDataA = 0;
	material.customDataB = 0;
	material.emissive = color.rgb;
	material.emissiveIntensity = GetBrightness();
	material.visibility = 1.0;
	material.lightModel = SHADINGMODELID_EMISSIVE;
	material.alpha = 0.0;

    clip(material.alpha - ALPHA_THRESHOLD);

	return EncodeGbuffer(material, input.depth);
}

GbufferParam MainPS2(Varyings input) {
    float4 color = GetColor(input.texcoord0, input.color);

    MaterialParam material;
	material.albedo = 0.01;
	material.normal = normalize(input.normalWS);
	material.smoothness = 0;
	material.metalness = 0;
	material.specular = 0;
	material.customDataA = 0;
	material.customDataB = 0;
	material.emissive = color.rgb;
	material.emissiveIntensity = GetBrightness();
	material.visibility = 1.0;
	material.lightModel = SHADINGMODELID_EMISSIVE;
	material.alpha = color.a;

    clip(material.alpha - 0.01);

	return EncodeGbuffer(material, input.depth);
}

technique MainTec0<
    string MMDPass = "object";
    string Script = 
        "RenderDepthStencilTarget=;"
		"RenderColorTarget0=;"
		"RenderColorTarget1=Gbuffer2RT;"
		"RenderColorTarget2=Gbuffer3RT;"
		"RenderColorTarget3=Gbuffer4RT;"
		"Pass=DrawObject;"
		"RenderColorTarget0=Gbuffer5RT;"
		"RenderColorTarget1=Gbuffer6RT;"
		"RenderColorTarget2=Gbuffer7RT;"
		"RenderColorTarget3=Gbuffer8RT;"
		"Pass=DrawAlphaObject;"

        "RenderColorTarget0=VertexMatBufTex;"
        "RenderColorTarget1=;"
        "RenderColorTarget2=;"
        "RenderColorTarget3=;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "Pass=DrawVertexBuf;"
        ;
> {
    pass DrawObject {
        AlphaTestEnable = FALSE; AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 MainVS();
        PixelShader = compile ps_3_0 MainPS();
    }
    pass DrawAlphaObject {
        AlphaTestEnable = FALSE; AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 MainVS();
        PixelShader = compile ps_3_0 MainPS2();
    }
    pass DrawVertexBuf {
        FillMode = SOLID;
        CullMode = NONE;
        ZEnable = false;
        AlphaTestEnable = FALSE; AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 MatVS();
        PixelShader = compile ps_3_0 MatPS();
    }
}

technique MainTecBS0<
    string MMDPass = "object_ss";
    string Script = 
        "RenderDepthStencilTarget=;"
		"RenderColorTarget0=;"
		"RenderColorTarget1=Gbuffer2RT;"
		"RenderColorTarget2=Gbuffer3RT;"
		"RenderColorTarget3=Gbuffer4RT;"
		"Pass=DrawObject;"
		"RenderColorTarget0=Gbuffer5RT;"
		"RenderColorTarget1=Gbuffer6RT;"
		"RenderColorTarget2=Gbuffer7RT;"
		"RenderColorTarget3=Gbuffer8RT;"
		"Pass=DrawAlphaObject;"

        "RenderColorTarget0=VertexMatBufTex;"
        "RenderColorTarget1=;"
        "RenderColorTarget2=;"
        "RenderColorTarget3=;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "Pass=DrawVertexBuf;"
        ;
> {
    pass DrawObject {
        AlphaTestEnable = FALSE; AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 MainVS();
        PixelShader = compile ps_3_0 MainPS();
    }
    pass DrawAlphaObject {
        AlphaTestEnable = FALSE; AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 MainVS();
        PixelShader = compile ps_3_0 MainPS2();
    }
    pass DrawVertexBuf {
        FillMode = SOLID;
        CullMode = NONE;
        ZEnable = false;
        AlphaTestEnable = FALSE; AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 MatVS();
        PixelShader = compile ps_3_0 MatPS();
    }
}

technique EdgeTec<string MMDPass = "edge";>{}
technique ZplotTec<string MMDPass = "zplot";>{}
technique ShadowTech<string MMDPass = "shadow";>{}