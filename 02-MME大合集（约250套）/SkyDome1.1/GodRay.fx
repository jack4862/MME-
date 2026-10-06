////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:木漏れ日
//	作成;kion
//	種類:ポストエフェクト
//	説明:
//		木漏れ日のポストエフェクト
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// コントロールオブジェクト //
float Scale : CONTROLOBJECT < string name = "(self)"; string item = "Si";>;	// スケール
float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr";>;	// 透過度
float SkyDomeScale : CONTROLOBJECT < string name = "SkyDome.x"; >;			// 距離補正
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ //
// ライトに合わせる(コメントアウトで無効化)
#include "GodRay_config.h"
static float RevScale = SkyDomeScale*0.1*SunRevDistanceScale;

// 光筋
// サンプリング数（増やすと滑らかになる）
#define RBLUR_NUM	8
// 光筋のパス回数(1～3)
// 大きいと光筋の長さが伸びるが、パス回数が増えるので重くなる
#define RBLUR_SMPNUM	3

// ブルーム
// ブルームの広がり
static float BloomPower = 1.0;
// ブルーム用バッファのフォーマット
#define HDR_BUFFER_FORMAT	"A8R8G8B8" //"A16B16G16R16F"

// 昼の光筋の強さ
float Bright = 1.0;
// 夜の光筋の強さ
float Dark = 0.25;


////////////////////////////////////////////////////////////////////////////////////////////////
// 詳細な設定
// 光筋の長さ(ブラー強度)
static float RadialBlurPower = Scale*0.1;

// フレーム(太陽の大きいブルームの代わり)
// フレーム範囲(-1.0～1.0)
float FrameLimit = -0.1;
// フレームのシャープ具合(0.0～40.0)
static float FrameSharpness = 1;

#include "Sun_config.h"
#include "Moon_config.h"

////////////////////////////////////////////////////////////////////////////////////////////////
// オフスクリーンレンダーターゲット
// マスクテクスチャ
texture texSunMask: OFFSCREENRENDERTARGET <
	string Description = "SunMask For GodRay.fx";
	float2 ViewPortRatio = {1.0, 1.0};
	float4 ClearColor = { 0, 0, 0, 1 }; float ClearDepth = 1.0;
	string Format= HDR_BUFFER_FORMAT ;
	bool AntiAlias = false; int Miplevels=1;
	string DefaultEffect =
		"self=hide;"
		"Sun.x=Sun.fx;"
		"Moon.x=Moon.fx;"
		"Cloud1.x = NotSunCloud1.fx;"
		"CloudDome.x = NotSunCloudDome.fx;"
		"*=NotSun.fx;";
>;
sampler smpSunMask = sampler_state{
	Texture = <texSunMask>;
	Filter=LINEAR;
    AddressU = Clamp; AddressV = Clamp;
};
// 深度
texture texZDepth: OFFSCREENRENDERTARGET <
    string Description = "Z Depth For GodRay.fx";
	float2 ViewportRatio = {1.0, 1.0};
    float4 ClearColor = { 1, 1, 1, 1 }; float ClearDepth = 1.0;
    string Format = "A8R8G8B8";
    bool AntiAlias = true; int Miplevels=1;
    string DefaultEffect = 
        "self = hide;"
		"Sun.x=hide;"
		"Cloud1.x = Cloud1ZDepth.fx;"
		"CloudDome.x = CloudDomeZDepth.fx;"
        "* = GodRayZDepth.fx;";
>;
sampler smpZDepth = sampler_state {
	texture = <texZDepth>;
	Filter=LINEAR;
	AddressU  = CLAMP; AddressV = CLAMP;
};

// オリジナル
texture2D texOut : RENDERCOLORTARGET
	< float2 ViewportRatio = {1.0, 1.0}; int MipLevels = 1; string Format = "A8R8G8B8"; >;
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET
	< float2 ViewportRatio = {1.0, 1.0}; string Format = "D24S8"; >;
