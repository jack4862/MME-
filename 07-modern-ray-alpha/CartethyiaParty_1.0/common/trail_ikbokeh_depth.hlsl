#include "../common/trail.hlsl"

struct Attributes {
    float2 texcoord0 : TEXCOORD0;
    int vertexID : _INDEX;
};

struct Varyings {
    float4 positionCS : SV_POSITION;
    float2 texcoord0 : TEXCOORD0;
    float3 positionVS : TEXCOORD1;
    float4 color: TEXCOORD2;
};

Varyings MainVS(in Attributes input) {
    Varyings output = (Varyings)0;

    VertexData data = GetVertexData(input.vertexID, input.texcoord0, 1.0);

    output.positionCS = data.positionCS;
    output.texcoord0 = data.texcoord0;
    output.positionVS = data.positionVS;
    output.color = data.color;

    return output;
}

float4 MainPS(Varyings input) : COLOR {
    float4 color = GetColor(input.texcoord0, input.color);
    float alpha = color.a;

    clip(alpha - AlphaThroughThreshold);

    float distance = length(input.positionVS.xyz);

	return float4(distance / FAR_DEPTH, 0, 0, 1);
}

technique MainTec0<
    string MMDPass = "object";
    string Script = 
        "RenderColorTarget=;"
        "RenderDepthStencilTarget=;"
        "Pass=DrawObject;"

        "RenderColorTarget=VertexMatBufTex;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "Pass=DrawVertexBuf;"
        ;
> {
    pass DrawObject {
        AlphaTestEnable = FALSE; AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 MainVS();
        PixelShader = compile ps_3_0 MainPS();
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
        "RenderColorTarget=;"
        "RenderDepthStencilTarget=;"
        "Pass=DrawObject;"

        "RenderColorTarget=VertexMatBufTex;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "Pass=DrawVertexBuf;"
        ;
> {
    pass DrawObject {
        AlphaTestEnable = FALSE; AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 MainVS();
        PixelShader = compile ps_3_0 MainPS();
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