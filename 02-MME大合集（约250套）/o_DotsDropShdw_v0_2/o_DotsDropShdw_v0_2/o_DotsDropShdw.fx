//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　水玉ドロップシャドウエフェクト v0.2
//　　　by おたもん（user/5145841）
//
//　　　※このエフェクトはビームマンＰの DropShadow を改造したものです
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

//=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=
//　ユーザーパラメータ　ここから

//　ボカしモード（ 0：高速ですが水玉の縁が荒くなります　1：重くなりますが水玉の縁が綺麗になります[初期値]）
#define BLUR_MODE 1

//　半透明モード（ 0：水玉１つ１つに半透明度が適用されます　1：水玉全体に半透明度が適用されます[初期値]）
#define ALPHA_MODE 1

//　サイズ操作モード（ 0：アクセサリ Z で水玉の密度を変更　1：水玉のサイズを変更[初期値]）
#define ZPOS_MODE 1

//　グリッドサイズ ＝ 密度（初期値：0.02、推奨値範囲：0.01 ～ 0.05）
float GridSize<
	string UIName = "密度";
	string UIWidget = "Slider";
	bool UIVisible =  true;
	float UIMin = 0.01;
	float UIMax = 0.05;
> = 0.015;

//　グリッドサイズに対する水玉比率（大きいほど小さい　初期値：1/√2 ≒ 0.7071）
float DotsScale<
	string UIName = "●サイズ";
	string UIWidget = "Slider";
	bool UIVisible =  true;
	float UIMin = 1.0;
	float UIMax = 0.5;
> = 0.7071067811865475244;

//　水玉の色（MikuMikuMoving 専用）
#ifdef MIKUMIKUMOVING
float3 DotsColor<
	string UIName = "水玉の色";
	string UIWidget = "Color";
	bool UIVisible =  true;
	float3 UIMin = float3(0.0, 0.0, 0.0);
	float3 UIMax = float3(1.0, 1.0, 1.0);
> = float3(0.8, 0.0, 0.2);
#endif

//　ユーザーパラメータ　ここまで
//　ここから先はエフェクトに詳しい方向け
//=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=


//=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=
//　初期定義

//　アクセサリ操作設定値を取得
float  Scale	: CONTROLOBJECT < string name = "(self)"; string item="Si"; >;
float  Alpha	: CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float3 WorldPos : CONTROLOBJECT < string name = "(self)"; >;
float3 ObjRxyz	: CONTROLOBJECT < string name = "(self)"; string item = "Rxyz"; >;

static float3 ObjXYZ = WorldPos + 1.0;

//　ボカし幅
static float GauseParam = Scale * 0.75;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float  AspectRatio = (ViewportSize.x / ViewportSize.y);
static float2 halfPixel = float2(1.0, 1.0) / (ViewportSize * 2.0);
static float2 fullPixel = float2(1.0, 1.0) / (ViewportSize);
static float2 ViewportOffset = (float2(0.5,0.5) / ViewportSize);
static float2 SampStep = (float2(GauseParam,GauseParam) / ViewportSize);

//　レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

//　パターンテクスチャ
texture2D DotTex <
	string ResourceName = "dots.png";
	string Format  = "L8";
	int	   MipLevels = 1;
>;
sampler DotSamp = sampler_state {
	texture	 = <DotTex>;
	FILTER	 = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};


//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ドロップシャドウを描画するレンダリングターゲット

texture DotsShadowRT: OFFSCREENRENDERTARGET <
	string Description = "水玉ドロップシャドウを使いたいオブジェクトに drawDShdw.fx を割り当て\n使いたくないオブジェクトは左端のチェックを外してください";
	float4 ClearColor = {0, 0, 0, 0};
	float ClearDepth = 1.0;
	string Format = "A8R8G8B8";
	bool AntiAlias = true;
	string DefaultEffect = 
		"self = hide;"

		"*.pmd = drawDShdw.fx;"	//　PMD モデルは初期で適用
		"*.pmx = drawDShdw.fx;"	//　PMX モデルは初期で適用

		"* = hide;";
	>;
sampler DropMap = sampler_state {
	texture = <DotsShadowRT>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	Filter = LINEAR;
};

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
	texture	 = <ScnMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV  = CLAMP;
};

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp2 = sampler_state {
	texture	  = <ScnMap2>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV  = CLAMP;
};

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// Y方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap3 : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp3 = sampler_state {
	texture	  = <ScnMap3>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = BORDER;
	AddressV  = BORDER;
	BorderColor =  {0, 0, 0, 0};
};

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

//　マクロ定義
//　　ぼかし処理の重み係数
#define WT_0  0.0920246
#define WT_1  0.0902024
#define WT_2  0.0849494
#define WT_3  0.0768654
#define WT_4  0.0668236
#define WT_5  0.0558158
#define WT_6  0.0447932
#define WT_7  0.0345379

#define RADIAN 57.29578
#define fmRange	0.8f
//=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=
//　エフェクト処理関数

//　汎用VS
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// X方向ぼかし

