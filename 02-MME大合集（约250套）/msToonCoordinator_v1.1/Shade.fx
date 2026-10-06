////////////////////////////////////////////////////////////////////////////////////////////////
//
//Shade - msToonCoordinator ver1.0
//
//Author: ましまし
//
////////////////////////////////////////////////////////////////////////////////////////////////

////設定ここから////


//MMDでアンチエイリアスをOFFにするときはコメントアウトしてください
//#define ANTIALIAS

//ハイライト部分が影領域に入ったときベース色にします
//コメントアウトした場合はハイライト色のままになります
//#define HIGHLIGHT_IN_SHADOW


////設定ここまで////


////////////////////////////////////////////////////////////////////////////////////////////////

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
CNT_VAR(CntShade1Threshould, "影1しきい値")
CNT_VAR(CntShade1HN, "影1色相")
CNT_VAR(CntShade1SN, "影1彩度")
CNT_VAR(CntShade1YN, "影1明度")
CNT_VAR(CntShade1HAN, "影1色相適用")
CNT_VAR(CntHighLi1Threshould, "ハイ1しきい値")
CNT_VAR(CntHighLi1HN, "ハイ1色相")
CNT_VAR(CntHighLi1SN, "ハイ1彩度")
CNT_VAR(CntHighLi1YN, "ハイ1明度")
CNT_VAR(CntHighLi1HAN, "ハイ1色相適用")
CNT_VAR(CntHighLi1RTonly, "ハイ1影を無視")
CNT_VAR(CntSubLi1Threshould, "Sub1しきい値")
CNT_VAR(CntSubLi1HN, "Sub1色相")
CNT_VAR(CntSubLi1SN, "Sub1彩度")
CNT_VAR(CntSubLi1YN, "Sub1明度")
CNT_VAR(CntSubLi2Threshould, "Sub2しきい値")
CNT_VAR(CntSubLi2HN, "Sub2色相")
CNT_VAR(CntSubLi2SN, "Sub2彩度")
CNT_VAR(CntSubLi2YN, "Sub2明度")
CNT_VAR(CntTes,	"調整用")
static float CntShade1S = CntShade1SN * 2.0 - 1.0;
static float CntShade1Y = CntShade1YN * 2.0 - 1.0;
static float CntHighLi1S = CntHighLi1SN * 2.0 - 1.0;
static float CntHighLi1Y = CntHighLi1YN * 2.0 - 1.0;
static float CntSubLi1S = CntSubLi1SN * 2.0 - 1.0;
static float CntSubLi1Y = CntSubLi1YN * 2.0 - 1.0;
static float CntSubLi2S = CntSubLi2SN * 2.0 - 1.0;
static float CntSubLi2Y = CntSubLi2YN * 2.0 - 1.0;


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

//ハイライトや陰影に関するRT
texture msTC_ShadeRT : OFFSCREENRENDERTARGET <
	string Description = "Set Shade&&Highlight for msToonCoordinator\nR = Base, G = Highlight, B = Shade";
	float4 ClearColor = { 0, 0, 1, 1 };
	float ClearDepth = 1.0;
	string Format= TEXFORMAT;
	int MipLevels = 1;
	#ifdef ANTIALIAS
	bool AntiAlias = true;
	#endif
	string DefaultEffect = 
		"self = hide;"
		"*ontroller* = hide;"
		"* = Shade/Shade_ExShadow.fx";
>;
sampler ShadeSamp = sampler_state {
	texture = <msTC_ShadeRT>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	Filter = LINEAR;
};

//サブライトに関するRT
texture msTC_SubLightRT : OFFSCREENRENDERTARGET <
	string Description = "Set SubLight for msToonCoordinator\nR = SubLight1, G = Sublight2, B = High&SubLightCanceler";
	float4 ClearColor = { 0, 0, 0, 1 };
	float ClearDepth = 1.0;
	string Format= TEXFORMAT;
	int MipLevels = 1;
	#ifdef ANTIALIAS
	bool AntiAlias = true;
	#endif
	string DefaultEffect = 
		"self = hide;"
		"*ontroller* = hide;"
		"* = SubLight/SubLight_ON.fx";
>;
sampler SubLightSamp = sampler_state {
	texture = <msTC_SubLightRT>;
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
	//.gから求めているけど.rでも.bでもいい
	hsya.y = ( rgba.g - hsya.z ) / ( saturated.g - hsya.z );
	hsya.y = lerp( hsya.y, 1.0, step( hsya.z, 0.0 ) + step( 1.0, hsya.z ) );

	return hsya;
}

// 指定したHSY値にする１
float3 adjustHSY1( float3 baseHSY, float h, float s, float y, float hAlpha ){
	float3 tgtHSY;
	tgtHSY.x = baseHSY.x;
	tgtHSY.y = baseHSY.y > 0 ?
		baseHSY.y + ( 0.5 - baseHSY.y ) * abs( s ) + 0.5 * s : 
		baseHSY.y;
	tgtHSY.z = baseHSY.z + ( 0.5 - baseHSY.z ) * abs( y ) + 0.5 * y;
	tgtHSY = rgb2hsy( lerp( hsy2rgb( float4( tgtHSY, 1.0 ) ), hsy2rgb( float4( h, tgtHSY.yz, 1.0 ) ), hAlpha ) ).xyz;
	return tgtHSY;
}

