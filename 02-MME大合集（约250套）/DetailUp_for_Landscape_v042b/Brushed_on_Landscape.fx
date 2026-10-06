////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Brushed_on_Landscape.fx v0.42b
//  作成: データP
//  ベース: full.fx 舞力介入P
//  質感向上: MipmapTexture＆AnisotropicFilter Furia氏
//  ソフトシャドウ：SpotLight そぼろ氏
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#include "config.h"

#define TargetMaterial "0-"		// 対象となる材質
//#define SkinColor float3(0.3,0.3,0.3)		// 地肌の色 定義しなければ材質・テクスチャの色 RGB
#define FurColor float3(1,1,1)	// 毛の色 定義しなければ材質・テクスチャの色 RGB
#define FurPower 0.2			// 毛の長さ?


////////////////////////////////////////////////////
// オブジェクトを個別にカスタマイズした
// エフェクトファイルを作る場合、以下を参考に調整
//
//// テクスチャバッファのサイズ(Mipmap/異方性フィルタ用)
//#undef TEXBUFFWIDTH
//#define TEXBUFFWIDTH 512
//#undef TEXBUFFHEIGHT
//#define TEXBUFFHEIGHT 512
//
//// 透過素材の透過率が高いものを切り捨てる割合 (1-255)
//#undef AlphaClipLimit
//#define AlphaClipLimit 128
//
//// 個別にシャドウのソフト化を指定しても良い。
//#undef SOFTSHADOW
//#define SOFTSHADOW SOFTSHADOW_VSM_SMALL
//
////////////////////////////////////////////////////

#define TEXBUFFSIZE { TEXBUFFWIDTH, TEXBUFFHEIGHT }

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "sceneorobject";
	string ScriptOrder = "standard";
> = 0.8;

// 座法変換行列
float4x4 WorldViewProjMatrix  : WORLDVIEWPROJECTION;
float4x4 WorldMatrix       : WORLD;
float4x4 ViewMatrix        : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
float4   EdgeColor         : EDGECOLOR;
// ライト色
float3   LightDiffuse   : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient   : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular  : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ

