////////////////////////////////////////////////////////////////////////////////////////////////
//
//  SoftLightSB.fx v0.11
//  作成: データP
//
////////////////////////////////////////////////////////////////////////////////////////////////

// ポストエフェクト宣言
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

float Tr : CONTROLOBJECT <string name="(self)"; string item="Tr";>;
float2 ViewportSize : VIEWPORTPIXELSIZE;

static const float2 ViewportOffset = float2(0.5,0.5)/ViewportSize;

// 処理用テクスチャ
texture OrgScreen : RENDERCOLORTARGET <
	string Format = "A8R8G8B8";
	float2 ViewPortRatio = {1,1};
>;
sampler OrgSampler = sampler_state {
	texture = <OrgScreen>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV  = CLAMP;
};
texture OrgSizeDepth : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;


/////////////////////////////
// コピー用の汎用頂点シェーダ
struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 Tex: TEXCOORD0;
};

VS_OUTPUT CopyVS(float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){ 
	VS_OUTPUT Out;
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	return Out;
}

/////////////////////////////
// SoftLightPS
float4 SoftLightPS(float2 Tex:TEXCOORD0):COLOR{
	float4 org = tex2D(OrgSampler, Tex);

	float3 dark = pow(org.rgb, 2*(1-org.rgb));
	float3 bright = pow(org.rgb, 1/(2*org.rgb));
	float3 Color = lerp(dark,bright,round(org.rgb));
	return float4(lerp(org,Color,Tr),1);
}

float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1;

technique PostEffectTec <
	string Script =
		"RenderColorTarget=OrgScreen;"
		"RenderDepthStencilTarget=OrgSizeDepth;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		"RenderColorTarget=;"
		"RenderDepthStencilTarget=;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=Effect;"
	;
>{
	pass Effect < string Script = "Draw=Buffer;"; >{
		AlphaBlendEnable = false;
		AlphaTestEnable  = false;
		VertexShader = compile vs_2_0 CopyVS();
		PixelShader  = compile ps_2_0 SoftLightPS();
	}
};
