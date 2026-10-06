// ぼかし処理の重み係数：
//    ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//    (WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379
//ポストエフェクト用宣言
float Script : STANDARDSGLOBAL
<
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset0 = (float2(0.5,0.5) / ViewportSize);
static float2 ViewportOffset1 = (float2(0.5,0.5) / (ViewportSize*0.25));
static float2 ViewportOffset2 = (float2(0.5,0.5) / (ViewportSize*0.125));
static float2 ViewportOffset3 = (float2(0.5,0.5) / (ViewportSize*0.0625));
static float2 ViewportOffset4 = (float2(0.5,0.5) / (ViewportSize*0.03125));
float4 ClearColor = {1,1,1,1};
float ClearDepth = 1.0;
/////////////////////////////////////////////////////////////////////////////////////////
//ワールド変換行列、これからMMDの設定値を受け取る
float4x4 matWorld : WORLD;
//高輝度部判定の閾値
static const float4 thresholdColor = {(100-matWorld._41)*0.01,(100-matWorld._41)*0.01,(100-matWorld._41)*0.01,0};
//画面全体に足す値
static const float4 diffuseColor = {matWorld._42*0.01,matWorld._42*0.01,matWorld._42*0.01,1};
//高輝度部に掛ける値、高輝度部の倍率
static const float4 modulateColor = {1+matWorld._43*0.01,1+matWorld._43*0.01,1+matWorld._43*0.01,1};
//高輝度ぼやけ範囲、適当に設定
static const float range = length(matWorld._11_12_13)*0.01;
static float2 SampStep0 = (float2(2,2) / ViewportSize)*range;
static float2 SampStep1 = (float2(2,2) / (ViewportSize*0.25))*range;
static float2 SampStep2 = (float2(2,2) / (ViewportSize*0.125))*range;
static float2 SampStep3 = (float2(2,2) / (ViewportSize*0.0625))*range;
static float2 SampStep4 = (float2(2,2) / (ViewportSize*0.03125))*range;
/////////////////////////////////////////////////////////////////////////////////////////
//深度値用レンダーターゲット
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET
<
	float2 ViewportRatio = {1.0,1.0};
	string Format = "D24S8";
>;
//オリジナルの描画結果記録用レンダーターゲット
texture2D OriginalTex : RENDERCOLORTARGET
<
	float2 ViewportRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