#define SKII1    1500
#define SKII2    8000
#define Toon     3

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler OrgObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// シャドウバッファのサンプラ
shared texture ShadowMap : OFFSCREENRENDERTARGET;
sampler ShadowMapSampler = sampler_state {
    texture = <ShadowMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// 景観テクスチャの質感向上用Mipmap
texture UseMipmapObjectTexture : RENDERCOLORTARGET <
	int2 Dimensions = TEXBUFFSIZE;
	int MipLevels = 0;
>;

// 景観テクスチャの質感向上 異方性フィルタ
sampler ObjTexSampler = sampler_state {
	texture = <UseMipmapObjectTexture>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = LINEAR;
	MAXANISOTROPY = 16;
};

// UseMipmapObjectTexture用深度バッファ
texture UMOTDepth : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = TEXBUFFSIZE;
>;

const static float2 MipmapOffset = {0.5/TEXBUFFWIDTH, 0.5/TEXBUFFHEIGHT};
// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1;

////////////////////////////////////////////////////////////////////////////////////////////////
// FOG
#if FOG_ENABLE==1
#ifndef FOG_COLOR
#define FOG_COLOR LightAmbient
#endif

float3 ControlerPos : CONTROLOBJECT <string name=FOG_CONTROLER;>;

#ifndef FOG_NEAR
#define FOG_NEAR ControlerPos.x
#endif
#ifndef FOG_FAR
#define FOG_FAR ControlerPos.z
#endif
#ifndef FOG_BRIGHT
float ControlerSiz : CONTROLOBJECT <string name=FOG_CONTROLER;>;
#define FOG_BRIGHT ControlerSiz
#endif

float4 FogMix(float4 Color, float3 Eye){
	return (FOG_FAR-FOG_NEAR)<=0.0 ? Color : float4(lerp(Color.rgb, FOG_COLOR*FOG_BRIGHT, saturate((length(Eye)-FOG_NEAR)/(FOG_FAR-FOG_NEAR))),Color.a);
}
#else
#define FogMix(x,y) x
#endif

////////////////////////////////////////////////////////////////////////////////////////////////
// テクスチャコピー
struct VS_OUT_COPYTEX {
    float4 Pos	: POSITION;
    float2 Tex	: TEXCOORD0;
};
VS_OUT_COPYTEX CopyTex_VS( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float2 TexOffset ){
	VS_OUT_COPYTEX o;
	o.Pos = Pos;
	o.Tex = Tex + TexOffset;
	return o;
}

float4 CopyTex_PS(float2 Tex: TEXCOORD0, uniform sampler TexSampler) : COLOR0 {
	return tex2D(TexSampler,Tex);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画
#if FOG_ENABLE==1
struct Edge_OUTPUT {
    float4 Pos      : POSITION;		// 射影変換座標
	float3 Eye		: TEXCOORD0;
};
// 頂点シェーダ
Edge_OUTPUT ColorRender_VS(float4 Pos : POSITION) {
	Edge_OUTPUT o;
    o.Pos = mul( Pos, WorldViewProjMatrix );
	o.Eye = CameraPosition - mul( Pos, WorldMatrix );
	return o;
}

// ピクセルシェーダ
float4 ColorRender_PS(float3 Eye:TEXCOORD0) : COLOR{
    return FogMix(EdgeColor,Eye);
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawEdge {
        VertexShader = compile vs_2_0 ColorRender_VS();
        PixelShader  = compile ps_2_0 ColorRender_PS();
    }
}
#endif

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex      : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 Color      : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR0
{
    float4 Color = IN.Color;
    if ( useTexture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }
    if ( useSphereMap) {
        // スフィアマップ適用
        if(spadd) Color.rgb += tex2D(ObjSphareSampler,IN.SpTex).rgb;
        else      Color *= tex2D(ObjSphareSampler,IN.SpTex);
    }
    if ( useToon ) {
        // トゥーン適用
        float LightNormal = dot( IN.Normal, -LightDirection );
        Color.rgb *= lerp(MaterialToon, float3(1,1,1), saturate(LightNormal * 2 + 0.5));
    }
    
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;

    // スペキュラ適用
    Color.rgb += Specular;
	// 毛の処理
	// 地肌の色
#ifdef SkinColor
	float3 skin = SkinColor;
#else
	float3 skin = Color.rgb;
#endif

	// 毛の色
#ifdef FurColor
	float3 fur = FurColor;
#else
	float3 fur = Color.rgb;
#endif
	Color.rgb=lerp(fur, skin, pow(abs(dot(normalize(IN.Eye),-normalize(IN.Normal))), FurPower));
    return FogMix(Color, IN.Eye);
}


// オブジェクト描画用テクニック
// 不要なものは削除可
#define BASIC_TEC_TEX(name, sphere, toon) \
	technique name < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = sphere; bool UseToon = toon; \
		string Script = \
			"RenderColorTarget=UseMipmapObjectTexture;" \
				"RenderDepthStencilTarget=UMOTDepth;" \
					"ClearSetColor=ClearColor;" \
					"ClearSetDepth=ClearDepth;" \
					"Clear=Color;" \
					"Clear=Depth;" \
				"Pass=CreateMipmap;" \
			"RenderColorTarget=;" \
				"RenderDepthStencilTarget=;" \
				"Pass=DrawObject;" \
		; \
	> { \
		pass CreateMipmap < string Script= "Draw=Buffer;"; >{ \
			AlphaBlendEnable = false; \
			ZEnable = false; \
			VertexShader = compile vs_2_0 CopyTex_VS(MipmapOffset); \
			PixelShader  = compile ps_2_0 CopyTex_PS(OrgObjTexSampler); \
		} \
		pass DrawObject { \
			VertexShader = compile vs_2_0 Basic_VS(true, sphere, toon); \
			PixelShader  = compile ps_2_0 Basic_PS(true, sphere, toon); \
		} \
	}
#define BASIC_TEC_NOTEX(name, sphere, toon) \
	technique name < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = sphere; bool UseToon = toon; \
	> { \
		pass DrawObject { \
			VertexShader = compile vs_2_0 Basic_VS(false, sphere, toon); \
			PixelShader  = compile ps_2_0 Basic_PS(false, sphere, toon); \
		} \
	}

BASIC_TEC_TEX(MainTec0, false, false)
BASIC_TEC_TEX(MainTec1, true,  false)
BASIC_TEC_TEX(MainTec2, false, true)
BASIC_TEC_TEX(MainTec3, true,  true)

BASIC_TEC_NOTEX(MainTec4, false, false)
BASIC_TEC_NOTEX(MainTec5, true,  false)
BASIC_TEC_NOTEX(MainTec6, false, true)
BASIC_TEC_NOTEX(MainTec7, true,  true)

///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット
// ShadowDrawへ移動
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {}


////////////////////////////////////////////////////////////////////////////////
// MMD標準のセルフシャドウの明るさ計算
float MMDShadowBrightness(float2 ShadowMapPos, float DepthRef){
	float shadow = max(DepthRef - tex2D(ShadowMapSampler,ShadowMapPos).r, 0);
	float comp = 1 - saturate(shadow*
		(parthf ? SKII2*ShadowMapPos.y // セルフシャドウモード2
				: SKII1 // セルフシャドウモード1
		)-0.3);
    return comp;
}

static const float2 sampstep = float2(1.0/SHADOWMAP_WIDTH, 1.0/SHADOWMAP_HEIGHT);


////////////////////////////////////////////////////////////////////////////////
// 大きめのソフトシャドウ
// VSM方式 27点サンプリング
// ミップマップを利用し、広範囲のぼかしを行う
// Original Code: そぼろ氏 SpotLightShadow_Object

#if SOFTSHADOW==SOFTSHADOW_VSM_LARGE
#define SHADER_VER(x) x##_3_0

float2 GetZBufSampleMipSingle(float4 t){
	float d=tex2Dlod(ShadowMapSampler, t).r;
	return float2(d, d*d);
}

float2 GetZBufSampleMip(float2 texc, float steprate, float mip){
	float2 step = steprate * sampstep;

    float2 Out = GetZBufSampleMipSingle(float4(texc, 0, mip)) * 2;

    Out += GetZBufSampleMipSingle(float4(texc + float2(0, step.y), 0, mip));
    Out += GetZBufSampleMipSingle(float4(texc + float2(0, -step.y), 0, mip));
    Out += GetZBufSampleMipSingle(float4(texc + float2(step.x, 0), 0, mip));
    Out += GetZBufSampleMipSingle(float4(texc + float2(-step.x, 0), 0, mip));
    Out += GetZBufSampleMipSingle(float4(texc + float2(step.x, step.y), 0, mip));
    Out += GetZBufSampleMipSingle(float4(texc + float2(-step.x, step.y), 0, mip));
    Out += GetZBufSampleMipSingle(float4(texc + float2(step.x, -step.y), 0, mip));
    Out += GetZBufSampleMipSingle(float4(texc + float2(-step.x, -step.y), 0, mip));

    Out /= 10;
    return Out;
}

float2 GetZBufSample(float2 texc, float steprate){
    float mipbase = sqrt(max(0, steprate-1));

    const float gain1 = 3, gain2 = 2, gain3 = 1;

    float2 Out = GetZBufSampleMip(texc, steprate, mipbase) * gain1;
    Out += GetZBufSampleMip(texc, steprate * 1.7, mipbase + 0.8) * gain2;
    Out += GetZBufSampleMip(texc, steprate * 3.5, mipbase + 1.6) * gain3;
    
    Out /= (gain1 + gain2 + gain3);
    
    return Out;
}

////////////////////////////////////////////////////////////////////////////////
// 小さめのソフトシャドウ
// VSM方式 9点サンプリング
// Original Code: そぼろ氏 SpotLightShadow_Object
#elif SOFTSHADOW==SOFTSHADOW_VSM_SMALL
#define SHADER_VER(x) x##_3_0

float2 GetZBuffSampleD2(float2 pos){
	float d=tex2D(ShadowMapSampler, pos).r;
	return float2(d, d*d);
}

// 9点サンプリング
float2 GetZBufSample(float2 texc, float steprate){
	float2 Out;
	float step = sampstep * steprate;

	Out = GetZBuffSampleD2(texc) * 2;

	Out += GetZBuffSampleD2(texc + float2(0, step));
	Out += GetZBuffSampleD2(texc + float2(0, -step));
	Out += GetZBuffSampleD2(texc + float2(step, 0));
	Out += GetZBuffSampleD2(texc + float2(-step, 0));
	Out += GetZBuffSampleD2(texc + float2(step, step)) * 0.7071; // 0.7071=sqrt(0.5) 中心からの距離
	Out += GetZBuffSampleD2(texc + float2(-step, step))* 0.7071;
	Out += GetZBuffSampleD2(texc + float2(step, -step))* 0.7071;
	Out += GetZBuffSampleD2(texc + float2(-step, -step))* 0.7071;

	Out /= 2 + 4 + 4*(0.7071);
	return Out;
}
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////
// シャドウの明るさ計算
// VSM方式共通
// Original Code: そぼろ氏 SpotLightShadow_Object
#if SOFTSHADOW==SOFTSHADOW_VSM_SMALL || SOFTSHADOW==SOFTSHADOW_VSM_LARGE
float ShadowBrightness(float2 ShadowMapPos, float DepthRef){
	float comp;
	if(parthf && (ShadowMapPos.y<SOFTSHADOW_DISTANCE)){
		comp = MMDShadowBrightness(ShadowMapPos, DepthRef);
	}
	else{
		float2 d = GetZBufSample(ShadowMapPos, 1);
		d.y += SOFTSHADOW_THRESHOLD;
		float sigma2 = d.y - d.x * d.x;
		comp = sigma2 / (sigma2 + DepthRef - d.x);
		comp = (comp<0) + saturate(comp);
	}
    return comp;
}
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 小さめのセルフシャドウ
// PCF方式 9点サンプリング
#if SOFTSHADOW==SOFTSHADOW_PCF_SMALL
#define SHADER_VER(x) x##_3_0

// 9点サンプリング
float GetZBufSample(float2 texc, float t, float steprate){
	float Out;
	float step = sampstep * steprate;

	Out = (t>tex2D(ShadowMapSampler, texc)) * 2;

	Out += (t>tex2D(ShadowMapSampler, texc + float2(0, step)));
	Out += (t>tex2D(ShadowMapSampler, texc + float2(0, -step)));
	Out += (t>tex2D(ShadowMapSampler, texc + float2(step, 0)));
	Out += (t>tex2D(ShadowMapSampler, texc + float2(-step, 0)));
	Out += (t>tex2D(ShadowMapSampler, texc + float2(step, step))) * 0.7071; // 0.7071=sqrt(0.5) 中心からの距離
	Out += (t>tex2D(ShadowMapSampler, texc + float2(-step, step))) * 0.7071;
	Out += (t>tex2D(ShadowMapSampler, texc + float2(step, -step))) * 0.7071;
	Out += (t>tex2D(ShadowMapSampler, texc + float2(-step, -step))) * 0.7071;

	Out /= 2 + 4 + 4*(0.7071);
	return Out;
}

float ShadowBrightness(float2 ShadowMapPos, float DepthRef){
	float comp;
	if(parthf && (ShadowMapPos.y<SOFTSHADOW_DISTANCE)){
		comp = MMDShadowBrightness(ShadowMapPos, DepthRef);
	}
	else{
		comp = 1-GetZBufSample(ShadowMapPos, DepthRef-SOFTSHADOW_THRESHOLD, 1);
	}
    return comp;
}
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////
// シャドウの明るさ計算
// 4点近傍PCFで、ジャギ軽減のみ
#if SOFTSHADOW==SOFTSHADOW_PCF_UNJAGGY
#define SHADER_VER(x) x##_3_0
float ShadowBrightness(float2 ShadowMapPos, float DepthRef){
	const float2 diff=fmod(ShadowMapPos, sampstep); // 偏差分を求める
	const float2 diffRate=diff/sampstep;

	const float2 OrigPos=ShadowMapPos-diff;

	float a=tex2D(ShadowMapSampler,OrigPos).r < DepthRef-0.0005;
	float b=tex2D(ShadowMapSampler,OrigPos+sampstep*float2(1,0)).r < DepthRef-0.0005;
	float c=tex2D(ShadowMapSampler,OrigPos+sampstep*float2(0,1)).r < DepthRef-0.0005;
	float d=tex2D(ShadowMapSampler,OrigPos+sampstep*float2(1,1)).r < DepthRef-0.0005;

	float comp=diffRate.y*(diffRate.x*d + (1.0-diffRate.x)*c) + (1.0-diffRate.y)*(diffRate.x*b + (1.0-diffRate.x)*a);
	comp=pow(comp,1);
    return 1-comp;
}
#endif
////////////////////////////////////////////////////////////////////////////////////////////////////////////
// シャドウの明るさ計算
// ソフトシャドウ化を行わない MMD標準と同じ
#if SOFTSHADOW==SOFTSHADOW_NONE
#if FOG_ENABLE==1
#define SHADER_VER(x) x##_3_0
#else
#define SHADER_VER(x) x##_2_0
#endif
#define ShadowBrightness( pos, depth) MMDShadowBrightness(pos,depth)

#endif

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）
struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float4 ZCalcTex : TEXCOORD0;    // Z値
    float2 Tex      : TEXCOORD1;    // テクスチャ
    float3 Normal   : TEXCOORD2;    // 法線
    float3 Eye      : TEXCOORD3;    // カメラとの相対位置
    float2 SpTex    : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 Color    : COLOR0;       // ディフューズ色
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul(Pos,WorldViewProjMatrix);

    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	// ライト視点によるワールドビュー射影変換
    Out.ZCalcTex = mul(Pos, LightWorldViewProjMatrix);

    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
    return Out;
}

// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
    float4 Color = IN.Color;
    float4 ShadowColor = float4(AmbientColor, Color.a);  // 影の色
    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        Color *= TexColor;
        ShadowColor *= TexColor;
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) {
            Color.rgb += TexColor.rgb;
            ShadowColor.rgb += TexColor.rgb;
        } else {
            Color *= TexColor;
            ShadowColor *= TexColor;
        }
    }
    // スペキュラ適用
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    Color.rgb += Specular;

    float comp = 1;
    if(useToon){
		comp = saturate(dot(IN.Normal,-LightDirection)*Toon);
		ShadowColor.rgb *= MaterialToon;
	}

	IN.ZCalcTex/=IN.ZCalcTex.w;
	float2 ShadowMapPos;
	ShadowMapPos.x = (1.0 + IN.ZCalcTex.x)*0.5;
	ShadowMapPos.y = (1.0 - IN.ZCalcTex.y)*0.5;

	if( !any( saturate(ShadowMapPos) != ShadowMapPos ) ) {
		comp = min(comp, ShadowBrightness(ShadowMapPos.xy, IN.ZCalcTex.z));
	}
	Color = lerp(ShadowColor, Color, comp);
	// 毛の処理
	// 地肌の色
