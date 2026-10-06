#define USE_HI

//フレネル比
float refractiveRatio = 1.000292f / 1.3334f;


//時間
float time : TIME;
// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 ViewProjMatrix      : VIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 InvWorldMatrix              : WORLDINVERSE;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;
float4x4 CameraWorldMatrix : WORLD < string Object = "Camera"; >;
float4x4 InvViewProjMatrix : VIEWPROJECTIONINVERSE;
float4x4	InvViewMatrix		: VIEWINVERSE;
float4x4	InvProjMatrix		: PROJECTIONINVERSE;
float4x4 ProjMatrix		: PROJECTION;

#define BUF_FORMAT "D3DFMT_A16B16G16R16F"
#define TEX_SIZE 1024
//#define MIRROR_SIZE 1024		//（修正箇所）使わないのでコメントアウト
//#define UNDER_W_SIZE 1024		//（修正箇所）使わないのでコメントアウト
#define HITTEX_SIZE 1024
#define HITPIX (1.0/HITTEX_SIZE)

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5f, 0.5f)/ViewportSize);
float3   LightDirection    : DIRECTION < string Object = "Light"; >;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
float Si : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

#define F2DC "fluid2DController.pmx"
float mOuterScale : CONTROLOBJECT < string name = F2DC; string item = "外周広さ"; >;
float mWaveScale : CONTROLOBJECT < string name = F2DC; string item = "生成波強さ"; >;
float mWaveSpd : CONTROLOBJECT < string name = F2DC; string item = "生成波速度"; >;
float mSeaPower : CONTROLOBJECT < string name = F2DC; string item = "さざ波強さ"; >;
float mSeaScale : CONTROLOBJECT < string name = F2DC; string item = "さざ波細かさ"; >;
float mWaveHeight : CONTROLOBJECT < string name = F2DC; string item = "生成波高さ"; >;
float mGeoScale : CONTROLOBJECT < string name = F2DC; string item = "さざ波高さ"; >;
float mWaterMoveXp : CONTROLOBJECT < string name = F2DC; string item = "流れX+"; >;
float mWaterMoveXm : CONTROLOBJECT < string name = F2DC; string item = "流れX-"; >;
float mWaterMoveYp : CONTROLOBJECT < string name = F2DC; string item = "流れY+"; >;
float mWaterMoveYm : CONTROLOBJECT < string name = F2DC; string item = "流れY-"; >;
float mFogScale : CONTROLOBJECT < string name = F2DC; string item = "フォグ距離"; >;
float mFogR : CONTROLOBJECT < string name = F2DC; string item = "フォグR"; >;
float mFogG : CONTROLOBJECT < string name = F2DC; string item = "フォグG"; >;
float mFogB : CONTROLOBJECT < string name = F2DC; string item = "フォグB"; >;
float mBubbleR : CONTROLOBJECT < string name = F2DC; string item = "泡R"; >;
float mBubbleG : CONTROLOBJECT < string name = F2DC; string item = "泡G"; >;
float mBubbleB : CONTROLOBJECT < string name = F2DC; string item = "泡B"; >;
float mMirrorScale : CONTROLOBJECT < string name = F2DC; string item = "鏡面強さ"; >;
float mLighting : CONTROLOBJECT < string name = F2DC; string item = "ライティング強さ"; >;
float mSpecularScale : CONTROLOBJECT < string name = F2DC; string item = "スペキュラ強さ"; >;



//アドオン
bool bCausticsAddon : CONTROLOBJECT < string name = "Caustics_Addon.x";>;

static float2 WaterMove = float2(mWaterMoveXp - mWaterMoveXm,mWaterMoveYp - mWaterMoveYm);
static float OUTERSCALE = 200 * mOuterScale;

static float4 FogCol = float4(mFogR,mFogG,mFogB,1);
float FogStart = 0;
static float FogEnd = 0.1+500*mFogScale;
static float WaterHightScale = mWaveHeight*1;
static float WaveScale = mWaveScale*5;

//計算によるさざ波作成
static float SeaScale = mSeaScale*10;
static float SEA_HEIGHT = mSeaPower*4;
static float SEA_GEOMETRYSCALE = 0.1*(mGeoScale*4);
static const float2x2 octave_m = float2x2(1.6, 1.2, -1.2, 1.6);

float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

//フィルタエフェクトインクルード
#include "sub/Gaussian.fx"

float4x4 inverseDir(float4x4 mat){
    return float4x4(
        mat._11, mat._21, mat._31, 0,
        mat._12, mat._22, mat._32, 0,
        mat._13, mat._23, mat._33, 0,
        0,0,0,1
    );
}

float4x4 inverse(float4x4 mat){
    float4x4 mv={
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        -mat._41, -mat._42, -mat._43, 1
    };

    return mul(mv,inverseDir(mat));
}


//マスク
texture MaskTex
<
   string ResourceName = "Texture/mask.png";
>;
sampler MaskSamp = sampler_state
{
	Texture = <MaskTex>;
    Filter = NONE;
    AddressU = Wrap;
    AddressV = Wrap;
};

//泡
texture BubbleTex
<
   string ResourceName = "Texture/Bubble.png";
>;
sampler BubbleSamp = sampler_state
{
	Texture = <BubbleTex>;
    Filter = NONE;
    AddressU = Wrap;
    AddressV = Wrap;
};