sampler2D OriginalSamp = sampler_state
{
	texture = <OriginalTex>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
//高輝度部出力用レンダーターゲット(ガウスかける原本)
texture2D HighBriTexG : RENDERCOLORTARGET
<
	float2 ViewportRatio = {1,1};
	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
sampler2D HighBriSampG = sampler_state
{
	texture = <HighBriTexG>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
//ガウスフィルタ途中のレンダーターゲット
texture2D GaussianTempTex0 : RENDERCOLORTARGET
<
	float2 ViewportRatio = {1,1};
	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
sampler2D GaussianTempSamp0 = sampler_state
{
	texture = <GaussianTempTex0>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D GaussianTempTex1 : RENDERCOLORTARGET
<
	float2 ViewportRatio = {0.5,0.5};
	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
sampler2D GaussianTempSamp1 = sampler_state
{
	texture = <GaussianTempTex1>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D GaussianTempTex2 : RENDERCOLORTARGET
<
	float2 ViewportRatio = {0.25,0.25};
	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
sampler2D GaussianTempSamp2 = sampler_state
{
	texture = <GaussianTempTex2>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D GaussianTempTex3 : RENDERCOLORTARGET
<
	float2 ViewportRatio = {0.125,0.125};
	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
sampler2D GaussianTempSamp3 = sampler_state
{
	texture = <GaussianTempTex3>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D GaussianTempTex4 : RENDERCOLORTARGET
<
	float2 ViewportRatio = {0.0625,0.0625};
	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
sampler2D GaussianTempSamp4 = sampler_state
{
	texture = <GaussianTempTex4>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
//高輝度部出力用レンダーターゲット(ガウスを掛けられたRT達)
texture2D HighBriTex0 : RENDERCOLORTARGET
<
	float2 ViewportRatio = {1,1};
	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
sampler2D HighBriSamp0 = sampler_state
{
	texture = <HighBriTex0>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D HighBriTex1 : RENDERCOLORTARGET
<
	float2 ViewportRatio = {0.5,0.5};
	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
sampler2D HighBriSamp1 = sampler_state
{
	texture = <HighBriTex1>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D HighBriTex2 : RENDERCOLORTARGET
<
	float2 ViewportRatio = {0.25,0.25};
	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
sampler2D HighBriSamp2 = sampler_state
{
	texture = <HighBriTex2>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D HighBriTex3 : RENDERCOLORTARGET
<
	float2 ViewportRatio = {0.125,0.125};
	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
sampler2D HighBriSamp3 = sampler_state
{
	texture = <HighBriTex3>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
texture2D HighBriTex4 : RENDERCOLORTARGET
<
	float2 ViewportRatio = {0.0625,0.0625};
	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
sampler2D HighBriSamp4 = sampler_state
{
	texture = <HighBriTex4>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
/////////////////////////////////////////////////////////////////////////////////////////
//頂点シェーダ出力
struct VS_OUTPUT
{
	float4 pos : POSITION;	//頂点座標
	float2 tex : TEXCOORD0;	//テクスチャ座標0
};
/////////////////////////////////////////////////////////////////////////////////////////
//高輝度部出力
VS_OUTPUT VS_HighBri(float4 pos : POSITION,float2 tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.pos = pos;
	Out.tex = tex + ViewportOffset0;
	return Out;
}
float4 PS_HighBri(float2 tex : TEXCOORD0) : COLOR
{
	return saturate(float4(tex2D(OriginalSamp,tex)) - thresholdColor) * modulateColor;
}
//ガウスフィルタを掛ける,X方向
VS_OUTPUT VS_GaussianX0(float4 pos : POSITION,float2 tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.pos = pos;
	Out.tex = tex + float2(0,ViewportOffset0.y);
	return Out;
}
float4 PS_GaussianX0(float2 tex : TEXCOORD0) : COLOR
{
	float4 color;
	color  = WT_0 *  tex2D(HighBriSampG,tex);
	color += WT_1 * (tex2D(HighBriSampG,tex + float2(SampStep0.x  ,0)) + tex2D(HighBriSampG,tex - float2(SampStep0.x  ,0)));
	color += WT_2 * (tex2D(HighBriSampG,tex + float2(SampStep0.x*2,0)) + tex2D(HighBriSampG,tex - float2(SampStep0.x*2,0)));
	color += WT_3 * (tex2D(HighBriSampG,tex + float2(SampStep0.x*3,0)) + tex2D(HighBriSampG,tex - float2(SampStep0.x*3,0)));
	color += WT_4 * (tex2D(HighBriSampG,tex + float2(SampStep0.x*4,0)) + tex2D(HighBriSampG,tex - float2(SampStep0.x*4,0)));
	color += WT_5 * (tex2D(HighBriSampG,tex + float2(SampStep0.x*5,0)) + tex2D(HighBriSampG,tex - float2(SampStep0.x*5,0)));
	color += WT_6 * (tex2D(HighBriSampG,tex + float2(SampStep0.x*6,0)) + tex2D(HighBriSampG,tex - float2(SampStep0.x*6,0)));
	color += WT_7 * (tex2D(HighBriSampG,tex + float2(SampStep0.x*7,0)) + tex2D(HighBriSampG,tex - float2(SampStep0.x*7,0)));
	return color;
}
VS_OUTPUT VS_GaussianX1(float4 pos : POSITION,float2 tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.pos = pos;
	Out.tex = tex + float2(0,ViewportOffset1.y);
	return Out;
}
float4 PS_GaussianX1(float2 tex : TEXCOORD0) : COLOR
{
	float4 color;
	color  = WT_0 *  tex2D(HighBriSamp0,tex);
	color += WT_1 * (tex2D(HighBriSamp0,tex + float2(SampStep1.x  ,0)) + tex2D(HighBriSamp0,tex - float2(SampStep1.x  ,0)));
	color += WT_2 * (tex2D(HighBriSamp0,tex + float2(SampStep1.x*2,0)) + tex2D(HighBriSamp0,tex - float2(SampStep1.x*2,0)));
	color += WT_3 * (tex2D(HighBriSamp0,tex + float2(SampStep1.x*3,0)) + tex2D(HighBriSamp0,tex - float2(SampStep1.x*3,0)));
	color += WT_4 * (tex2D(HighBriSamp0,tex + float2(SampStep1.x*4,0)) + tex2D(HighBriSamp0,tex - float2(SampStep1.x*4,0)));
	color += WT_5 * (tex2D(HighBriSamp0,tex + float2(SampStep1.x*5,0)) + tex2D(HighBriSamp0,tex - float2(SampStep1.x*5,0)));
	color += WT_6 * (tex2D(HighBriSamp0,tex + float2(SampStep1.x*6,0)) + tex2D(HighBriSamp0,tex - float2(SampStep1.x*6,0)));
	color += WT_7 * (tex2D(HighBriSamp0,tex + float2(SampStep1.x*7,0)) + tex2D(HighBriSamp0,tex - float2(SampStep1.x*7,0)));
	return color;
}
VS_OUTPUT VS_GaussianX2(float4 pos : POSITION,float2 tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.pos = pos;
	Out.tex = tex + float2(0,ViewportOffset2.y);
	return Out;
}
float4 PS_GaussianX2(float2 tex : TEXCOORD0) : COLOR
{
	float4 color;
	color  = WT_0 *  tex2D(HighBriSamp1,tex);
	color += WT_1 * (tex2D(HighBriSamp1,tex + float2(SampStep2.x  ,0)) + tex2D(HighBriSamp1,tex - float2(SampStep2.x  ,0)));
	color += WT_2 * (tex2D(HighBriSamp1,tex + float2(SampStep2.x*2,0)) + tex2D(HighBriSamp1,tex - float2(SampStep2.x*2,0)));
	color += WT_3 * (tex2D(HighBriSamp1,tex + float2(SampStep2.x*3,0)) + tex2D(HighBriSamp1,tex - float2(SampStep2.x*3,0)));
	color += WT_4 * (tex2D(HighBriSamp1,tex + float2(SampStep2.x*4,0)) + tex2D(HighBriSamp1,tex - float2(SampStep2.x*4,0)));
	color += WT_5 * (tex2D(HighBriSamp1,tex + float2(SampStep2.x*5,0)) + tex2D(HighBriSamp1,tex - float2(SampStep2.x*5,0)));
	color += WT_6 * (tex2D(HighBriSamp1,tex + float2(SampStep2.x*6,0)) + tex2D(HighBriSamp1,tex - float2(SampStep2.x*6,0)));
	color += WT_7 * (tex2D(HighBriSamp1,tex + float2(SampStep2.x*7,0)) + tex2D(HighBriSamp1,tex - float2(SampStep2.x*7,0)));
	return color;
}
VS_OUTPUT VS_GaussianX3(float4 pos : POSITION,float2 tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.pos = pos;
	Out.tex = tex + float2(0,ViewportOffset3.y);
	return Out;
}
float4 PS_GaussianX3(float2 tex : TEXCOORD0) : COLOR
{
	float4 color;
	color  = WT_0 *  tex2D(HighBriSamp2,tex);
	color += WT_1 * (tex2D(HighBriSamp2,tex + float2(SampStep3.x  ,0)) + tex2D(HighBriSamp2,tex - float2(SampStep3.x  ,0)));
	color += WT_2 * (tex2D(HighBriSamp2,tex + float2(SampStep3.x*2,0)) + tex2D(HighBriSamp2,tex - float2(SampStep3.x*2,0)));
	color += WT_3 * (tex2D(HighBriSamp2,tex + float2(SampStep3.x*3,0)) + tex2D(HighBriSamp2,tex - float2(SampStep3.x*3,0)));
	color += WT_4 * (tex2D(HighBriSamp2,tex + float2(SampStep3.x*4,0)) + tex2D(HighBriSamp2,tex - float2(SampStep3.x*4,0)));
	color += WT_5 * (tex2D(HighBriSamp2,tex + float2(SampStep3.x*5,0)) + tex2D(HighBriSamp2,tex - float2(SampStep3.x*5,0)));
	color += WT_6 * (tex2D(HighBriSamp2,tex + float2(SampStep3.x*6,0)) + tex2D(HighBriSamp2,tex - float2(SampStep3.x*6,0)));
	color += WT_7 * (tex2D(HighBriSamp2,tex + float2(SampStep3.x*7,0)) + tex2D(HighBriSamp2,tex - float2(SampStep3.x*7,0)));
	return color;
}
VS_OUTPUT VS_GaussianX4(float4 pos : POSITION,float2 tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.pos = pos;
	Out.tex = tex + float2(0,ViewportOffset4.y);
	return Out;
}
float4 PS_GaussianX4(float2 tex : TEXCOORD0) : COLOR
{
	float4 color;
	color  = WT_0 *  tex2D(HighBriSamp3,tex);
	color += WT_1 * (tex2D(HighBriSamp3,tex + float2(SampStep4.x  ,0)) + tex2D(HighBriSamp3,tex - float2(SampStep4.x  ,0)));
	color += WT_2 * (tex2D(HighBriSamp3,tex + float2(SampStep4.x*2,0)) + tex2D(HighBriSamp3,tex - float2(SampStep4.x*2,0)));
	color += WT_3 * (tex2D(HighBriSamp3,tex + float2(SampStep4.x*3,0)) + tex2D(HighBriSamp3,tex - float2(SampStep4.x*3,0)));
	color += WT_4 * (tex2D(HighBriSamp3,tex + float2(SampStep4.x*4,0)) + tex2D(HighBriSamp3,tex - float2(SampStep4.x*4,0)));
	color += WT_5 * (tex2D(HighBriSamp3,tex + float2(SampStep4.x*5,0)) + tex2D(HighBriSamp3,tex - float2(SampStep4.x*5,0)));
	color += WT_6 * (tex2D(HighBriSamp3,tex + float2(SampStep4.x*6,0)) + tex2D(HighBriSamp3,tex - float2(SampStep4.x*6,0)));
	color += WT_7 * (tex2D(HighBriSamp3,tex + float2(SampStep4.x*7,0)) + tex2D(HighBriSamp3,tex - float2(SampStep4.x*7,0)));
	return color;
}
//ガウスフィルタを掛ける,Y方向pass
VS_OUTPUT VS_GaussianY0(float4 pos : POSITION,float2 tex : TEXCOORD0) 
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.pos = pos;
	Out.tex = tex + float2(ViewportOffset0.x,0);
	return Out;
}
float4 PS_GaussianY0(float2 tex : TEXCOORD0) : COLOR
{
	float4 color;
	color  = WT_0 *  tex2D(GaussianTempSamp0,tex);
	color += WT_1 * (tex2D(GaussianTempSamp0,tex + float2(0,SampStep0.y  )) + tex2D(GaussianTempSamp0,tex - float2(0,SampStep0.y  )));
	color += WT_2 * (tex2D(GaussianTempSamp0,tex + float2(0,SampStep0.y*2)) + tex2D(GaussianTempSamp0,tex - float2(0,SampStep0.y*2)));
	color += WT_3 * (tex2D(GaussianTempSamp0,tex + float2(0,SampStep0.y*3)) + tex2D(GaussianTempSamp0,tex - float2(0,SampStep0.y*3)));
	color += WT_4 * (tex2D(GaussianTempSamp0,tex + float2(0,SampStep0.y*4)) + tex2D(GaussianTempSamp0,tex - float2(0,SampStep0.y*4)));
	color += WT_5 * (tex2D(GaussianTempSamp0,tex + float2(0,SampStep0.y*5)) + tex2D(GaussianTempSamp0,tex - float2(0,SampStep0.y*5)));
	color += WT_6 * (tex2D(GaussianTempSamp0,tex + float2(0,SampStep0.y*6)) + tex2D(GaussianTempSamp0,tex - float2(0,SampStep0.y*6)));
	color += WT_7 * (tex2D(GaussianTempSamp0,tex + float2(0,SampStep0.y*7)) + tex2D(GaussianTempSamp0,tex - float2(0,SampStep0.y*7)));
	return color;
}
VS_OUTPUT VS_GaussianY1(float4 pos : POSITION,float2 tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.pos = pos;
	Out.tex = tex + float2(ViewportOffset1.x,0);
	return Out;
}
float4 PS_GaussianY1(float2 tex : TEXCOORD0) : COLOR
{
	float4 color;
	color  = WT_0 *  tex2D(GaussianTempSamp1,tex);
	color += WT_1 * (tex2D(GaussianTempSamp1,tex + float2(0,SampStep1.y  )) + tex2D(GaussianTempSamp1,tex - float2(0,SampStep1.y  )));
	color += WT_2 * (tex2D(GaussianTempSamp1,tex + float2(0,SampStep1.y*2)) + tex2D(GaussianTempSamp1,tex - float2(0,SampStep1.y*2)));
	color += WT_3 * (tex2D(GaussianTempSamp1,tex + float2(0,SampStep1.y*3)) + tex2D(GaussianTempSamp1,tex - float2(0,SampStep1.y*3)));
	color += WT_4 * (tex2D(GaussianTempSamp1,tex + float2(0,SampStep1.y*4)) + tex2D(GaussianTempSamp1,tex - float2(0,SampStep1.y*4)));
	color += WT_5 * (tex2D(GaussianTempSamp1,tex + float2(0,SampStep1.y*5)) + tex2D(GaussianTempSamp1,tex - float2(0,SampStep1.y*5)));
	color += WT_6 * (tex2D(GaussianTempSamp1,tex + float2(0,SampStep1.y*6)) + tex2D(GaussianTempSamp1,tex - float2(0,SampStep1.y*6)));
	color += WT_7 * (tex2D(GaussianTempSamp1,tex + float2(0,SampStep1.y*7)) + tex2D(GaussianTempSamp1,tex - float2(0,SampStep1.y*7)));
	return color;
}
VS_OUTPUT VS_GaussianY2(float4 pos : POSITION,float2 tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.pos = pos;
	Out.tex = tex + float2(ViewportOffset2.x,0);
	return Out;
}
float4 PS_GaussianY2(float2 tex : TEXCOORD0) : COLOR
{
	float4 color;
	color  = WT_0 *  tex2D(GaussianTempSamp2,tex);
	color += WT_1 * (tex2D(GaussianTempSamp2,tex + float2(0,SampStep2.y  )) + tex2D(GaussianTempSamp2,tex - float2(0,SampStep2.y  )));
	color += WT_2 * (tex2D(GaussianTempSamp2,tex + float2(0,SampStep2.y*2)) + tex2D(GaussianTempSamp2,tex - float2(0,SampStep2.y*2)));
	color += WT_3 * (tex2D(GaussianTempSamp2,tex + float2(0,SampStep2.y*3)) + tex2D(GaussianTempSamp2,tex - float2(0,SampStep2.y*3)));
	color += WT_4 * (tex2D(GaussianTempSamp2,tex + float2(0,SampStep2.y*4)) + tex2D(GaussianTempSamp2,tex - float2(0,SampStep2.y*4)));
	color += WT_5 * (tex2D(GaussianTempSamp2,tex + float2(0,SampStep2.y*5)) + tex2D(GaussianTempSamp2,tex - float2(0,SampStep2.y*5)));
	color += WT_6 * (tex2D(GaussianTempSamp2,tex + float2(0,SampStep2.y*6)) + tex2D(GaussianTempSamp2,tex - float2(0,SampStep2.y*6)));
	color += WT_7 * (tex2D(GaussianTempSamp2,tex + float2(0,SampStep2.y*7)) + tex2D(GaussianTempSamp2,tex - float2(0,SampStep2.y*7)));
	return color;
}
VS_OUTPUT VS_GaussianY3(float4 pos : POSITION,float2 tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.pos = pos;
	Out.tex = tex + float2(ViewportOffset3.x,0);
	return Out;
}
float4 PS_GaussianY3(float2 tex : TEXCOORD0) : COLOR
{
	float4 color;
	color  = WT_0 *  tex2D(GaussianTempSamp3,tex);
	color += WT_1 * (tex2D(GaussianTempSamp3,tex + float2(0,SampStep3.y  )) + tex2D(GaussianTempSamp3,tex - float2(0,SampStep3.y  )));
	color += WT_2 * (tex2D(GaussianTempSamp3,tex + float2(0,SampStep3.y*2)) + tex2D(GaussianTempSamp3,tex - float2(0,SampStep3.y*2)));
	color += WT_3 * (tex2D(GaussianTempSamp3,tex + float2(0,SampStep3.y*3)) + tex2D(GaussianTempSamp3,tex - float2(0,SampStep3.y*3)));
	color += WT_4 * (tex2D(GaussianTempSamp3,tex + float2(0,SampStep3.y*4)) + tex2D(GaussianTempSamp3,tex - float2(0,SampStep3.y*4)));
	color += WT_5 * (tex2D(GaussianTempSamp3,tex + float2(0,SampStep3.y*5)) + tex2D(GaussianTempSamp3,tex - float2(0,SampStep3.y*5)));
	color += WT_6 * (tex2D(GaussianTempSamp3,tex + float2(0,SampStep3.y*6)) + tex2D(GaussianTempSamp3,tex - float2(0,SampStep3.y*6)));
	color += WT_7 * (tex2D(GaussianTempSamp3,tex + float2(0,SampStep3.y*7)) + tex2D(GaussianTempSamp3,tex - float2(0,SampStep3.y*7)));
	return color;
}
VS_OUTPUT VS_GaussianY4(float4 pos : POSITION,float2 tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.pos = pos;
	Out.tex = tex + float2(ViewportOffset4.x,0);
	return Out;
}
float4 PS_GaussianY4(float2 tex : TEXCOORD0) : COLOR
{
	float4 color;
	color  = WT_0 *  tex2D(GaussianTempSamp4,tex);
	color += WT_1 * (tex2D(GaussianTempSamp4,tex + float2(0,SampStep4.y  )) + tex2D(GaussianTempSamp4,tex - float2(0,SampStep4.y  )));
	color += WT_2 * (tex2D(GaussianTempSamp4,tex + float2(0,SampStep4.y*2)) + tex2D(GaussianTempSamp4,tex - float2(0,SampStep4.y*2)));
	color += WT_3 * (tex2D(GaussianTempSamp4,tex + float2(0,SampStep4.y*3)) + tex2D(GaussianTempSamp4,tex - float2(0,SampStep4.y*3)));
	color += WT_4 * (tex2D(GaussianTempSamp4,tex + float2(0,SampStep4.y*4)) + tex2D(GaussianTempSamp4,tex - float2(0,SampStep4.y*4)));
	color += WT_5 * (tex2D(GaussianTempSamp4,tex + float2(0,SampStep4.y*5)) + tex2D(GaussianTempSamp4,tex - float2(0,SampStep4.y*5)));
	color += WT_6 * (tex2D(GaussianTempSamp4,tex + float2(0,SampStep4.y*6)) + tex2D(GaussianTempSamp4,tex - float2(0,SampStep4.y*6)));
	color += WT_7 * (tex2D(GaussianTempSamp4,tex + float2(0,SampStep4.y*7)) + tex2D(GaussianTempSamp4,tex - float2(0,SampStep4.y*7)));
	return color;
}
//高輝度部と通常描画を合成して最終出力
VS_OUTPUT VS_Finish(float4 pos : POSITION,float2 tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.pos = pos;
	Out.tex = tex + ViewportOffset0;
	return Out;
}
float4 PS_Finish(float2 tex : TEXCOORD0) : COLOR
{
	return float4(tex2D(OriginalSamp,tex)) + float4(tex2D(HighBriSamp0,tex)) + 
		float4(tex2D(HighBriSamp1,tex)) + float4(tex2D(HighBriSamp2,tex)) + 
		float4(tex2D(HighBriSamp3,tex)) + float4(tex2D(HighBriSamp4,tex)) + diffuseColor;
}
/////////////////////////////////////////////////////////////////////////////////////////
technique LightBloom
<string Script = 
	//基本描画
	"RenderColorTarget0=OriginalTex;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"ClearSetColor=ClearColor;"
	"ClearSetDepth=ClearDepth;"
	"Clear=Color;"
	"Clear=Depth;"
	"ScriptExternal=Color;"
	//高輝度部原本
	"RenderColorTarget0=HighBriTexG;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
	"Pass=HighBriRender;"
	//ガウスフィルタ0
	"RenderColorTarget0=GaussianTempTex0;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
	"Pass=GaussianX0;"
	"RenderColorTarget0=HighBriTex0;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
	"Pass=GaussianY0;"
	//1
	"RenderColorTarget0=GaussianTempTex1;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
	"Pass=GaussianX1;"
	"RenderColorTarget0=HighBriTex1;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
	"Pass=GaussianY1;"
	//2
	"RenderColorTarget0=GaussianTempTex2;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
	"Pass=GaussianX2;"
	"RenderColorTarget0=HighBriTex2;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
	"Pass=GaussianY2;"
	//3
	"RenderColorTarget0=GaussianTempTex3;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
	"Pass=GaussianX3;"
	"RenderColorTarget0=HighBriTex3;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
	"Pass=GaussianY3;"
	//4
	"RenderColorTarget0=GaussianTempTex4;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
	"Pass=GaussianX4;"
	"RenderColorTarget0=HighBriTex4;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
	"Pass=GaussianY4;"
	//高輝度部と通常描画を合成して描画
	"RenderColorTarget0=;"
	"RenderDepthStencilTarget=;"
	"Clear=Color;"
	"Clear=Depth;"
	"Pass=Finish;"
;>
{
	//高輝度部を抽出する
	pass HighBriRender <string Script = "Draw=Buffer";>
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_HighBri();
		PixelShader = compile ps_2_0 PS_HighBri();
	}
	//ガウスX方向
	pass GaussianX0 <string Script = "Draw=Buffer";>
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_GaussianX0();
		PixelShader = compile ps_2_0 PS_GaussianX0();
	}
	pass GaussianX1 <string Script = "Draw=Buffer";>
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_GaussianX1();
		PixelShader = compile ps_2_0 PS_GaussianX1();
	}
	pass GaussianX2 <string Script = "Draw=Buffer";>
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_GaussianX2();
		PixelShader = compile ps_2_0 PS_GaussianX2();
	}
	pass GaussianX3 <string Script = "Draw=Buffer";>
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_GaussianX3();
		PixelShader = compile ps_2_0 PS_GaussianX3();
	}
	pass GaussianX4 <string Script = "Draw=Buffer";>
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_GaussianX4();
		PixelShader = compile ps_2_0 PS_GaussianX4();
	}
	//ガウスY方向 
	pass GaussianY0 <string Script = "Draw=Buffer";>
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_GaussianY0();
		PixelShader = compile ps_2_0 PS_GaussianY0();
	}
	pass GaussianY1 <string Script = "Draw=Buffer";>
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_GaussianY1();
		PixelShader = compile ps_2_0 PS_GaussianY1();
	}
	pass GaussianY2 <string Script = "Draw=Buffer";>
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_GaussianY2();
		PixelShader = compile ps_2_0 PS_GaussianY2();
	}
	pass GaussianY3 <string Script = "Draw=Buffer";>
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_GaussianY3();
		PixelShader = compile ps_2_0 PS_GaussianY3();
	}
	pass GaussianY4 <string Script = "Draw=Buffer";>
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_GaussianY4();
		PixelShader = compile ps_2_0 PS_GaussianY4();
	}
	//最終出力(RT合成)
	pass Finish <string Script = "Draw=Buffer";>
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_Finish();
		PixelShader = compile ps_2_0 PS_Finish();
	}
}