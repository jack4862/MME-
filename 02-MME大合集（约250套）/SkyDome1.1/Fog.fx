////////////////////////////////////////////////////////////////////////////////////////////////
//
//	名前:フォグ
//	種類:ポストエフェクト
//	作成:kion
//	説明:
//		霧
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ操作用オブジェクト
float3 XYZ : CONTROLOBJECT < string name = "(self)"; string item = "XYZ";>;	// 座標
float3 Rxyz : CONTROLOBJECT < string name = "(self)"; string item="Rxyz";>;	// 角度
float Scale : CONTROLOBJECT < string name = "(self)"; string item = "Si";>;	// スケール
//float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr";>;	// 透過度
float3 CameraPosition: POSITION < string Object = "Camera"; >;	// カメラ座標
float3 LightDiffuse		: DIFFUSE	< string Object = "Light"; >;	// 拡散
float3 LightAmbient		: AMBIENT	< string Object = "Light"; >;	// 環境
float3 LightSpecular	: SPECULAR	< string Object = "Light"; >;	// 反射
float SkyDomeScale : CONTROLOBJECT < string name = "SkyDome.x"; >;			// 距離補正
static float RevScale = SkyDomeScale*0.1*0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// フォグの色
static float4 FogColor=float4(Rxyz*0.22353f, 1);

// 単色化する(コメントアウトで無効化)
//#define SINGLE_COLOR

// 昼は明るくする
float Luminance = 1.0;
// 夜は暗くする
float Dark = 0.5;

// フォグの色グラデーション
texture texFogGrad< string ResourceName = "FogGradation.jpg"; >;
sampler smpFogGrad = sampler_state{
	Texture = <texFogGrad>;
	Filter = LINEAR; ADDRESSU = CLAMP; ADDRESSV = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// 射影行列
float4x4 View	: VIEW;
float4x4 InvView	: VIEWINVERSE;
float4x4 InvProj	: PROJECTIONINVERSE;
// ライト方向
float3 LightDirection	: DIRECTION	< string Object = "Light"; >;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

////////////////////////////////////////////////////////////////////////////////////////////////
// レンダリングターゲットのクリア値
float4 ClearColorBlack = {0,0,0,1}, ClearColorWhite = {1,1,1,1};
float ClearDepth  = 1.0;

// レンダーターゲット
// オリジナル
texture2D texOut : RENDERCOLORTARGET
	< float2 ViewportRatio = {1.0, 1.0};	int MipLevels = 1; string Format = "A8R8G8B8"; >;
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET
	< float2 ViewportRatio = {1.0, 1.0};	string Format = "D24S8"; >;
// サンプラー
sampler2D smpOut = sampler_state {
	texture = <texOut>;
	MinFilter = LINEAR; MagFilter=LINEAR; MipFilter = LINEAR;
	AddressU = CLAMP; AddressV = CLAMP;
};
// フォグ濃度
texture texFog: OFFSCREENRENDERTARGET <
	string Description = "FogDensity For Fog.fx";
	float2 ViewportRatio = {1.0, 1.0};
	float4 ClearColor = { 0, 0, 0, 1 };
	float ClearDepth = 1.0;
	string Format = "A8R8G8B8" ;
	bool AntiAlias = true;
	string DefaultEffect = 
		"self = hide;"
		"Sun.x = hide;"
		"Moon.x = hide;"
		"Cloud1.x = hide;"
		"CloudDome.x = hide;"
		"* = FogOffScreen.fx";
>;
// サンプラー
sampler2D smpFog = sampler_state {
    texture = <texFog>;
    MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR;
    AddressU  = CLAMP; AddressV = CLAMP;
};


// ライトに合わせる(コメントアウトで無効化)
#include "GodRay_config.h"
#include "Sun_config.h"
#include "Moon_config.h"
// 月の位置と太陽の位置
#ifdef SYNCLIGHT
float3 MoonXYZ : CONTROLOBJECT < string name = "Moon.x"; string item = "XYZ";>;	// 座標
static float3 MoonPos = -LightDirection * MoonXYZ.z * RevScale;
float3 SunXYZ : CONTROLOBJECT < string name = "Sun.x"; string item = "XYZ";>;	// 座標
static float3 SunPos = -LightDirection * SunXYZ.z * RevScale;
#else
float4x4 MoonMatrix : CONTROLOBJECT < string name = "Moon.x"; >;// 行列
static float3 MoonPos = MoonMatrix._41_42_43*RevScale;
float4x4 SunMatrix : CONTROLOBJECT < string name = "Sun.x"; >;	// 行列
static float3 SunPos = SunMatrix._41_42_43*RevScale;
#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// フォグ
// 頂点出力
struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};
VS_OUTPUT VS_Fog( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    return Out;
}
float4  PS_Fog( VS_OUTPUT In ) : COLOR{   
	float4 Color = tex2D(smpOut,In.Tex);
	// グラデーションのテクスチャ位置
	float tex;
	// 太陽が出ているときは太陽色それ以外は月色
	tex = dot(normalize(SunPos),float3(0,1,0))*0.5+0.5;
	FogColor.rgb *= LightAmbient;
	FogColor *= tex2D(smpFogGrad,saturate(tex));
	if(SunPos.y<0){
		tex = dot(normalize(MoonPos),float3(0,1,0));
		FogColor += tex2D(smpSun,saturate(tex)) * Dark * MoonColor;
	}
	else{
		tex = dot(normalize(SunPos),float3(0,1,0));
		FogColor += tex2D(smpSun,saturate(tex)) * Luminance * SunColor;
	}

#ifdef SINGLE_COLOR
	Color.rgb = FogColor.rgb*tex2D(smpFog, In.Tex).r*Scale*0.1;
#else
	Color.rgb = lerp(Color.rgb, FogColor.rgb*0.5, tex2D(smpFog, In.Tex).r*Scale*0.1);
#endif
	//return float4((float3)tex2D(smpFog, In.Tex).r, 1);
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique FOG<
    string Script = 
		// オリジナル画像出力
		"RenderColorTarget0=texOut; RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColorWhite; ClearSetDepth=ClearDepth; Clear=Color; Clear=Depth;"
			"ScriptExternal=Color;"
		// 画面に出力
		"RenderColorTarget0=; RenderDepthStencilTarget=;"
		"Clear=Color; Clear=Depth;"
			"Pass=Fog;"
    ;
> {
	pass Fog < string Script= "Draw=Buffer;"; >
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_Fog();
		PixelShader  = compile ps_2_0 PS_Fog();
	}
}