// 指定したHSY値にする２
float3 adjustHSY2( float3 baseHSY, float h, float s, float y ){
	float3 tgtHSY;
	tgtHSY.x = h;
	tgtHSY.y = baseHSY.y + ( 0.5 - baseHSY.y ) * abs( s ) + 0.5 * s;
	tgtHSY.z = baseHSY.z + ( 0.5 - baseHSY.z ) * abs( y ) + 0.5 * y;
	return tgtHSY;
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
float4 PS_Shading(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 ColorOrg = tex2Dfix( ScnSamp, Tex, 0 );
	float4 ColorOrgHSY = rgb2hsy( ColorOrg );
	//float4 ColorLnr = LINEARIZE(ColorOrg);
	//float4 ColorLnrHSY = rgb2hsy( ColorLnr );
	float4 Color = ColorOrg;
	float4 ColorShade1, ColorHighLi1, ColorSubLi1, ColorSubLi2;
	
	//RTタブから陰影を取得
	float4 Shade = tex2Dfix( ShadeSamp, Tex, 0 );
	float4 SubLight = tex2Dfix( SubLightSamp, Tex, 0 );
	//各色フラグ
	#ifdef HIGHLIGHT_IN_SHADOW
		float Shade1 = 1.0 - step( CntShade1Threshould, Shade.b + Shade.r + Shade.g * CntHighLi1RTonly );
	#else
		float Shade1 = 1.0 - step( CntShade1Threshould, Shade.b + Shade.r );
	#endif
	float HighLi1 = step( CntHighLi1Threshould, ( max( Shade.b + Shade.r, CntHighLi1RTonly ) * Shade.g ) * ( 1.0 - SubLight.b ) - 0.01 );
	float SubLi1 = step( CntSubLi1Threshould, SubLight.r * ( 1.0 - SubLight.b ) );
	float SubLi2 = step( CntSubLi2Threshould, SubLight.g * ( 1.0 - SubLight.b ) );
	
	Color = ColorShade1 = ColorSubLi1 = ColorSubLi2 = ColorOrgHSY;
	
	//Shade1
	ColorShade1.xyz = adjustHSY1( ColorOrgHSY, CntShade1HN, CntShade1S, CntShade1Y, CntShade1HAN );
	Color.xyz = lerp( Color.xyz, ColorShade1.xyz, Shade1 );
	
	//HighLight1
	ColorHighLi1.xyz = adjustHSY1( ColorOrgHSY, CntHighLi1HN, CntHighLi1S, CntHighLi1Y, CntHighLi1HAN );
	Color.xyz = lerp( Color.xyz, ColorHighLi1.xyz, HighLi1 );
	
	//SubLight2
	ColorSubLi2.xyz = adjustHSY2( ColorOrgHSY, CntSubLi2HN, CntSubLi2S, CntSubLi2Y );
	Color.xyz = lerp( Color.xyz, ColorSubLi2.xyz,  SubLi2 );
	/* 手法2
	ColorSubLi2 = hsy2rgb( float4( CntSubLi2HN, CntSubLi2SN, CntSubLi2YN, ColorOrg.a ) );
	Color = hsy2rgb( Color );
	Color = LINEARIZE( Color ) + LINEARIZE( ColorSubLi2 ) * SubLi2;
	Color = NONLINEARIZE( Color );
	Color = rgb2hsy( Color );
	*/
	
	//SubLight1
	ColorSubLi1.xyz = adjustHSY2( ColorOrgHSY, CntSubLi1HN, CntSubLi1S, CntSubLi1Y );
	Color.xyz = lerp( Color.xyz, ColorSubLi1.xyz, SubLi1 );
	/* 手法2
	ColorSubLi1 = hsy2rgb( float4( CntSubLi1HN, CntSubLi1SN, CntSubLi1YN + , ColorOrg.a ) );
	//Color = hsy2rgb( Color );
	Color = Color + LINEARIZE( ColorSubLi1 ) * SubLi1;
	Color = NONLINEARIZE( Color );
	*/
	
	Color = hsy2rgb( Color );
	
	//テスト用
	const float item_num = 4.0;
	float current = 0.0;
	//ベース色
	Color = lerp(Color, ColorOrg, step( ++current / (item_num + 1), CntTes ) );
	//Shadeタブ
	Color = lerp(Color, float4( Shade.rgb, ColorOrg.a ), step( ++current / (item_num + 1), CntTes ) );
	//SubLightタブ
	Color = lerp(Color, float4( SubLight.rgb, ColorOrg.a ), step( ++current / (item_num + 1), CntTes ) );
	//Edge
	Color = lerp(Color, float4( 1.0, 1.0, 1.0, ColorOrg.a ), step( ++current / (item_num + 1), CntTes ) );
	
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
		"Pass=ShadingPass;"
		
	;
> {
	pass ShadingPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DrawBuffer(ViewportOffset);
		PixelShader  = compile ps_3_0 PS_Shading();
	}
	pass DammyPass < string Script= "Draw=Geometry;"; > {
	}

}
////////////////////////////////////////////////////////////////////////////////////////////////