// サンプラー
sampler2D smpOut = sampler_state {
	texture = <texOut>;
	MinFilter = LINEAR; MagFilter=LINEAR; MipFilter = LINEAR;
	AddressU = CLAMP; AddressV = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// テクスチャ
// 深度マスク(放射ブラー)
texture2D texDepthMaskBlur : RENDERCOLORTARGET
	< float2 ViewportRatio = {1.0, 1.0}; int MipLevels = 1; string Format = "A8R8G8B8"; >;
sampler2D smpDepthMaskBlur = sampler_state {
	texture = <texDepthMaskBlur>;
	MinFilter = LINEAR; MagFilter=LINEAR; MipFilter = LINEAR;
	AddressU = CLAMP; AddressV = CLAMP;
};
// 太陽マスク(ブルーム)
texture2D texSunMaskBloom : RENDERCOLORTARGET
	< float2 ViewportRatio = {1.0, 1.0}; int MipLevels = 1; string Format = "A8R8G8B8"; >;
sampler2D smpSunMaskBloom = sampler_state {
	texture = <texSunMaskBloom>;
	MinFilter = LINEAR; MagFilter=LINEAR; MipFilter = LINEAR;
	AddressU = CLAMP; AddressV = CLAMP;
};
// ブラー用
texture2D texBlur1 : RENDERCOLORTARGET
	< float2 ViewportRatio = {1.0, 1.0}; int MipLevels = 1; string Format = "A8R8G8B8"; >;
sampler2D smpBlur1 = sampler_state {
	texture = <texBlur1>;
	MinFilter = LINEAR; MagFilter=LINEAR; MipFilter = LINEAR;
	AddressU = CLAMP; AddressV = CLAMP;
};
// ブルーム用
texture2D texHighBloom1 : RENDERCOLORTARGET
	< float2 ViewportRatio = {1.0, 1.0}; int MipLevels = 1; string Format = HDR_BUFFER_FORMAT; >;
sampler2D smpHighBloom1 = sampler_state {
	texture = <texHighBloom1>;
	Filter=POINT;
	AddressU = CLAMP; AddressV = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// カメラ行列
float4x4 WorldViewProjMatrix: WORLDVIEWPROJECTION;
float4x4 ViewProjMatrix: VIEWPROJECTION;
// ライト方向
float3 LightDirection	: DIRECTION	< string Object = "Light"; >;
// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2)0.5/ViewportSize;
// レンダリングターゲットのクリア値
float4 ClearColorB = {0,0,0,1}, ClearColorW = {1,1,1,1};
float ClearDepth = 1.0;

// ガウス //
#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379
float Weights[8]={ WT_0, WT_1, WT_2, WT_3, WT_4, WT_5, WT_6, WT_7 };
// ぼかしの強さ
// ガウス
static float SampStep = 0.004*BloomPower*float2(ViewportSize.y/ViewportSize.x, 1);
// 放射ブラー
static float RadialBlurStep = 0.01*RadialBlurPower;

// 太陽の位置と月の位置
#ifdef SYNCLIGHT
float3 SunXYZ : CONTROLOBJECT < string name = "Sun.x"; string item = "XYZ";>;	// 座標
static float3 SunPos = -LightDirection * SunXYZ.z * RevScale;
float3 MoonXYZ : CONTROLOBJECT < string name = "Moon.x"; string item = "XYZ";>;	// 座標
static float3 MoonPos = -LightDirection * MoonXYZ.z * RevScale;
#else
float4x4 SunMatrix : CONTROLOBJECT < string name = "Sun.x"; >;	// 行列
static float3 SunPos = SunMatrix._41_42_43*RevScale;
float4x4 MoonMatrix : CONTROLOBJECT < string name = "Moon.x"; >;// 行列
static float3 MoonPos = MoonMatrix._41_42_43*RevScale;
#endif
// スクリーン座標での位置
static float4 SunScreenPos = mul(float4(SunPos,1), ViewProjMatrix);
static float2 SunTexPos = SunScreenPos.xy/SunScreenPos.w;
static float4 MoonScreenPos = mul(float4(MoonPos,1), ViewProjMatrix);
static float2 MoonTexPos = MoonScreenPos.xy/MoonScreenPos.w;


////////////////////////////////////////////////////////////////////////////////////////////////
// 最終合成 //
// 頂点出力
struct VS_OUTPUT {
	float4 Pos	: POSITION;
	float2 Tex	: TEXCOORD0;
};
// 頂点シェーダ
VS_OUTPUT VS( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	return Out;
}
// ピクセルシェーダ
float4 PS( VS_OUTPUT In ) : COLOR
{
	//return tex2D(smpSunMaskBloom, In.Tex);
	//return tex2D(smpZDepth, In.Tex).r;
	//return tex2D(smpDepthMaskBlur, In.Tex).r;
	float4 Color=tex2D(smpOut,In.Tex);
	// 合成
	// フレームの作成
	// 太陽が沈んでいるときは月を有効化
	float2 LTexPos=1;
	float ScreenPosW=1;
	float3 LObjectPos=1;
	float Power=1;
	float4 GradColor = 1;
	if(SunPos.y<0){
		LTexPos = MoonTexPos;
		ScreenPosW = MoonScreenPos.w;
		LObjectPos = MoonPos;
		Power = Dark;
		GradColor = tex2D(smpSun,saturate(dot(normalize(LObjectPos),float3(0,1,0)))) * MoonColor;
	}
	else{
		LTexPos = SunTexPos;
		ScreenPosW = SunScreenPos.w;
		LObjectPos = SunPos;
		Power = Bright;
		GradColor = tex2D(smpMoon,saturate(dot(normalize(LObjectPos),float3(0,1,0)))) * SunColor;
	}
	// 太陽の座標をテクスチャ座標にする
	float2 center = float2(LTexPos.x, -LTexPos.y);	// -1～1の範囲に変換
	float2 pos = (In.Tex-0.5)*2;	// -1～1の範囲に変換
	// アスペクト比を合わせる
	pos.y *= ViewportSize.y/ViewportSize.x;
	center.y *= ViewportSize.y/ViewportSize.x;
	// 円フレーム
	float f = max(1-distance(pos, center), 0);
	float frame = saturate(FrameSharpness * (f - FrameLimit));

	// 深度(影)のブラー結果を合成、太陽が後に回ったときは0
#if RBLUR_SMPNUM==1
	frame *= tex2D(smpDepthMaskBlur, In.Tex).r * (ScreenPosW>0 ? 1 : 0);
#endif
#if RBLUR_SMPNUM==2 || RBLUR_SMPNUM==3
	frame *= tex2D(smpDepthMaskBlur, In.Tex).r * (ScreenPosW>0 ? 1 : 0);
#endif
	
	// 影を合成
	Color.rgb += GradColor.rgb * frame * Tr * Power;
	//Color.rgb += tex2D(smpSun,saturate(dot(-LightDirection,float3(0,1,0)))).rgb * frame * Tr;
	//Color.rgb *= saturate(frame+saturate(dot(-LightDirection,float3(0,1,0))) + 0.8);
	
	// ブルームを合成
	Color.rgb += tex2D(smpSunMaskBloom, In.Tex).rgb * Power;
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 光筋（放射ブラー） //
// 放射ブラー
// ピクセルシェーダ
float4 PS_RadialBlur( float2 Tex : TEXCOORD0, uniform sampler2D smp ) : COLOR {   
    float4 Color=(float)0;
	// 太陽が沈んでいるときは月を中心
	float2 LObjectPos;
	if(normalize(SunPos).y<0)
		LObjectPos = MoonTexPos;
	else
		LObjectPos = SunTexPos;
	// 太陽の位置を中心に放射状にブラーをかける
	float2 Center = float2((LObjectPos.x+1.0f)*0.5f,(-LObjectPos.y+1.0f)*0.5f);
	// オフセット
	float2 uvOffset = (Center-Tex) * RadialBlurStep;
	// テクスチャ座標
	float2 uv = Tex;
	// サンプリングの回数だけ実行
	for(int i=0; i<RBLUR_NUM; i++) {
		Color+=tex2D(smp, uv);
		uv+=uvOffset;	// テクスチャ座標的には小さくなると拡大
	}
	Color /= RBLUR_NUM;
//	float d = length(center-(float2)0.5);
//	Color = lerp(Color,(float4)1, d);
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// ガウスブルーム //
float4 PS_Gauss( float2 Tex: TEXCOORD0, uniform float2 GaussDir, uniform sampler2D smp ) : COLOR {   
    float4 Color=(float4)0;
	Color = WT_0*tex2D(smp, Tex);
	for(int i=1;i<8;i++){
		float2 tex = SampStep*i * GaussDir;
		Color += Weights[i] * ( tex2D(smp, Tex+tex) + tex2D(smp, Tex-tex) );
	}
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique Main <
	string Script =
		"RenderColorTarget0=texOut; RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColorB; ClearSetDepth=ClearDepth;"
		"Clear=Color; Clear=Depth;"
			"ScriptExternal=Color;"

		// 深度マスクの放射ブラー
#if RBLUR_SMPNUM==1
		"RenderColorTarget0=texDepthMaskBlur;"
		"Clear=Color; Clear=Depth;"
			"Pass=PassDepthMaskBlur1;"
#endif
#if RBLUR_SMPNUM==2
		"RenderColorTarget0=texBlur1;"
		"Clear=Color; Clear=Depth;"
			"Pass=PassDepthMaskBlur1;"
		"RenderColorTarget0=texDepthMaskBlur;"
		"Clear=Color; Clear=Depth;"
			"Pass=PassDepthMaskBlur3;"
#endif
#if RBLUR_SMPNUM==3
		"RenderColorTarget0=texDepthMaskBlur;"
		"Clear=Color; Clear=Depth;"
			"Pass=PassDepthMaskBlur1;"
		"RenderColorTarget0=texBlur1;"
		"Clear=Color; Clear=Depth;"
			"Pass=PassDepthMaskBlur2;"
		"RenderColorTarget0=texDepthMaskBlur;"
		"Clear=Color; Clear=Depth;"
			"Pass=PassDepthMaskBlur3;"
#endif

		// 太陽マスクのブルーム
		"RenderColorTarget0=texHighBloom1;"
		"Clear=Color; Clear=Depth;"
			"Pass=PassSunMaskBlur1;"
		"RenderColorTarget0=texSunMaskBloom;"
		"Clear=Color; Clear=Depth;"
			"Pass=PassSunMaskBlur2;"
		

		"RenderColorTarget0=; RenderDepthStencilTarget=;"
		"Clear=Color; Clear=Depth;"
			"Pass=Pass1;"
	;
> {
	// 深度マスクのブラー
	pass PassDepthMaskBlur1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_0 PS_RadialBlur(smpZDepth);
	}
	pass PassDepthMaskBlur2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_0 PS_RadialBlur(smpDepthMaskBlur);
	}
	pass PassDepthMaskBlur3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_0 PS_RadialBlur(smpBlur1);
	}
	// 太陽マスクのブラー
	pass PassSunMaskBlur1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_0 PS_Gauss(float2(1,0),smpSunMask);
	}
	pass PassSunMaskBlur2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_0 PS_Gauss(float2(0,1),smpHighBloom1);
	}
	// 最終合成
	pass Pass1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_0 PS();
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////