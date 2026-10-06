//=============================================================================

#define Color1	float3(0.9, 0.9, 0.9)
#define Color2	float3(0.2, 0.2, 0.2)

#define ColorOut	float3(1, 0.2, 0.2)

//-----------------------------------------------------------------------------

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0;

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5) / (ViewportSize.xy));
static float2 SampleStep = (float2(1.0,1.0) / (ViewportSize.xy));

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

//-----------------------------------------------------------------------------
//

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float4 TexCoord		: TEXCOORD0;
};

VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy;
	float2 Offset = SampleStep;
	Out.TexCoord = float4(TexCoord, Offset);

	return Out;
}

float4 PS_Final( VS_OUTPUT IN) : COLOR
{
	float2 texCoord = IN.TexCoord.xy * 2.0 - 1.0;
	texCoord.x *= ViewportSize.x / ViewportSize.y;

	float2 check = floor(texCoord.xy * 4 + 32);
	float index = frac((check.x + check.y) * 0.5 + 1e-4);

	float3 result = index < 0.5 ? Color1 : Color2;

	// 画面端?
	float margin = 8;
	float2 texCoord2 = 1.0 - abs(IN.TexCoord.xy * 2.0 - 1.0);
	texCoord2.xy = texCoord2.xy * ViewportSize.xy * 0.5 / margin;
	result *= (texCoord2.x < 1) + (texCoord2.y < 1) ? ColorOut : 1;

	return float4(result, AcsTr);
}

technique CheckerTech <
	string Script = 
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color; Clear=Depth;"
		"ScriptExternal=Color;"

		"Pass=FinalPass;"
	;
> {
	pass FinalPass < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Final();
	}
}

