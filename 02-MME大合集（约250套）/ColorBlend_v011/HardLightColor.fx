////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HardLightColor.fx v0.11
//  作成: データP
//  色設定アイディア PointLight.fx(極北P)
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

float4x4 WorldMatrix : CONTROLOBJECT <string name="(self)";>;
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


// 行列の回転量から色取得
float3 getRotCol(float4x4 rm){
	float4x4 m = rm / length(rm._11_12_13);
	return float3(degrees(-asin(m._32)),degrees(-atan2(-m._31, m._33)),degrees(-atan2(-m._12, m._22)));
}

static const float3 BaseColor = getRotCol(WorldMatrix);

/////////////////////////////
// コピー用のシェーダ
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
float4 HardLightColorPS(float2 Tex: TEXCOORD0) : COLOR {
	float3 org = tex2D(OrgSampler,Tex).rgb;
	float3 bright = 1 - 2*(1-org)*(1-BaseColor);
	float3 dark = 2*org*BaseColor;
	float3 df = lerp(dark,bright,round(BaseColor));
	return float4(lerp(org,df,Tr), 1);
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
		"Pass=HardLightColor;"
	;
>{
	pass HardLightColor < string Script = "Draw=Buffer;"; >{
		AlphaBlendEnable = false;
		AlphaTestEnable  = false;
		VertexShader = compile vs_2_0 CopyVS();
		PixelShader  = compile ps_2_0 HardLightColorPS();
	}
};
