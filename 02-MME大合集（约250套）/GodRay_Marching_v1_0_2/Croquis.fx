////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Croquis.fx v0.12
//  データP
//  mod: less
//
////////////////////////////////////////////////////////////////////////////////////////////////

// 設定項目 ////////////////////////////////////////////////////////////////////////////////////
/**
 * 色差エッジの有効化
 */
#define USE_COLOR_TRACE_EDGE

/**
 * 色差エッジの有効化
 */
#define USE_COLOR_DIFFERENCE_EDGE

/**
 * エッジ最終出力の太さ倍率
 *
 * 数値が大きい程太くなります。
 * 1で標準。
 */
#define EDGE_SCALE 1

/**
 * AOエッジ強調による太さの倍率
 *
 * 数値が大きい程太さが強調されます。
 * 1で標準。
 */
#define AO_EDGE_SCALE 1

/**
 * エッジ太さテクスチャを利用する
 *
 * ここが有効になっていない場合、CM_EdgeStrengthMapタブで
 * エッジ太さテクスチャを使うfxを適用していても無視されます。
* (CM_EdgeStrengthMapタブが消えます)
 */
#define USE_EDGE_STRENGTH_TEXTURE

/**
 * エッジ太さテクスチャによる太さの倍率
 *
 * 数値が大きい程太さが強調されます。
 * 1で標準。
 */
#define EDGE_STRENGTH_SCALE 1;

/**
 * バックバッファーのアンチエイリアス処理
 *
 * true: アンチエイリアスをかける / false: アンチエイリアスをかけない
 *
 * アンチエイリアスをかけたほうが出力は滑らかにになりますが、
 * より多くのVRAM(ビデオメモリ)を消費し、重くなります。
 * 高解像度出力から縮小する場合はこれをfalseにしていても十分綺麗だったりします。
 */
#define ANTI_ALIAS false

/**
 * バックバッファーの出力解像度に対するサイズ倍率
 *
 * 数値を大きくする程大きいバッファを確保しますが、
 * より激しい量のVRAM(ビデオメモリ)を消費し、泣きたくなるくらい重くなります。
 * 2のままでいいと思います。
 */
#define MapTimes 2

/**
 * 計算の元になる線の太さ
 *
 * 数値が大きい程太くなります。
 * 1で標準。
 */
float SobelSize <
	string UIName = "線太さ";
	string UIWidget = "Numeric";
	bool UIVisible =  true;
	float UIDefault = 1.0f;
> = 1.0f;

/**
 * 色トレスエッジを使わないときのエッジの色
 *
 * R(赤)、G(緑)、B(青)、A(透明度)の並びです。
 */
float4 FrontColor <
	string UIName = "線の色";
	string UIWidget = "Color";
	bool UIVisible =  true;
	float4 UIDefault = float4(0, 0, 0, 1);
> = float4( 0.0 , 0.0 , 0.0 , 1.0 );

/**
 * 地の色
 *
 * R(赤)、G(緑)、B(青)、A(透明度)の並びです。
 * これを (1, 1, 1, 1)にするとエッジのみの描画を出力できます。
 */
float4 BackColor <
	string UIName = "地の色";
	string UIWidget = "Color";
	bool UIVisible =  true;
	float4 UIDefault = float4(0, 0, 0, 0);
> = float4( 0 , 0 , 0 , 0 );

// 以下弄れる人以外スルーで ////////////////////////////////////////////////////////////////////
float4 ClearColor = float4(0, 0, 0, 0);

#define HalfDistance 50

////////////////////////////////////////////////////////////////////////////////////////////////
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

float3 Acc : CONTROLOBJECT <string name="(self)"; string item="XYZ";>;
float Tr : CONTROLOBJECT <string name="(self)"; string item="Tr";>;
float Si : CONTROLOBJECT <string name="(self)"; string item="Si";>;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

texture ColorMap : RENDERCOLORTARGET <
	string Format = "D3DFMT_A16B16G16R16F";
	float2 ViewPortRatio = {1,1};
