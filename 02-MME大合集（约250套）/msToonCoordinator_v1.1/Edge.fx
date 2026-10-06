////////////////////////////////////////////////////////////////////////////////////////////////
//
//Edge - msToonCoordinator ver1.0
//
//Author: ましまし
//
////////////////////////////////////////////////////////////////////////////////////////////////

////設定ここから////


//MMDでアンチエイリアスをOFFにするときはコメントアウトしてください
//#define ANTIALIAS


////設定ここまで////

//テクスチャフォーマット。HDR非対応。
#define TEXFORMAT "A16B16G16R16F"

//コントローラ名
#define CONTROLLER_NAME	"msToonCoordinatorController.pmx"

//tex2Dlod代替
#define tex2Dfix(x, y, z)	tex2Dlod(x, float4(y, 0.0, z))
//リニア・ノンリニア変換
#define LINEARIZE(x)	pow(x, 2.2)
#define NONLINEARIZE(x)	pow(x, 1.0/2.2)

////////////////////////////////////////////////////////////////////////////////////////////////
// ポストエフェクトでは必ず以下の設定をする。
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "sceneorobject";
	string ScriptOrder = "postprocess";
> = 0.8;

// 背景のクリア値
float4 ClearColor = {1.0, 1.0, 1.0, 0.0};
float ClearDepth  = 1.0;

// パラメータ取得
//float  SiNative  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
//static float Si = SiNative * 0.1;
//float  Tr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

#define CNT_VAR( _var, _morph)	float _var : CONTROLOBJECT	< string name = CONTROLLER_NAME; string item = _morph; >;
CNT_VAR(CntEdgeHN, "エッジ色相")
CNT_VAR(CntEdgeSN, "エッジ彩度")
CNT_VAR(CntEdgeYN, "エッジ明度")
CNT_VAR(CntEdgeThreshould, "エッジしきい値")
CNT_VAR(CntTes,	"調整用")
static float CntEdgeS = CntEdgeSN * 2.0 - 1.0;
static float CntEdgeY = CntEdgeYN * 2.0 - 1.0;


// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	//float2 ViewPortRatio = {ScreenScale, ScreenScale};
	string Format= TEXFORMAT;
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

//エッジ描画に関するRT
texture msTC_EdgeRT : OFFSCREENRENDERTARGET <
	string Description = "Set Edge for msToonCoordinator\nR = Edge";
	float4 ClearColor = { 1, 0, 0, 1 };
	float ClearDepth = 1.0;
	string Format= TEXFORMAT;
	int MipLevels = 1;
	#ifdef ANTIALIAS
	bool AntiAlias = true;
	#endif
	string DefaultEffect = 
		"self = hide;"
		"*ontroller* = hide;"
		"* = Edge/Edge_ON.fx";
>;
sampler EdgeSamp = sampler_state {
	texture = <msTC_EdgeRT>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	Filter = LINEAR;
};

// 深度バッファ
texture DepthBuffer : RENDERDEPTHSTENCILTARGET <
	//float2 ViewPortRatio = {ScreenScale, ScreenScale};
>;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

// 半ピクセル
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 SampStep = (float2(1,1)/ViewportSize);
static float2 ViewportARatio = float2(ViewportSize.x / ViewportSize.y, 1.0);
////////////////////////////////////////////////////////////////////////////////////////////////

//HSYをRGBに変換
float4 hsy2rgb( float4 hsya ){
	float4 rgba;
	
	//引数の色相値における純色のRGB値を求める
	hsya.x = fmod( abs(hsya.x), 1.0);
	float regionH = hsya.x * 360.0 / 60.0 ;
	float mid = 1.0 - abs( fmod(regionH, 2.0) - 1.0 );
	
	rgba.rgb = float3(1.0, mid, 0.0);
	rgba.rgb = lerp(rgba.rgb, float3(mid, 1.0, 0.0), step(1.0, regionH));
	rgba.rgb = lerp(rgba.rgb, float3(0.0, 1.0, mid), step(2.0, regionH));
	rgba.rgb = lerp(rgba.rgb, float3(0.0, mid, 1.0), step(3.0, regionH));
	rgba.rgb = lerp(rgba.rgb, float3(mid, 0.0, 1.0), step(4.0, regionH));
	rgba.rgb = lerp(rgba.rgb, float3(1.0, 0.0, mid), step(5.0, regionH));
	
	//純色の輝度を求める
	float pureColorLuminance = dot(rgba.rgb, float3(0.2126, 0.7152, 0.0722));
	
	//引数の輝度と純色の輝度の差から、彩度1としたときの引数のRGB値を求める
	float4 lt = lerp( 0.0, rgba, hsya.z / pureColorLuminance );
	float4 gt = lerp( rgba, 1.0, ( hsya.z - pureColorLuminance ) / ( 1.0 - pureColorLuminance ) );
	rgba = lerp( lt, gt, step( pureColorLuminance, hsya.z ) );
	
	//彩度0と彩度1でのRGB値が分かったので、最終的な引数のRGB値を求める
	rgba = lerp( hsya.zzzw, rgba, hsya.y );
	
	rgba.a = hsya.a;
	
	return rgba;
}