//水面のデータ計算用テクスチャ
texture CalcTex1 : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format= BUF_FORMAT;
>;
sampler CalcSamp1 = sampler_state
{
	Texture = <CalcTex1>;
    Filter = NONE;
    AddressU = CLAMP;
    AddressV = CLAMP;
};
texture CalcTex2 : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format= BUF_FORMAT;
>;
sampler CalcSamp2 = sampler_state
{
	Texture = <CalcTex2>;
    Filter = NONE;
    AddressU = CLAMP;
    AddressV = CLAMP;
};
//水面泡描画用テクスチャ
texture WaterBubbleTex : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format= BUF_FORMAT;
>;
sampler WaterBubbleSamp = sampler_state
{
	Texture = <WaterBubbleTex>;
    Filter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
};
texture WaterBubbleTexBuf : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format= BUF_FORMAT;
>;
sampler WaterBubbleBufSamp = sampler_state
{
	Texture = <WaterBubbleTexBuf>;
    Filter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

//水面のデータ保持用テクスチャ
shared texture BufTex : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format= BUF_FORMAT;
>;
sampler BufSamp = sampler_state
{
	Texture = <BufTex>;
    Filter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
};
//水面のデータ保持用テクスチャ
shared texture BufTexBlur : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format= BUF_FORMAT;
>;
sampler BufSampBlur = sampler_state
{
	Texture = <BufTexBlur>;
    Filter = LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};
//インナー領域のさざなみ高さ保持用テクスチャ
texture HeightTex : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format= BUF_FORMAT;
>;
sampler HeightSamp = sampler_state
{
	Texture = <HeightTex>;
    Filter = LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};
//のワーク領域
texture HeightTexWork : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format= BUF_FORMAT;
>;
sampler HeightSampWork = sampler_state
{
	Texture = <HeightTexWork>;
    Filter = LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};
//法線情報を保存するテクスチャー
shared texture NormalTex : RenderColorTarget
<
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
   string Format= BUF_FORMAT;
>;
sampler NormalSampler = sampler_state
{
	Texture = <NormalTex>;
    Filter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

//火線をカメラから記録するテクスチャ（Caustics_Addon用）
shared texture2D CameraCausTex : RENDERCOLORTARGET;
sampler2D CameraCausSamp = sampler_state {
    texture = <CameraCausTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};



//作業用深度バッファ
texture Data_DepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_SIZE;
   int Height=TEX_SIZE;
    string Format = "D24S8";
>;

//水面までの距離記録用
shared texture SurfaceDepTex : RenderColorTarget
<
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 1, 1, 1, 1 };
   string Format= "R16F";
>;
sampler SurfaceDepSamp = sampler_state
{
	Texture = <SurfaceDepTex>;
    Filter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

//当たり判定用RT
texture HitRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for fluid2D";
    int Width = HITTEX_SIZE;
    int Height = HITTEX_SIZE;
    string Format = "A16B16G16R16F" ;
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "*=sub/VelocityMap.fx;";
>;
sampler HitView = sampler_state {
    texture = <HitRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//マップ格納情報から速度ベクトルを得る
float3 MB_VelocityPreparation(float4 rawvec){

    float3 vel = rawvec.xyz;
    float len = length(vel);
    vel = max(0, len - 0.04) * normalize(vel);
    
    float Threshold = 0.12;
    vel = min(vel, float3(Threshold, Threshold, Threshold));
    vel = max(vel, float3(-Threshold, -Threshold, -Threshold));
    
    return vel * 0.1;
}

//---水面下用テクスチャ---
//水面下、画像用RT
shared texture UnderObjectsRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for fluid2D";
    
   //int Width=UNDER_W_SIZE;
   //int Height=UNDER_W_SIZE;
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    string Format = "A16B16G16R16F" ;
    bool AntiAlias = true;
    
    
    string DefaultEffect = 
        "self = hide;"
        "*=sub/UnderColor.fx;";
>;
sampler UnderViewNoFilter = sampler_state {
    texture = <UnderObjectsRT>;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler UnderView = sampler_state {
    texture = <UnderObjectsRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//水面下、法線用RT
shared texture UnderDataRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for fluid2D";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "*=sub/UnderObject.fx;";
>;
sampler UnderNormalView = sampler_state {
    texture = <UnderDataRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//水面下、座標用RT
shared texture UnderPos: RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    string Format = "A16B16G16R16F" ;
>;

sampler UnderPosViewNoFilter = sampler_state {
    texture = <UnderPos>;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler UnderPosView = sampler_state {
    texture = <UnderPos>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

//水面下判定保存用
shared texture2D UnderSaveTex : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    bool AntiAlias = false;
    string Format = "A8R8G8B8" ;
>;
sampler2D UnderSaveSamp = sampler_state {
    texture = <UnderSaveTex>;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


shared texture UnderSave_DepthBuffer : RenderDepthStencilTarget <
    float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
	float ClearDepth = 0.0;
	bool AntiAlias = false;
>;

shared texture UnderDepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1, 1};
	string Format = "D24S8";
	float ClearDepth = 0.0;
	bool AntiAlias = false;
	int Miplevels = 1;
>;
//---

//---鏡面用テクスチャ---
texture MirrorRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for fluid2D";
    //int Width = MIRROR_SIZE;			//（修正箇所）使わないのでコメントアウト
    //int Height = MIRROR_SIZE;			//（修正箇所）使わないのでコメントアウト
    float2 ViewportRatio = {2.0, 2.0};	//（修正箇所）テクスチャサイズを描画サイズの2倍に設定。
    string Format = "A16B16G16R16F" ;
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "*= sub/MirrorColor.fx;";
>;
//鏡面用深度RT
texture MirrorDepth: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for fluid2D";
    //int Width = MIRROR_SIZE;			//（修正箇所）使わないのでコメントアウト
    //int Height = MIRROR_SIZE;			//（修正箇所）使わないのでコメントアウト
    float2 ViewportRatio = {2.0, 2.0};	//（修正箇所）テクスチャサイズを描画サイズの2倍に設定。
    string Format = "R16F" ;
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "*= sub/MirrorDepth.fx;";
>;

sampler MirrorView = sampler_state {
    texture = <MirrorRT>;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
sampler MirrorDepthView = sampler_state {
    texture = <MirrorDepth>;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
shared texture MirrorDepthBuffer : RENDERDEPTHSTENCILTARGET <
    //int Width = MIRROR_SIZE;			//（修正箇所）使わないのでコメントアウト
    //int Height = MIRROR_SIZE;			//（修正箇所）使わないのでコメントアウト
    float2 ViewportRatio = {2.0, 2.0};	//（修正箇所）テクスチャサイズを描画サイズの2倍に設定。
	string Format = "D24S8";
	float ClearDepth = 0.0;
	bool AntiAlias = false;
	int Miplevels = 1;
>;
//---


// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {}
// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {}
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {}
// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

#include "sub/WaterNormal.fxsub"

//フレネル計算
float CalcFresnel(float3 View,float3 Normal)
{
	float A = refractiveRatio;
    float B = dot(-normalize(View), normalize(Normal));
    float C = sqrt(1.0f - A*A * (1-B*B));
    float Rs = (A*B-C) * (A*B-C) / ((A*B+C) * (A*B+C));
    float Rp = (A*C-B) * (A*C-B) / ((A*C+B) * (A*C+B));
    float alpha = (Rs + Rp) / 2.0f;
    
    alpha = min( alpha, 1.0f);
    return alpha;
}


struct VS_OUT {
	float4 Pos      : POSITION;     // 射影変換座標
	float2 Tex      : TEXCOORD1;    // テクスチャ
	float4 LastPos  : TEXCOORD2;
	float3 Normal	: TEXCOORD3;
	float3 WPos		: TEXCOORD4;
	float4 Pos0		: TEXCOORD5;	//（修正箇所）波を加える前のエフェクト頂点射影変換座標。
};

// 頂点シェーダ
VS_OUT Main_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUT Out = (VS_OUT)0;
	float2 BGTex = Tex-0.5;
	float4 tmpPos = Pos;
	
	//高さ情報取得
	float4 data = tex2Dlod(BufSampBlur,float4(Tex,0,0));
	float height = data.b*0.25*WaterHightScale*2;
	height -= tex2Dlod(HeightSamp,float4(Tex,0,0)).r*0.1;
	Pos.y -= height * (1.0 - abs(BGTex.x * 2)) * (1.0 - abs(BGTex.y * 2));
	
	//Pos.y = max(-0.001,Pos.y);
	//Pos.y = min(0.01,Pos.y);
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.LastPos = Out.Pos;
	Out.Pos0 = mul( tmpPos, WorldViewProjMatrix );	//（修正箇所）鏡面の画像は波高を加える前に行われるので、加える前の座標をPSに出力。
    Out.WPos = mul( Pos,WorldMatrix);
    //UV値
	Out.Tex = Tex;
	//法線
	Out.Normal = mul(Normal,WorldMatrix);
	
    return Out;
}
//画面ピクセル座標計算
float3 GetPixelPos(float2 tex)
{
	tex = tex * 2 - 1;
	tex.y *= -1;
    float2 sp = tex;

    float4 ndcray = float4(tex.xy,1,1);
    float3 ray = mul(mul(ndcray,InvProjMatrix).xyz,InvViewMatrix);
    return CameraPosition + ray;
}
float CalcDepth(float2 tex)
{
	float3 pos = tex2D(UnderPosViewNoFilter,tex).rgb;	//（修正箇所）UnderPosViewNoFilterに変更することで水面上にあるモデル周囲のジャギが軽減される
	return length(pos - CameraPosition);
}

float4 PS_Surface(float2 BGTex,VS_OUT IN,bool bInner)
{
	float3 Eye = IN.WPos - CameraPosition;

	
	//----法線計算
	float3 	Normal = GetWaveNormal(BGTex*0.075+WaterMove*time*0.01, IN.Normal, normalize(Eye.xyz), IN.WPos,9);
	Normal = lerp(Normal,IN.Normal,smoothstep(100,10000,length(Eye))*0.5);
	[branch]
	if(bInner)
	{
		float3 WaveNormal = tex2D(NormalSampler,IN.Tex).rgb;
		Normal.rb += WaveNormal.rb*1;
	}
	Normal.g *= 0.02;
	Normal = normalize(Normal);
	//メイン用UV種
	float2 UVSeed = normalize(Normal).xz*0.1;
	//ライティング用法線
	float3 LightingNormal = Normal*float3(1,0.1,1);
	LightingNormal = normalize(mul(LightingNormal,WorldMatrix));
	
	//Normal = normalize(mul(Normal,WorldMatrix));

	float d_light = max(0,min(1,dot(Normal,-LightDirection)))*0.5+0.5;

	//d_light = (d_light < 0.5) ? 1 : 0;
	// スペキュラ色計算
    float3 HalfVector = normalize( normalize(-Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, LightingNormal )), 64 ) * LightSpecular*4*mSpecularScale;

	//水面下画像
	float2 UnderUV = float2((IN.LastPos.x/IN.LastPos.w + 1)*0.5,(-IN.LastPos.y/IN.LastPos.w + 1)*0.5)+ViewportOffset;

	float realDep = CalcDepth(UnderUV);
	float plane_depth = realDep - length(Eye);
	UVSeed *= saturate(plane_depth*0.1);

	//水面下深度
	float  UnderDepth;
	UnderDepth = CalcDepth(UnderUV + UVSeed);

	float4 UnderCol = tex2D(UnderViewNoFilter,UnderUV + UVSeed);	//（修正箇所）フィルターによるモデル周囲の色混入が目立つのでUnderViewNoFilterに変更。
	float4 UnderNor = tex2D(UnderNormalView,UnderUV + UVSeed);
	
	float3 NowDep = UnderDepth;

	[branch]
	if(NowDep.r - length(Eye) < 0)
	{
		UnderDepth = realDep;
		UnderCol = tex2Dlod(UnderViewNoFilter,float4(UnderUV,0,0));
		UnderNor = tex2Dlod(UnderNormalView,float4(UnderUV,0,0));
	}
	
	//鏡面画像
    float2 ScreenUV = float2( 0.75f - ( ( - IN.LastPos.x/IN.LastPos.w + 2 * IN.Pos0.x/IN.Pos0.w) + 1.0f ) * 0.25f,
                              0.75f - ( ( - IN.LastPos.y/IN.LastPos.w + 2 * IN.Pos0.y/IN.Pos0.w) + 1.0f ) * 0.25f ) + ViewportOffset * 0.5;
								//（修正箇所）波高による鏡像の変化を追加。鏡像の視野を画面の二倍に変更したので、それに合わせてUVを0.25～0.75に再計算。

	UVSeed *= 0.5;		//（修正箇所）鏡像の視野を二倍にしたので、波による鏡像のにじみに関連したUVSeedを0.5倍。

	float4 mirror_test = tex2D(MirrorView,ScreenUV + UVSeed);

	//鏡面画像
	float mirror_depth = tex2D(MirrorDepthView,ScreenUV + UVSeed*mirror_test.a).r;
	float4 MirrorCol = tex2D(MirrorView,ScreenUV + UVSeed*mirror_test.a);

	[branch]			//（修正箇所）波高による鏡像変化で水面上に突き出た部分を波高追加前の鏡像で置き換え。
	if(mirror_depth - length(Eye) < 0.0)
	{
		ScreenUV = float2( 0.75f - ( IN.LastPos.x/IN.LastPos.w + 1.0f ) * 0.25f,
                              0.75f - ( IN.LastPos.y/IN.LastPos.w + 1.0f ) * 0.25f ) + ViewportOffset * 0.5;

		mirror_depth = tex2Dlod(MirrorDepthView,float4(ScreenUV,0,0));
		MirrorCol = tex2Dlod(MirrorView,float4(ScreenUV,0,0));
	}

	//Normal = lerp(normalize(Normal),float3(0,1,0),0.75);
	//float d = saturate(dot(normalize(Normal),-normalize(Eye)));
	//d = 1-pow(1-d,6);
	//表裏判定
	//float3 PxPos = CameraPosition + ViewMatrix

	//スクリーン座標
	float2 ScPos = IN.LastPos.xy/IN.LastPos.w;
	float3 PxCam = GetPixelPos(ScPos);
	float3 PxEye = IN.WPos - PxCam;
	//GetPixelPos
	float flipd = dot(normalize(PxEye),IN.Normal) > 0 ? -1 : 1;

	//フォグ
	[branch]
	if(flipd > 0)
	{
		UnderCol = lerp(UnderCol,FogCol,smoothstep(FogStart,FogEnd,(UnderDepth - length(Eye))));
	}else{
		UnderCol = lerp(UnderCol,FogCol,smoothstep(FogStart,FogEnd,length(Eye)));
		MirrorCol = lerp(MirrorCol,FogCol,smoothstep(FogStart,FogEnd,mirror_depth.r));
	}

	ScreenUV = 1.0f - ScPos * 0.5f + ViewportOffset;	//（修正箇所）鏡像用のUVから通常のScreenUVに戻す。

	//火線の描画
	[branch]
	if(flipd > 0 && bCausticsAddon)
	{
		ScreenUV.x = 1-ScreenUV.x;
		float3 caus = tex2Dlod(CameraCausSamp,float4(UnderUV,0,0)).rgb*2*LightSpecular;
		UnderCol.rgb += caus*smoothstep(FogEnd,FogStart,(UnderDepth - length(Eye)));
	}
	Eye *= flipd;
	float d = CalcFresnel(normalize(Eye),Normal);
	float mirrorscale = saturate(d*MirrorCol.a+(mMirrorScale*2-1));
	float4 LastColor = lerp(UnderCol,MirrorCol,mirrorscale);
	
	//LastColor.rgb = lerp(LastColor.rgb,BubbleColor.rgb,bubble*BubbleColor.r)*1;
	LastColor.rgb = lerp(LastColor.rgb*(1.0-mLighting),LastColor.rgb,d_light);
	LastColor.rgb += Specular;
	
	[branch]
	if(bInner)
	{
		//水面泡の描画
		float4 WaterBubbleColor = tex2Dlod(WaterBubbleSamp,float4(IN.Tex,0,0));
		LastColor.rgb = lerp(LastColor.rgb,WaterBubbleColor.rgb,WaterBubbleColor.a);
	}else{
		//外周の場合ぼかし
		LastColor.a *= smoothstep(OUTERSCALE*Si,0,length(Eye));
	}
	
	return LastColor;
}
//ピクセルシェーダ
float4 Main_PS(VS_OUT IN) : COLOR
{
	float2 BGTex = (IN.Tex-0.5);
	float4 Color = PS_Surface(BGTex,IN,true);
	
	Color.a = tex2D(MaskSamp,IN.Tex).r;
	return Color;
}
VS_OUT Outer_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUT Out = (VS_OUT)0;
	//高さ情報取得
	//float height = 0;//tex2Dlod(BufSampBlur,float4(Tex,0,0)).b;
	//height += map(Tex*OUTERSCALE);
	//height *= WaterHightScale;
	//Pos.y -= height;
	//Pos.y = max(-0.001,Pos.y);
	//Pos.y = min(0.01,Pos.y);
    //Pos.y -= 0.01;
    // カメラ視点のワールドビュー射影変換
    Pos.xz *= OUTERSCALE;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.LastPos = Out.Pos;
	Out.Pos0 = Out.Pos;				//（修正箇所）Main_VSに合わせてPos0を出力。
    Out.WPos = mul(Pos,WorldMatrix);
    //UV値
	Out.Tex = Tex;
	//法線
	Out.Normal = mul(Normal,WorldMatrix);
	
    return Out;
}
//ピクセルシェーダ
float4 Outer_PS(VS_OUT IN) : COLOR
{
	float3 Eye = IN.WPos - CameraPosition;
	float2 BGTex = IN.Tex-0.5;
	BGTex *= OUTERSCALE;
	
	float clipchk = -1 * ((abs(BGTex.x) < 0.45) && (abs(BGTex.y) < 0.45));	//（修正箇所）内側をデフォルトでは0.495としているが、境目が見えるので0.45に変更
	clip(clipchk);
	
	return PS_Surface(BGTex,IN,false);
}

float4 SurfDepth_PS(VS_OUT IN,uniform bool bInner) : COLOR
{
	float2 BGTex = IN.Tex-0.5;
	BGTex *= OUTERSCALE;
	[branch]
	if(bInner)
	{
		float clipchk = -1 * ((abs(BGTex.x) < 0.45) && (abs(BGTex.y) < 0.45));	//（修正箇所）内側をデフォルトでは0.495としているが、境目が見えるので0.45に変更
		clip(clipchk);
	}
	return float4(length(IN.WPos - CameraPosition),0,0,1);
}


struct PS_IN_BUFFER
{
	float4 Pos : POSITION;
	float2 Tex : TEXCOORD0;
};
//バッファ処理用VS
PS_IN_BUFFER VS_Standard( float4 Pos: POSITION, float2 Tex: TEXCOORD )
{
   PS_IN_BUFFER Out;
   Out.Pos = Pos;
   Out.Tex = Tex + float2(0.5/TEX_SIZE, 0.5/TEX_SIZE);
   return Out;
}

#define PIXEL (1/TEX_SIZE)
#define DATA(x,y) GetData(BufSamp,IN.Tex,x,y)
#define DATA1(x,y) GetData(CalcSamp1,IN.Tex,x,y)
#define DATA2(x,y) GetData(CalcSamp2,IN.Tex,x,y)

float4 GetData(sampler samp,float2 now,float addx,float addy)
{
	float step = mWaveSpd*5;
	now += WaterMove*0.001;
	addx += WaterMove.x*0.001;
	addy += WaterMove.y*0.001;
	return tex2Dlod(samp,float4(now+float2(addx*step,addy*step)/TEX_SIZE,0,0));
}

//水面泡の描画
float4 PS_WaterBubble(PS_IN_BUFFER IN) : COLOR
{
	//水面データ
	float4 Data = tex2D(BufSamp,IN.Tex);
	//隣のデータ
	float4 Data2 = tex2D(BufSamp,IN.Tex+Data.xy);
	
	//泡量計算
	//隣のデータと比較した際の差分
	float bubble = length(Data.xy - Data2.xy);
	bubble = saturate(saturate(bubble*1)*2)*10;
	bubble = smoothstep(0,1,bubble);
	//return float4(bubble,0,0,1);
	
	//(smoothstep(0.4,1,abs(Data.x*1.0)+abs(Data.y*1.0)));
	float4 BubbleColor = tex2D(BubbleSamp,IN.Tex*64+Data.xy);
	BubbleColor.rgb = saturate(BubbleColor.rgb*1.5)*float3(1.0-mBubbleR,1.0-mBubbleG,1.0-mBubbleB);
	BubbleColor.a = bubble;
	

	//前Fの泡データ
	float4 PrevWaterBubble = tex2D(WaterBubbleBufSamp,IN.Tex);
	//現在の方が泡力が強ければ設置
	BubbleColor = PrevWaterBubble.a > BubbleColor.a ? PrevWaterBubble : BubbleColor;
	[branch]
	if(time == 0 || Tr == 0)
	{
		BubbleColor.a = 0;
	}
	//BubbleColor.a = saturate(BubbleColor.a);
	return BubbleColor;
}

//水面泡の移動とコピー
float4 PS_WaterBubbleCpy(PS_IN_BUFFER IN) : COLOR
{
	float4 Data = tex2D(BufSamp,IN.Tex);
	float4 BubbleColor = tex2D(WaterBubbleSamp,IN.Tex + Data.xy*0.1);

	BubbleColor.a *= 0.98f;
	[branch]
	if(time == 0 || Tr == 0)
	{
		BubbleColor.a = 0;
	}
	//BubbleColor.a = saturate(BubbleColor.a);
	return BubbleColor;
}

//流体計算
float4 PS_Fluid1( PS_IN_BUFFER IN ) : COLOR
{
	//RG:左右速度
	//B:密度
	
	float4 retData = DATA(0,0);
	//波リセット
	[branch]
	if(time == 0)
	{
		retData = float4(0,0,0,0);
	}else{
		//上下左右の速度を元に発散を計算
		retData.a = DATA(1,0).x-DATA(-1,0).x + DATA(0,1).y-DATA(0,-1).y;
		retData.z *= 0.999;
	}	
	return retData;
}

float4 PS_Fluid2_1( PS_IN_BUFFER IN ) : COLOR
{
	float4 retData = DATA1(0,0);
	[branch]
	if(time == 0) return retData;
	
	//圧力計算
	retData.z = (DATA1(-1,0).z + DATA1(1,0).z + DATA1(0,-1).z + (DATA1(0,1).z + -1.0 * retData.a)) * 0.25; 
	
	
	return retData;
}
float4 PS_Fluid2_2( PS_IN_BUFFER IN ) : COLOR
{
	float4 retData = DATA2(0,0);
	[branch]
	if(time == 0)
	{
		return retData;
	}
	//圧力計算
	retData.z = (DATA2(-1,0).z + DATA2(1,0).z + DATA2(0,-1).z + (DATA2(0,1).z - retData.a)) * 0.25;
	
	//if(IN.Tex.x > 0.999) retData.z = 0*abs(cos(time*10+sin(IN.Tex.y+time))); 
	//if(IN.Tex.x < 0.001) retData.z = -1.5*abs(cos(time*10+sin(IN.Tex.y+time))); 
	return retData;
}


float4 PS_Fluid3( PS_IN_BUFFER IN ) : COLOR
{
	float4 retData = DATA1(0,0);
	[branch]
	if(time == 0)
	{
		return float4(0,0,0,1);
	}
	//速度計算
	retData.x += (DATA1(-1,0).z - DATA1(1,0).z) * 0.5;
	retData.y += (DATA1(0,-1).z - DATA1(0,1).z) * 0.5;
	
	
	retData.a = 1;
	return retData;
}


//コピー
struct PS_COPY_AND_NORMAL
{
	float4 Color : COLOR0;
	float4 Normal : COLOR1;
	float4 Height : COLOR2;
};

float dt : ELAPSEDTIME;

PS_COPY_AND_NORMAL PS_Copy( PS_IN_BUFFER IN ) : COLOR
{
	PS_COPY_AND_NORMAL Out;
	float2 BGTex = IN.Tex-0.5;
	float4 retData = DATA2(0,0);
	
	//乱流
	retData.xy = tex2D(CalcSamp2,IN.Tex+retData.xy*dt*5);
	
	//速度減衰
	retData.xy -= retData.xy*dt*0.1;
	//retData.xy *= 0.999;
	
	//retData.xy += float2(cos(IN.Tex.x*64+time*16)*3,sin(-IN.Tex.y*48-time*16)*3)*0.0001;
	//ヒット情報
	float4 Hit = tex2D(HitView,IN.Tex*float2(1,1));
	float3 vel = MB_VelocityPreparation(Hit);
	
	retData.xy += WaterMove*0.001;
	//障害物
	//retData.xy *= lerp(1,0,Hit.a);
	
	
	//波生成(XZ)
	retData.xy += vel*WaveScale;

	
	//波生成(Y)
	//隣接データ取得
	float zx0 = MB_VelocityPreparation(tex2D(HitView,IN.Tex*float2(1,1)+float2( HITPIX*2,0))).z;
	float zx1 = MB_VelocityPreparation(tex2D(HitView,IN.Tex*float2(1,1)+float2(-HITPIX*2,0))).z;
	float zy0 = MB_VelocityPreparation(tex2D(HitView,IN.Tex*float2(1,1)+float2( 0,HITPIX*2))).z;
	float zy1 = MB_VelocityPreparation(tex2D(HitView,IN.Tex*float2(1,1)+float2(0,-HITPIX*2))).z;
	
	float z_scale = WaveScale;
	retData.xy += zx0*float2( 1, 0)*z_scale;
	retData.xy += zx1*float2(-1, 0)*z_scale;
	retData.xy += zy0*float2( 0, 1)*z_scale;
	retData.xy += zy1*float2( 0,-1)*z_scale;
	
	//とりあえず触れてたらちょっとは出す		
	//retData.xy += Hit.a*0.1*cos(time*56.789+IN.Tex.x*12.345+IN.Tex.y*34.567)*float2(cos(time*12.345+IN.Tex.x*34.567),sin(time*34.567+IN.Tex.y*12.345));
	
	//float block = tex2D(ZeroSamp,IN.Tex).r;
	//retData.xy *= block != 1;
		
	//フチに近づくほどフェード波を弱くする
	retData.xyz *= 1-pow(1-smoothstep(1,0,length(IN.Tex-float2(0.5,0.5))),2);
	//!(IN.Tex.x > 0.995 || IN.Tex.y > 0.995 || IN.Tex.x < 0.005 || IN.Tex.y < 0.005);
	
	Out.Color = retData;
	
	float3 WPos = mul(float3(BGTex.x,0,BGTex.y),WorldMatrix);
	float3 Eye = WPos - CameraPosition;
	float SeaHeight = abs(GetWaveHeight(BGTex*0.075+WaterMove*time*0.01, mul(float3(0,1,0),WorldMatrix), normalize(Eye.xyz), WPos,2))*1;
	Out.Height = float4(SeaHeight*1*(mGeoScale),0,0,1);
	//Out.Color.a = SeaHeight*1*(mGeoScale);
	
	//----法線計算
	float outer = 1.0 - pow(1.0 - ((1.0 - abs(BGTex.x * 2)) * (1.0 - abs(BGTex.y * 2))),2);
	float HeightHx = (DATA2(1, 0).z - DATA2( -1 ,0).z) * 3.0 * outer;
	float HeightHy = (DATA2( 0,1).z - DATA2( 0 ,-1).z) * 3.0 * outer;

	float3 AxisU = { 1.0, HeightHx, 0.0 };
	float3 AxisV = { 0.0, HeightHy, 1.0 };

	float3 Normal = (normalize( cross( AxisU, AxisV ) ) ) + 0.5;
	
	
	Normal.rb = Normal.rb * 2.0 - 1.0;
	Normal.g = 0.1;	
	
	Out.Normal = float4(Normal,1);
	
	return Out;
}
//水面下判定保存
PS_IN_BUFFER VS_UnderSave( float4 Pos: POSITION, float2 Tex: TEXCOORD )
{
   PS_IN_BUFFER Out = (PS_IN_BUFFER)0; 
   Out.Pos = Pos;
   Out.Tex = Tex;// + float2(0.5/TEX_SIZE, 0.5/TEX_SIZE);
   return Out;
}


float4 PS_UnderSave(float2 Tex : TEXCOORD0) : COLOR
{
	float4 cPos = float4(GetPixelPos(Tex),1);
	
	//現pxにおける水面の座標
	float2 BGTex = cPos.xz/(Si);
	BGTex.y *= -1;
	float2 OriginTex = saturate(BGTex + 0.5);
	//高さ情報取得
	float4 data = tex2Dlod(BufSampBlur,float4(OriginTex,0,0));
	float height = data.b*0.25;
	height -= tex2Dlod(HeightSamp,float4(OriginTex,0,0)).r*0.1;
	
	float4 pos = float4(0,0,0,1);
	pos.y -= height * (1.0 - saturate(abs(BGTex.x * 2))) * (1.0 - saturate(abs(BGTex.y * 2)));
	//pos = mul(pos,WorldMatrix);
	cPos = mul(cPos,InvWorldMatrix);
	return float4((cPos.y < pos.y),0,0,1);
}

//鏡面のコピー
/*
PS_IN_BUFFER VS_BasePass( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float2 TexSize )
{
	PS_IN_BUFFER Out = (PS_IN_BUFFER)0; 
	
	Out.Pos = Pos;
	Out.Tex = Tex.xy + 0.5/TexSize;
	
	return Out;
}
float4 PS_TexCopy(float2 Tex : TEXCOORD0) : COLOR
{
	float4 col = tex2D(ScreenView,Tex);
	float4 Mirror = tex2D(MirrorView,Tex);
	col = lerp(col,Mirror,Mirror.a);
	
	return col;
}
*/
// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1;

int LOOPNUM = 2;

technique MainTec < string MMDPass = "object"; string Subset = "0";
    string Script = 
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		
		//流体マップ更新(粘性項まで)	
        "RenderColorTarget0=CalcTex1;"
	    "RenderDepthStencilTarget=Data_DepthBuffer;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=FluidPass1;"
	    
		//流体マップ更新(ポアソンループ)
		
		
		"LoopByCount=LOOPNUM;"
		    
	        "RenderColorTarget0=CalcTex2;"
		    "RenderDepthStencilTarget=Data_DepthBuffer;"
			"Clear=Color;" "Clear=Depth;"
		    "Pass=FluidPass2_1;"
		    
	        "RenderColorTarget0=CalcTex1;"
		    "RenderDepthStencilTarget=Data_DepthBuffer;"
			"Clear=Color;" "Clear=Depth;"
		    "Pass=FluidPass2_2;"
	    
	    "LoopEnd=;"
		
	    //流体マップ更新(最終)	
        "RenderColorTarget0=CalcTex2;"
	    "RenderDepthStencilTarget=Data_DepthBuffer;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=FluidPass3;"
	    
		//マップコピー、法線計算(MRT)
        "RenderColorTarget0=BufTex;"
        "RenderColorTarget1=NormalTex;"
        "RenderColorTarget2=HeightTex;"
	    "RenderDepthStencilTarget=Data_DepthBuffer;"
		"Clear=Color;" "Clear=Depth;"
	    "Pass=CopyPass;"
        "RenderColorTarget1=;"
	    "RenderColorTarget2=;"
	    
	    //水面のぼかし
        "RenderColorTarget0=CalcTex1;"
        "RenderColorTarget1=HeightTexWork;"
	    "RenderDepthStencilTarget=Data_DepthBuffer;"
		"Clear=Color;"	"Clear=Depth;"
	    "Pass=Gaussian_X;"
        "RenderColorTarget0=BufTexBlur;"
        "RenderColorTarget1=HeightTex;"
	    "RenderDepthStencilTarget=Data_DepthBuffer;"
		"Clear=Color;"	"Clear=Depth;"
	    "Pass=Gaussian_Y;"
	    
        "RenderColorTarget1=;"
        
    	//水面に泡を描画する
        "RenderColorTarget0=WaterBubbleTex;"
	    "RenderDepthStencilTarget=Data_DepthBuffer;"
		"Clear=Color;"	"Clear=Depth;"
		
    	"Pass=WaterBubblePass1;"
    	//バッファテクスチャにコピー
        "RenderColorTarget0=WaterBubbleTexBuf;"
	    "RenderDepthStencilTarget=Data_DepthBuffer;"
		"Clear=Color;"	"Clear=Depth;"
		
    	"Pass=WaterBubblePass2;"
    	
	    //外周描画
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=OuterPass;"
	    
		//水面描画
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=MainPass;"
	    
	    //外周深度描画
        "RenderColorTarget0=SurfaceDepTex;"
	    "RenderDepthStencilTarget=UnderSave_DepthBuffer;"
		"Clear=Color;"	"Clear=Depth;"
	    "Pass=SurfDepthPass2;"
	    
	    //水面深度描画
        "RenderColorTarget0=SurfaceDepTex;"
	    "RenderDepthStencilTarget=UnderSave_DepthBuffer;"
	    "Pass=SurfDepthPass1;"
	    
		//水面下判定保存
        "RenderColorTarget0=UnderSaveTex;"
	    "RenderDepthStencilTarget=UnderSave_DepthBuffer;"
	    "Pass=UnderSavePass;"
    ;
>
{
/*
    pass SaveMirror  < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = TRUE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 VS_BasePass(MIRROR_SIZE);
        PixelShader  = compile ps_3_0 PS_TexCopy();
    }
*/

    pass SurfDepthPass1{
		ALPHABLENDENABLE = TRUE;
		ZENABLE = TRUE;
		ZWRITEENABLE = TRUE;
		CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS();
        PixelShader  = compile ps_3_0 SurfDepth_PS(false);
    }
    pass SurfDepthPass2{
		ALPHABLENDENABLE = TRUE;
		ZENABLE = TRUE;
		ZWRITEENABLE = TRUE;
		CULLMODE = NONE;
        VertexShader = compile vs_3_0 Outer_VS();
        PixelShader  = compile ps_3_0 SurfDepth_PS(true);
    }
    pass UnderSavePass  < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = TRUE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 VS_UnderSave();
        PixelShader  = compile ps_3_0 PS_UnderSave();
    }
	//流体計算1(～粘性項）
    pass FluidPass1 < string Script = "Draw=Buffer;";>{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_3_0 VS_Standard();
	    PixelShader = compile ps_3_0 PS_Fluid1();
    }
    //流体計算2(ポアソンループ）
    pass FluidPass2_1 < string Script = "Draw=Buffer;";>{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_3_0 VS_Standard();
	    PixelShader = compile ps_3_0 PS_Fluid2_1();
    }
    pass FluidPass2_2 < string Script = "Draw=Buffer;";>{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_3_0 VS_Standard();
	    PixelShader = compile ps_3_0 PS_Fluid2_2();
    }
    
    //流体計算3(最終値）
    pass FluidPass3 < string Script = "Draw=Buffer;";>{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_3_0 VS_Standard();
	    PixelShader = compile ps_3_0 PS_Fluid3();
    }
    //バッファにコピー
    pass CopyPass < string Script = "Draw=Buffer;";>{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_3_0 VS_Standard();
	    PixelShader = compile ps_3_0 PS_Copy();
    }
    
    //水面泡描画
    pass WaterBubblePass1 < string Script = "Draw=Buffer;";>{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_3_0 VS_Standard();
	    PixelShader = compile ps_3_0 PS_WaterBubble();
    }
    pass WaterBubblePass2 < string Script = "Draw=Buffer;";>{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
	    VertexShader = compile vs_3_0 VS_Standard();
	    PixelShader = compile ps_3_0 PS_WaterBubbleCpy();
    }
    
    //最終描画
    pass MainPass {
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS();
        PixelShader  = compile ps_3_0 Main_PS();
    }
    pass OuterPass {
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Outer_VS();
        PixelShader  = compile ps_3_0 Outer_PS();
    }
    
    //ガウスブラー(水面処理専用）
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passX();
        PixelShader  = compile ps_3_0 PS_passX2(BufSamp,HeightSamp,1);
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passY();
        PixelShader  = compile ps_3_0 PS_passY2(CalcSamp1,HeightSampWork,1);
    }
}