>;
sampler ResultSampler = sampler_state {
	texture = <ColorMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
// カラーマップ
#ifdef USE_COLOR_TRACE_EDGE
texture CM_EdgeColorMap : OFFSCREENRENDERTARGET <
	string Description = "EdgeColorMap";
	string Format = "D3DFMT_A8R8G8B8";
	float2 ViewPortRatio = {1.0,1.0};
	float4 ClearColor = {0,0,0,0};
	float ClearDepth = 1.0;
	bool AntiAlias = ANTI_ALIAS;
	int Miplevels = 1;
	string DefaultEffect =
	    "self=hide;"
	    "*=EdgeColorDraw.fxsub;";
>;
sampler EdgeColorMapSampler = sampler_state {
	texture = <CM_EdgeColorMap>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
#endif

texture CM_ObjectColorMap : OFFSCREENRENDERTARGET <
	string Description = "ColorMap";
	string Format = "D3DFMT_A8R8G8B8";
	float2 ViewPortRatio = {MapTimes,MapTimes};
	float4 ClearColor = {0,0,0,0};
	float ClearDepth = 1.0;
	bool AntiAlias = ANTI_ALIAS;
	int Miplevels = 1;
	string DefaultEffect =
	    "self=hide;"
	    "*=ColorDraw.fxsub;";
>;
sampler ObjectColorMapSampler = sampler_state {
	texture = <ColorMap>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

#ifdef USE_EDGE_STRENGTH_TEXTURE
// エッジ太さマップ
texture CM_EdgeStrengthMap : OFFSCREENRENDERTARGET <
	string Description = "EdgeStrengthMap";
	string Format = "D3DFMT_R16F";
	float2 ViewPortRatio = {1.0,1.0};
	float4 ClearColor = {1,1,1,1};
	float ClearDepth = 1.0;
	bool AntiAlias = ANTI_ALIAS;
	int Miplevels = 1;
	string DefaultEffect =
	    "self=hide;"
	    "*=EdgeStrengthDraw.fxsub;";
>;
sampler EdgeStrengthMapSampler = sampler_state {
	texture = <CM_EdgeStrengthMap>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
#endif

// 法線マップ
texture CM_NormalMap : OFFSCREENRENDERTARGET <
	string Description = "NormalMap";
	string Format = "D3DFMT_A8R8G8B8";
	float2 ViewPortRatio = {MapTimes,MapTimes};
	float4 ClearColor = {0,0,1,0};
	float ClearDepth = 1.0;
	bool AntiAlias = ANTI_ALIAS;
	int Miplevels = 1;
	string DefaultEffect =
	    "self=hide;"
	    "*=NormalDraw.fxsub;";
>;
sampler NormalMapSampler = sampler_state {
	texture = <CM_NormalMap>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

// 深度マップ
texture CM_DepthMap : OFFSCREENRENDERTARGET <
	string Description = "DepthMap";
	string Format = "D3DFMT_R16F";
	float2 ViewPortRatio = {MapTimes,MapTimes};
	float4 ClearColor = {1,0,1,0};
	float ClearDepth = 1.0;
	bool AntiAlias = ANTI_ALIAS;
	int Miplevels = 1;
	string DefaultEffect =
		"self=hide;"
	    "*=DepthDraw.fxsub;";
>;
sampler DepthMapSampler = sampler_state {
	texture = <CM_DepthMap>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

// エッジを作った後の処理用
texture EdgeMap : RENDERCOLORTARGET <
	string Format = "D3DFMT_A16B16G16R16F";
	float2 ViewPortRatio = {MapTimes,MapTimes};
>;
texture2D EdgeDepth : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {MapTimes,MapTimes};
	string Format = "D24S8";
>;
sampler EdgeMapSampler = sampler_state {
	texture = <EdgeMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};


texture OrgSizeDepth : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1,1};
	string Format = "D24S8";
>;

//SSAOマップ取得
shared texture2D ExShadowSSAOMapOut : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "R16F";
>;

sampler2D ExShadowSSAOMapSamp = sampler_state {
    texture = <ExShadowSSAOMapOut>;
    MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
    AddressU  = CLAMP; AddressV = CLAMP;
};

bool Exist_ExShadowSSAO : CONTROLOBJECT < string name = "ExShadowSSAO.x"; >;

///////////////////////////////////////////////////////////////
// 汎用VS
struct CopyData {
	float4 Pos : POSITION;
	float2 Tex : TEXCOORD0;
};
struct Copy2Data {
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
};
float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static const float2 EdgeMapOffset = (float2(0.5,0.5)/(ViewportSize*MapTimes));
static const float2 PixelSize = (float2(1,1)/(ViewportSize));
static const float2 MapPixelSize = (float2(1,1)/(ViewportSize*MapTimes));

CopyData CopyVS(float4 Pos : POSITION, float2 Tex : TEXCOORD0, uniform float2 Offset){
	CopyData o;
	o.Pos = Pos;
	o.Tex = Tex + Offset;
	return o;
}

Copy2Data Copy2VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0, uniform float2 Offset0, uniform float2 Offset1){
	Copy2Data o;
	o.Pos = Pos;
	o.Tex0 = Tex + Offset0;
	o.Tex1 = Tex + Offset1;
	return o;
}


///////////////////////////////////////////////////////////////
// エッジを作る
float DepthFromPoint(float2 xy){
	float depth = tex2D(DepthMapSampler, xy).r;
	return depth;
}
float3 NormalFromPoint(float2 xy){
	float3 n=tex2D(NormalMapSampler, xy);
	return normalize(2*n.xyz-float3(1,1,1));
}

float4 ColorFromPoint(float2 xy){
	float4 c=tex2D(ObjectColorMapSampler, xy);
	return c;
}

float ddEdge(float2 xy){
	float3 oN=NormalFromPoint(xy);
	float oZ=DepthFromPoint(xy);
	float3 oC=ColorFromPoint(xy);

#if (0 < AO_EDGE_SCALE)
    if(Exist_ExShadowSSAO){
    	SobelSize *= 1 + tex2D(ExShadowSSAOMapSamp , xy).r * AO_EDGE_SCALE; //陰度加算
    }
#endif
	float EdgeStrength = 1.0f;
#ifdef USE_EDGE_STRENGTH_TEXTURE
	EdgeStrength = tex2D(EdgeStrengthMapSampler, xy).r * EDGE_STRENGTH_SCALE;
#endif

	float ColorPixelSize = MapPixelSize * SobelSize * Si * 0.2 * EDGE_SCALE * EdgeStrength; // 色差エッジとの太さ補正
	float3 dN1=NormalFromPoint(xy + float2(-1,0)*ColorPixelSize);
	float3 dN2=NormalFromPoint(xy + float2(0,-1)*ColorPixelSize);
	float3 dN3=NormalFromPoint(xy + float2(-1,1)*ColorPixelSize);
	float3 dN4=NormalFromPoint(xy + float2(-1,-1)*ColorPixelSize);

	float dZ1=DepthFromPoint(xy + float2(-1,0)*ColorPixelSize);
	float dZ2=DepthFromPoint(xy + float2(0,-1)*ColorPixelSize);
	float dZ3=DepthFromPoint(xy + float2(-1,1)*ColorPixelSize);
	float dZ4=DepthFromPoint(xy + float2(-1,-1)*ColorPixelSize);

	float ddN = dot(oN-dN1,oN-dN1) + dot(oN-dN2,oN-dN2) + 0.7*dot(oN-dN3,oN-dN3) + 0.7*dot(oN-dN4,oN-dN4);
	float4 ddZZ = float4(oZ-dZ1, oZ-dZ2, 0.7*(oZ-dZ3), 0.7*(oZ-dZ4));
	float ddZ = dot(ddZZ,ddZZ);

#ifdef USE_COLOR_DIFFERENCE_EDGE
	ColorPixelSize = MapPixelSize * SobelSize * Si * 0.1 * EDGE_SCALE * EdgeStrength;
	float4 dC1=ColorFromPoint(xy + float2(-1,-1)*ColorPixelSize);
	float4 dC2=ColorFromPoint(xy + float2(-1,0)*ColorPixelSize);
	float4 dC3=ColorFromPoint(xy + float2(-1,1)*ColorPixelSize);
	float4 dC4=ColorFromPoint(xy + float2(0,1)*ColorPixelSize);
	float4 dC5=ColorFromPoint(xy + float2(0,-1)*ColorPixelSize);
	float4 dC6=ColorFromPoint(xy + float2(1,1)*ColorPixelSize);
	float4 dC7=ColorFromPoint(xy + float2(1,0)*ColorPixelSize);
	float4 dC8=ColorFromPoint(xy + float2(1,-1)*ColorPixelSize);

	float4 cX = -dC1 - 2.0f * dC2 - dC3 + dC8 + 2.0f * dC7 + dC6;
	float4 cY = -dC1 - 2.0f * dC5 - dC8 + dC3 + 2.0f * dC4 + dC6;
	float4 ddC = pow(pow(cX, 2) + pow(cY, 2), 0.5);
#endif

//	return saturate(max(0,ddN-0.5)*2 + max(0,ddZ-0.0001)*7000 + max(0, ddC-0.02)*30);
#ifdef USE_COLOR_DIFFERENCE_EDGE
	return saturate(max(0,ddN-0.5)*2 * Acc.x + max(0,ddZ-0.0001)*7000 * Acc.y + length(ddC) * Acc.z);
#else
	return saturate(max(0,ddN-0.5)*2 + max(0,ddZ-0.0001)*7000);
#endif
}

float4 EdgePS(float2 Tex: TEXCOORD0):COLOR{
	return  float4((1.0 - ddEdge(Tex)*float3(1, 1, 1)), 1);
}

float4 MixPS(float2 Tex:TEXCOORD0, float2 MapTex:TEXCOORD1):COLOR{
	float e0=   0.25*tex2D(EdgeMapSampler,MapTex)
				+ 0.125*(tex2D(EdgeMapSampler,MapTex + float2(0,-1)*MapPixelSize)
						+ tex2D(EdgeMapSampler,MapTex + float2(0,1)*MapPixelSize)
						+ tex2D(EdgeMapSampler,MapTex + float2(1,0)*MapPixelSize)
						+ tex2D(EdgeMapSampler,MapTex + float2(-1,0)*MapPixelSize) )
				+ 0.0625*(tex2D(EdgeMapSampler,MapTex + float2(-1,-1)*MapPixelSize)
						+ tex2D(EdgeMapSampler,MapTex + float2(1,1)*MapPixelSize)
						+ tex2D(EdgeMapSampler,MapTex + float2(1,-1)*MapPixelSize)
						+ tex2D(EdgeMapSampler,MapTex + float2(-1,1)*MapPixelSize) );
	float4 color = lerp(FrontColor,BackColor,e0);
	float t = Tr*color.a;
	color.a=1;
	float4 SrcColor = tex2D(ResultSampler,Tex);
#ifdef USE_COLOR_TRACE_EDGE
	float4 EdgeColor = tex2D(EdgeColorMapSampler, MapTex);
#else
	float4 EdgeColor = color;
#endif
	EdgeColor = min(EdgeColor, SrcColor);
#ifdef USE_COLOR_TRACE_EDGE
	EdgeColor = 1 - ((1 - color) * (1 - EdgeColor));
	return lerp(SrcColor, EdgeColor ,t);
#else
	return lerp(SrcColor, color ,t);
#endif
}

float ClearDepth=1;
technique ComicEdgeTec <
	string Script = 
		"RenderColorTarget=ColorMap;"
		"RenderDepthStencilTarget=OrgSizeDepth;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		"RenderColorTarget=EdgeMap;"
		"RenderDepthStencilTarget=EdgeDepth;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=DrawEdge;"

		"RenderColorTarget=;"
		"RenderDepthStencilTarget=;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=DrawMix;"
	;
	>{
	pass DrawEdge < string Script= "Draw=Buffer;"; >{
		AlphaBlendEnable=false;
		AlphaTestEnable=false;
		ZWriteEnable=false;
		VertexShader = compile vs_3_0 CopyVS(EdgeMapOffset);
		PixelShader  = compile ps_3_0 EdgePS();
	}
	pass DrawMix < string Script= "Draw=Buffer;"; >{
		AlphaBlendEnable=false;
		AlphaTestEnable=false;
		ZWriteEnable=false;
		VertexShader = compile vs_3_0 Copy2VS(ViewportOffset, EdgeMapOffset);
		PixelShader  = compile ps_3_0 MixPS();
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////