VS_OUTPUT VS_passX(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	
	Out.Pos = Pos;
	Out.Pos.zw = 1.0;
	
	WorldPos.x *= -1.0;
	Tex.xy += WorldPos.xy * 0.01;
	Tex.xy += float2(-0.5, -0.5);
//	  Tex.xy *= 1.0+WorldPos.z*0.01;
	Tex.xy -= float2(-0.5, -0.5);
	Out.Tex = Tex + float2(0.0, ViewportOffset.y);
	
	return Out;
}

float4 PS_passX(float2 Tex: TEXCOORD0) : COLOR
{
	float4 Color;
	
	Color  = WT_0 *	 tex2D(DropMap, Tex );
	Color += WT_1 * (tex2D(DropMap, Tex + float2(SampStep.x	   , 0)) + tex2D(DropMap, Tex - float2(SampStep.x	 , 0)));
	Color += WT_2 * (tex2D(DropMap, Tex + float2(SampStep.x * 2, 0)) + tex2D(DropMap, Tex - float2(SampStep.x * 2, 0)));
	Color += WT_3 * (tex2D(DropMap, Tex + float2(SampStep.x * 3, 0)) + tex2D(DropMap, Tex - float2(SampStep.x * 3, 0)));
	Color += WT_4 * (tex2D(DropMap, Tex + float2(SampStep.x * 4, 0)) + tex2D(DropMap, Tex - float2(SampStep.x * 4, 0)));
	Color += WT_5 * (tex2D(DropMap, Tex + float2(SampStep.x * 5, 0)) + tex2D(DropMap, Tex - float2(SampStep.x * 5, 0)));
	Color += WT_6 * (tex2D(DropMap, Tex + float2(SampStep.x * 6, 0)) + tex2D(DropMap, Tex - float2(SampStep.x * 6, 0)));
	Color += WT_7 * (tex2D(DropMap, Tex + float2(SampStep.x * 7, 0)) + tex2D(DropMap, Tex - float2(SampStep.x * 7, 0)));
	
	return Color;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// Y方向ぼかし

VS_OUTPUT VS_passY(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	
	Out.Pos = Pos;
	Out.Pos.zw = 1.0;

	WorldPos.x *= -1.0;
	Tex.xy += WorldPos.xy * 0.01;
	Tex.xy += float2(-0.5, -0.5);
//	Tex.xy *= 1+WorldPos.z*0.01;
	Tex.xy -= float2(-0.5, -0.5);
	Out.Tex = Tex + float2(ViewportOffset.x, 0.0);

	return Out;
}

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{	
	float4 Color;

	Color  = WT_0 *	 tex2D(ScnSamp2, Tex);
	Color += WT_1 * (tex2D(ScnSamp2, Tex + float2(0, SampStep.y	   )) + tex2D(ScnSamp2, Tex - float2(0, SampStep.y	  )));
	Color += WT_2 * (tex2D(ScnSamp2, Tex + float2(0, SampStep.y * 2)) + tex2D(ScnSamp2, Tex - float2(0, SampStep.y * 2)));
	Color += WT_3 * (tex2D(ScnSamp2, Tex + float2(0, SampStep.y * 3)) + tex2D(ScnSamp2, Tex - float2(0, SampStep.y * 3)));
	Color += WT_4 * (tex2D(ScnSamp2, Tex + float2(0, SampStep.y * 4)) + tex2D(ScnSamp2, Tex - float2(0, SampStep.y * 4)));
	Color += WT_5 * (tex2D(ScnSamp2, Tex + float2(0, SampStep.y * 5)) + tex2D(ScnSamp2, Tex - float2(0, SampStep.y * 5)));
	Color += WT_6 * (tex2D(ScnSamp2, Tex + float2(0, SampStep.y * 6)) + tex2D(ScnSamp2, Tex - float2(0, SampStep.y * 6)));
	Color += WT_7 * (tex2D(ScnSamp2, Tex + float2(0, SampStep.y * 7)) + tex2D(ScnSamp2, Tex - float2(0, SampStep.y * 7)));

	return Color;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// 水玉ドロップシャドウを描画する

//　グリッドからの距離に合わせた透明度を返す関数
inline float getDotsAlpha(uniform float GridAplha, uniform float2 GridPos, uniform float2 GridScale)
{
	float alpha;
	float2 pos, texWidePos;

	pos = saturate(GridPos * GridScale / GridAplha);
	texWidePos = saturate((GridPos + halfPixel) * GridScale / GridAplha) - pos;

	alpha = tex2D(DotSamp, pos);
#if BLUR_MODE
	alpha = alpha * 2.0
			+ tex2D(DotSamp, float2(pos.x + texWidePos.x, pos.y + texWidePos.y))
			+ tex2D(DotSamp, float2(pos.x + texWidePos.x, pos.y - texWidePos.y))
			+ tex2D(DotSamp, float2(pos.x - texWidePos.x, pos.y + texWidePos.y));
	alpha *= 0.2;
#endif

#if ALPHA_MODE == 0
	alpha *= Alpha;
#endif
	
	return alpha;
}

VS_OUTPUT VS_drawDots(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	float2 c = float2(0.5, 0.5);

	Out.Pos = Pos;
	Out.Pos.zw = 1;
	WorldPos.x *= -1;

	Tex.xy += WorldPos.xy*0.01;
	Tex.xy += float2(-0.5,-0.5);
	Tex.xy *= 1+WorldPos.z*0.01;
	Tex.xy -= float2(-0.5,-0.5);
	Out.Tex = (Tex + ViewportOffset - c) * fmRange + c;

	return Out;
}

float4 PS_drawDots(float2 ScrPos: TEXCOORD0) : COLOR
{	
	float4 Color = 0.0;

	float2 GridPos;	// 水玉の中心から現在のピクセルの距離
	float2 GridNum;	// 現在のピクセルから左上にある水玉が何個目か
#if ZPOS_MODE
	float2 GridScale = float2(GridSize, GridSize * AspectRatio);	// グリッド間隔
	float2 DotsSize = DotsScale * ObjXYZ.z / GridScale;
#else
	float2 GridScale = float2(GridSize * ObjXYZ.z, GridSize * ObjXYZ.z * AspectRatio);	// グリッド間隔
	float2 DotsSize = DotsScale / GridScale;
#endif
	float2 GridHalfScale = GridScale * 0.5; // 偶数列用のグリッド半分幅

#ifdef MIKUMIKUMOVING
	Color.rgb = DotsColor;				// MMM ではパラメータのみで色調整
#else
	Color.rgb = ObjRxyz * RADIAN;		// アクセサリ操作 Rx、Ry、Rz から色を決定
#endif
	//------------------
	// 奇数列の４点からの距離から影の濃さを取得する

	GridPos = fmod(ScrPos, GridScale);
	GridNum = floor(ScrPos / GridScale);

	// 左上の水玉
	Color.a += getDotsAlpha(tex2D(ScnSamp3, GridScale * GridNum).a, GridPos, DotsSize);

	// 右上の水玉
	Color.a += getDotsAlpha(tex2D(ScnSamp3, GridScale * float2(GridNum.x + 1.0, GridNum.y)).a
							, float2(GridScale.x - GridPos.x, GridPos.y), DotsSize);
	// 左下の水玉
	Color.a += getDotsAlpha(tex2D(ScnSamp3, GridScale * float2(GridNum.x, GridNum.y + 1.0)).a
							, float2(GridPos.x, GridScale.y - GridPos.y), DotsSize);
	// 右下の水玉
	Color.a += getDotsAlpha(tex2D(ScnSamp3, GridScale * float2(GridNum.x + 1.0, GridNum.y + 1.0)).a
							, float2(GridScale.x - GridPos.x, GridScale.y - GridPos.y), DotsSize);

	//------------------
	// 偶数列（奇数列同士の対角線の交点）の４点からの距離から影の濃さを取得する

	GridPos = fmod(ScrPos + GridHalfScale, GridScale);
	GridNum = floor((ScrPos + GridHalfScale) / GridScale);

	// 左上の水玉
	Color.a += getDotsAlpha(tex2D(ScnSamp3, GridScale * GridNum - GridHalfScale).a, GridPos, DotsSize);

	// 右上の水玉
	Color.a += getDotsAlpha(tex2D(ScnSamp3, GridScale * float2(GridNum.x + 1.0, GridNum.y) - GridHalfScale).a
							, float2(GridScale.x - GridPos.x, GridPos.y), DotsSize);
	// 左下の水玉
	Color.a += getDotsAlpha(tex2D(ScnSamp3, GridScale * float2(GridNum.x, GridNum.y + 1.0) - GridHalfScale).a
							, float2(GridPos.x, GridScale.y - GridPos.y), DotsSize);
	// 右下の水玉
	Color.a += getDotsAlpha(tex2D(ScnSamp3, GridScale * float2(GridNum.x + 1.0, GridNum.y + 1.0) - GridHalfScale).a
							, float2(GridScale.x - GridPos.x, GridScale.y - GridPos.y), DotsSize);

#if ALPHA_MODE
	Color.a = saturate(Color.a) * Alpha;
#endif

	return saturate(Color);
}

//=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=
//　テクニック記述
technique DotsShadow <
	string Script = 
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		"RenderColorTarget0=ScnMap2;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=Gaussian_X;"

		"RenderColorTarget0=ScnMap3;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=Gaussian_Y;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=drawDotsShadow;"
	;
> {
	pass Gaussian_X < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_2_0 VS_passX();
		PixelShader	 = compile ps_2_0 PS_passX();
	}
	pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_2_0 VS_passY();
		PixelShader	 = compile ps_2_0 PS_passY();
	}
	pass drawDotsShadow < string Script= "Draw=Buffer;"; > {
		VertexShader = compile vs_3_0 VS_drawDots();
		PixelShader	 = compile ps_3_0 PS_drawDots();
	}
}
//=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=