//RGBをHSYに変換
float4 rgb2hsy( float4 rgba ){
	float4 hsya = rgba;

	rgba = saturate(rgba);

	//色相値を求める
	float minRGB= min(min(rgba.r, rgba.g), rgba.b);
	float maxRGB= max(max(rgba.r, rgba.g), rgba.b);
	float diff = maxRGB- minRGB;
	float achromaticHue = 0 * 6.0;	//無彩色の色相値
	
	hsya.x = (rgba.g - rgba.r) / diff + 1.0;
	hsya.x = lerp( hsya.x, (rgba.r - rgba.b) / diff + 5.0, step( rgba.g, minRGB) );
	hsya.x = lerp( hsya.x, (rgba.b - rgba.g) / diff + 3.0, step( rgba.r, minRGB) );
	hsya.x = lerp( hsya.x, achromaticHue, step( maxRGB, minRGB) );
	hsya.x *= 60.0 / 360.0;
	
	//輝度を求める
	hsya.z = dot(rgba.rgb, float3(0.2126, 0.7152, 0.0722));

	//求めた色相・輝度をもつ、彩度１のRGB値を求める
	float4 saturated = hsy2rgb( float4( hsya.x, 1.0, hsya.z, 1.0 ) );
	
	//彩度0と彩度1でのRGB値が分かったので、その差から引数の彩度を求める
	//rgba.gとsaturated.g（G値）から求めているけど.rでも.bでもいい
	hsya.y = ( rgba.g - hsya.z ) / ( saturated.g - hsya.z );
	hsya.y = lerp( hsya.y, 1.0, step( hsya.z, 0.0 ) + step( 1.0, hsya.z ) );

	return hsya;
}



////////////////////////////////////////////////////////////////////////////////////////////////
// シェーダ

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_DrawBuffer( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float2 offset ){
	VS_OUTPUT Out; 
	
	Out.Pos = Pos;
	Out.Tex = Tex + offset;
	
	return Out;
}

//最終合成
float4 PS_Edge(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 ColorOrg = tex2Dfix( ScnSamp, Tex, 0 );
	//float4 ColorOrgHSY = rgb2hsy( ColorOrg );
	float4 ColorEdge = hsy2rgb( float4( CntEdgeHN, CntEdgeSN, CntEdgeYN, ColorOrg.a ) );
	float4 Color = ColorOrg;
	
	//RTタブからエッジを取得
	float3 Edge = tex2Dfix( EdgeSamp, Tex, 0 ).rgb;
	float EdgeBi = step( CntEdgeThreshould, Edge.r );
	
	Color = lerp( ColorEdge, ColorOrg, EdgeBi);
	
	//テスト用
	const float item_num = 4.0;
	float current = 0.0;
	//ベース色
	Color = lerp(Color, ColorOrg, step( ++current / (item_num + 1), CntTes ) );
	//Shadeタブ
	Color = lerp(Color, ColorOrg, step( ++current / (item_num + 1), CntTes ) );
	//Sublightタブ
	Color = lerp(Color, ColorOrg, step( ++current / (item_num + 1), CntTes ) );
	//Edge
	Color = lerp(Color, float4( lerp( 0.0, Color.rgb, EdgeBi), ColorOrg.a ), step( ++current / (item_num + 1), CntTes ) );
	
	Color.a = ColorOrg.a;
	
	return Color;

}

////////////////////////////////////////////////////////////////////////////////////////////////

technique PostEffect <
	string Script = 
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"
		
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=EdgePass;"
		
	;
> {
	pass EdgePass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DrawBuffer(ViewportOffset);
		PixelShader  = compile ps_3_0 PS_Edge();
	}
	pass DammyPass < string Script= "Draw=Geometry;"; > {
	}

}
////////////////////////////////////////////////////////////////////////////////////////////////