#ifdef SkinColor
	float3 skin = SkinColor;
#else
	float3 skin = Color.rgb;
#endif

	// 毛の色
#ifdef FurColor
	float3 fur = FurColor;
#else
	float3 fur = Color.rgb;
#endif
	Color.rgb=lerp(fur, skin, pow(abs(dot(normalize(IN.Eye),-normalize(IN.Normal))), FurPower));
    if( transp ) Color.a *= 0.5f;
    return FogMix(Color, IN.Eye);
}

// オブジェクト描画用テクニック
// 不要なものは削除可
#define SELFSHADOW_TEC_TEX(name, sphere, toon) \
	technique name < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = sphere; bool UseToon = toon; \
		string Script = \
			"RenderColorTarget=UseMipmapObjectTexture;" \
				"RenderDepthStencilTarget=UMOTDepth;" \
					"ClearSetColor=ClearColor;" \
					"ClearSetDepth=ClearDepth;" \
					"Clear=Color;" \
					"Clear=Depth;" \
				"Pass=CreateMipmap;" \
			"RenderColorTarget=;" \
				"RenderDepthStencilTarget=;" \
				"Pass=DrawObject;" \
		; \
	> { \
		pass CreateMipmap < string Script= "Draw=Buffer;"; >{ \
			AlphaBlendEnable = false; \
			ZEnable = false; \
			VertexShader = compile vs_2_0 CopyTex_VS(MipmapOffset); \
			PixelShader  = compile ps_2_0 CopyTex_PS(OrgObjTexSampler); \
		} \
		pass DrawObject { \
			VertexShader = compile SHADER_VER(vs) BufferShadow_VS(true, sphere, toon); \
			PixelShader  = compile SHADER_VER(ps) BufferShadow_PS(true, sphere, toon); \
		} \
	}
#define SELFSHADOW_TEC_NOTEX(name, sphere, toon) \
	technique name < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = sphere; bool UseToon = toon; \
	> { \
		pass DrawObject { \
			VertexShader = compile SHADER_VER(vs) BufferShadow_VS(false, sphere, toon); \
			PixelShader  = compile SHADER_VER(ps) BufferShadow_PS(false, sphere, toon); \
		} \
	}

SELFSHADOW_TEC_TEX(BSTec0, false, false)
SELFSHADOW_TEC_TEX(BSTec1, true,  false)
SELFSHADOW_TEC_TEX(BSTec2, false, true)
SELFSHADOW_TEC_TEX(BSTec3, true,  true)

SELFSHADOW_TEC_NOTEX(BSTec4, false, false)
SELFSHADOW_TEC_NOTEX(BSTec5, true,  false)
SELFSHADOW_TEC_NOTEX(BSTec6, false, true)
SELFSHADOW_TEC_NOTEX(BSTec7, true,  true)

///////////////////////////////////////////////////////////////////////////////////////////////
