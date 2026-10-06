#include "../common/hsv.hlsl"
#include "../common/party.hlsl"

struct Attributes {
    float2 texcoord0 : TEXCOORD0;
    int vertexID : _INDEX;
};

struct Varyings {
    float4 positionCS : SV_POSITION;
};

Varyings MainVS(in Attributes input) {
    Varyings output = (Varyings)0;
	
    VertexData data = GetVertexData(input.vertexID, 0, 1);
    output.positionCS = data.positionCS;

    return output;
}

float4 MainPS(Varyings input) : COLOR {
	return float4(0.1, 0.05, 0.0, 0.0);
}

void EdgeLineVS(out float4 positionCS: SV_POSITION)
{
	positionCS = 0;
}

float4 EdgeLinePS() : COLOR
{
	return float4(0.1, 0.05, 0.0, 1.0);
}

technique EdgeTec<string MMDPass = "edge";>{
	pass DrawEdgeLine {
		AlphaTestEnable = false; AlphaBlendEnable = false;
		VertexShader = compile vs_3_0 EdgeLineVS();
		PixelShader  = compile ps_3_0 EdgeLinePS();
	}
}

technique MainTecBS0<
    string MMDPass = "object_ss";
    string Script = 
        "RenderDepthStencilTarget=;"
		"RenderColorTarget0=;"
		"Pass=DrawObject;"

        "RenderColorTarget=VertexMatBufTex;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "Pass=DrawVertexBuf;"
        ;
> {
    pass DrawObject {
		AlphaTestEnable = false; AlphaBlendEnable = false;
		DepthBias = 0;
		SlopeScaleDepthBias = 1;
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

technique MainTec0<string MMDPass = "object";>{}
technique ZplotTec<string MMDPass = "zplot";>{}
technique ShadowTech<string MMDPass = "shadow";>{}