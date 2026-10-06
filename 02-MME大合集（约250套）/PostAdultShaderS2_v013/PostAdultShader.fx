////////////////////////////////////////////////////////////////////////////////////////////////
//
//  PostAdultShader.fx v0.13
//  作成: データP
//
////////////////////////////////////////////////////////////////////////////////////////////////

// パラメータ宣言

// 色味の強さ
float EyeLightPower <
	string UIName = "色味の強さ";
	string UIWidget = "Numeric";
	bool UIVisible =  true;
	float UIMin = 0.0;
	float UIMax = 2.0;
	float UIDefault = 1.3;
	float UIStep = 0.1;
> = 2.0;

// 明るさ補正値
float OverBright <
	string UIName = "明るさ補正";
	string UIWidget = "Numeric";
	bool UIVisible =  true;
	float UIMin = 1.0;
	float UIMax = 2.0;
	float UIDefault = 1.2;
	float UIStep = 0.1;
> = 1.2;

// 周辺光の強さ
float FresnelCoef <
	string UIName = "周辺光の強さ";
	string UIWidget = "Numeric";
	bool UIVisible =  true;
	float UIMin = 0.0;
	float UIMax = 2.0;
	float UIDefault = 0.1;
	float UIStep = 0.1;
> = 0.1;

// 周辺光の鋭さ
float FresnelPower <
	string UIName = "周辺光の鋭さ";
	string UIWidget = "Numeric";
	bool UIVisible =  true;
	float UIMin = 1.0;
	float UIMax = 8.0;
	float UIDefault = 5.0;
	float UIStep = 0.1;
> = 5;

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

float4x4 ProjMatrix  : PROJECTION;
float3   LightAmbient: AMBIENT   < string Object = "Light"; >;
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


// 法線マップ
texture ASP_NormalMap : OFFSCREENRENDERTARGET <
	string Description = "NormalMap";
	string Format = "D3DFMT_A8R8G8B8";
	float2 ViewPortRatio = {1,1};
	float4 ClearColor = {0.5,0.5,0,0};
	float ClearDepth = 1.0;
	bool AntiAlias = false;
	int Miplevels = 1;
	string DefaultEffect =
	    "self=hide;"
	    "*=NormalDraw.fx;";
>;
sampler NormalMapSampler = sampler_state {
	texture = <ASP_NormalMap>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
float3 NormalFromPoint(float2 xy){
	float3 n=tex2D(NormalMapSampler, xy);
	return normalize(2*n.xyz-float3(1,1,1));
}

// スペキュラ色マップ
texture ASP_SpecularColorMap : OFFSCREENRENDERTARGET <
	string Description = "SpecularColorMap";
	string Format = "D3DFMT_A8R8G8B8";
	float2 ViewPortRatio = {1,1};
	float4 ClearColor = {0,0,0,0};
	float ClearDepth = 1.0;
	bool AntiAlias = false;
	int Miplevels = 1;
	string DefaultEffect =
	    "self=hide;"
	    "*=SpecularColorDraw.fx;";
>;
sampler SpecularColorMapSampler = sampler_state {
	texture = <ASP_SpecularColorMap>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

/////////////////////////////
// 視線方向ベクトル
float3 EyeVector(float2 Tex){
	float2 xy=Tex*2-1;
	return normalize(float3(xy.x/ProjMatrix._11, -xy.y/ProjMatrix._22, 1));
}

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

//////////////////////////////
// アダルトシェーダPS
float4 AdultShaderPS(float2 Tex: TEXCOORD0) : COLOR {
	float4 org = tex2D(OrgSampler,Tex);
	float3 Color = org.rgb;
	float3 Normal = NormalFromPoint(Tex);
	float3 Eye = EyeVector(Tex);

	float EN = dot(Normal, -Eye);
	float d = pow(EN,EyeLightPower);
	Color *= lerp(Color, OverBright*float3(1,1,1), d);
	Color=saturate(Color);

	d = FresnelCoef*pow(1.0-EN, FresnelPower);
	Color.rgb += tex2D(SpecularColorMapSampler,Tex).rgb*d;

	return lerp(org, float4(Color,org.a),Tr);
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
		PixelShader  = compile ps_2_0 AdultShaderPS();
	}
};
