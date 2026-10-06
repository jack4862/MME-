////////////////////////////////////////////////////////////////////////////////////////////////
//
//msPowerDiffusion ver1.0
//
//Author: ましまし
//
////////////////////////////////////////////////////////////////////////////////////////////////

////設定ここから////

//ぼかしの半径pixel
//大きくするほど効果のかかる範囲が広がる
#define SAMP_NUM	8

//出力サイズ（ikenoさん参考）
//編集中は編集画面サイズと出力サイズの比にしておき、出力するとき1に戻す
#define ScreenScale		1.0

////設定ここまで////

//テクスチャフォーマット。一応HDR対応。
#define TEXFORMAT "A16B16G16R16F"

//コントローラ名
#define CONTROLLER_NAME	"msPowerDiffusionController.pmx"

//tex2Dlod代替
#define tex2Dfix(x, y, z)	tex2Dlod(x, float4(y, 0.0, z))

//ダウンスケールの縮小比率
#define LEVEL(x)	(1.0/pow(2.0, x))

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
CNT_VAR(CntHue,	"色相")
CNT_VAR(CntSat,	"彩度")
CNT_VAR(CntVmin,	"明度_黒点")
CNT_VAR(CntVmax,	"明度_白点")
CNT_VAR(CntTra,	"透明度")
CNT_VAR(CntTes,	"調整用")
CNT_VAR(CntY1mod,	"芯_add/screen")
CNT_VAR(CntY5mod,	"拡散_add/screen")
CNT_VAR(CntAch,	"無彩色の色相")
CNT_VAR(CntMnC,	"色の統一")


// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {ScreenScale, ScreenScale};
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

//レベル補正・色変更用ターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
	float2 ViewPortRatio = {ScreenScale,ScreenScale};
	string Format= TEXFORMAT;
	int Miplevels = 0;
>;
sampler2D ScnSamp2 = sampler_state {
	texture = <ScnMap2>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

//ぼかしX用ターゲット
//ikenoさん参考
#define DECL_TEXTURE( _map, _samp, _size) \
	texture2D _map : RENDERCOLORTARGET < \
		int MipLevels = 1; \
		float2 ViewportRatio = {ScreenScale * LEVEL(_size), ScreenScale * LEVEL(_size)}; \
		string Format = TEXFORMAT; \
	>; \
	sampler2D _samp = sampler_state { \
		texture = <_map>; \
		MinFilter = LINEAR; \
		MagFilter = LINEAR; \
		MipFilter = LINEAR; \
		AddressU  = CLAMP; \
		AddressV = CLAMP; \
	}; 
DECL_TEXTURE( DownScaleMapX1, DownScaleSampX1, 1.0)
DECL_TEXTURE( DownScaleMapX2, DownScaleSampX2, 2.0)
DECL_TEXTURE( DownScaleMapX3, DownScaleSampX3, 3.0)
DECL_TEXTURE( DownScaleMapX4, DownScaleSampX4, 4.0)
DECL_TEXTURE( DownScaleMapX5, DownScaleSampX5, 5.0)
DECL_TEXTURE( DownScaleMapY1, DownScaleSampY1, 1.0)
DECL_TEXTURE( DownScaleMapY2, DownScaleSampY2, 2.0)
DECL_TEXTURE( DownScaleMapY3, DownScaleSampY3, 3.0)
DECL_TEXTURE( DownScaleMapY4, DownScaleSampY4, 4.0)
DECL_TEXTURE( DownScaleMapY5, DownScaleSampY5, 5.0)

//重み用ターゲット
texture2D WeightMap : RENDERCOLORTARGET <
	float2 Dimensions = {SAMP_NUM, 1.0};
	string Format = "R16F";
>;
sampler2D WeightSamp = sampler_state {
	texture = <WeightMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

//マスクマップRT
texture msPD_MaskRT : OFFSCREENRENDERTARGET <
	string Description = "Mask for msPowerDiffusion\n光らせたくないオブジェクト→Mask_BlackOut.fx、　強制的に光らせたいオブジェクト→Mask_Emissive.fx";
	float4 ClearColor = { 0, 0, 0, 1 };
	float ClearDepth = 1.0;
	string Format = "D3DFMT_R16F" ;
	int MipLevels = 1;
	string DefaultEffect = 
		"self = hide;"
		"*ontroller* = hide;"
		"* = Mask_Default.fx";
>;

sampler MaskSamp = sampler_state {
	texture = <msPD_MaskRT>;
	AddressU  = CLAMP;
	AddressV = CLAMP;
	Filter = NONE;
};

// 深度バッファ
texture DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {ScreenScale, ScreenScale};
>;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

// 半ピクセル
static float2 ViewportOffset = (float2(0.5,0.5)/(ViewportSize*ScreenScale));
static float2 SampStep = (float2(1,1)/(ViewportSize*ScreenScale));
static float2 ViewportARatio = float2(ViewportSize.x / ViewportSize.y, 1.0);
////////////////////////////////////////////////////////////////////////////////////////////////

//RGBカラーをHSLカラーに変換する(HDR)
float3 rgb2hsl(float3 rgb){
	float3 hsl;
	rgb = max(rgb, float3(0.0, 0.0, 0.0));
	float minRGB = min(min(rgb.r, rgb.g), rgb.b);
	float maxRGB = max(max(rgb.r, rgb.g), rgb.b);
	float diff = maxRGB - minRGB;
	float achromaticHue = CntAch * 6.0;	//無彩色の色相値
	
	hsl.x = lerp( (rgb.g - rgb.r)/diff + 1.0, (rgb.r - rgb.b)/diff + 5.0, step(rgb.g, minRGB) );
	hsl.x = lerp( hsl.x, (rgb.b - rgb.g)/diff + 3.0, step(rgb.r, minRGB) );
	hsl.x = lerp( hsl.x, achromaticHue, step(maxRGB, minRGB));
	hsl.x *= 60.0;
	hsl.y = diff;
	hsl.z = (maxRGB + minRGB) / 2.0;
	
	return hsl;
}

//HSLカラーをRGBカラーに変換する(HDR)
float3 hsl2rgb(float3 hsl){
	float3 rgb;
	hsl.x = fmod(hsl.x, 360.0);
	hsl.y = max(hsl.y, 0.0);
	hsl.z = max(hsl.z, 0.0);
	float min = hsl.z - hsl.y / 2.0;
	float mid = hsl.y / 60.0;

	rgb = float3(hsl.y, mid * hsl.x, 0.0);
	rgb = lerp(rgb, float3(mid * (120.0 - hsl.x), hsl.y, 0.0), step(60.0, hsl.x));
	rgb = lerp(rgb, float3(0.0, hsl.y, mid * (hsl.x - 120.0)), step(120.0, hsl.x));
	rgb = lerp(rgb, float3(0.0, mid * (240.0 - hsl.x), hsl.y), step(180.0, hsl.x));
	rgb = lerp(rgb, float3(mid * (hsl.x - 240.0), 0.0, hsl.y), step(240.0, hsl.x));
	rgb = lerp(rgb, float3(hsl.y, 0.0, mid * (360.0 - hsl.x)), step(300.0, hsl.x));
	rgb += min;
	
	return rgb;
}

float4 screenBlend(float4 b, float4 t){
	return b + saturate(t) - b * saturate(t);
}

//輝度 CIE XYZ
float lumiXYZ(float4 color){
	color = pow(color, 1.0/2.2);
	return pow(dot(color.rgb, float3(0.2126, 0.7152, 0.0722)), 2.2); 
}

float lumiXYZLinear(float4 color){
	return dot(color.rgb, float3(0.2126, 0.7152, 0.0722)); 
}

////////////////////////////////////////////////////////////////////////////////////////////////
// シェーダ

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_DrawBuffer( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float2 offset, uniform int mipLevelSize ){
	VS_OUTPUT Out; 
	
	Out.Pos = Pos;
	Out.Tex = Tex + offset / LEVEL(mipLevelSize);
	
	return Out;
}

//ガウシアンの重みを計算
float4 PS_Weight(float2 Tex: TEXCOORD0) : COLOR
{   
	return exp(-0.5 * pow(((Tex.x - (0.5/SAMP_NUM))* SAMP_NUM) / (SAMP_NUM / 2.0), 2.0));
}

//レベル補正・色変更
float4 PS_Chroma(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 ColorOrg = tex2Dfix( ScnSamp, Tex, 0 );
	float4 ColorOrgLinear = LINEARIZE(ColorOrg);
	float4 Color = ColorOrgLinear;
	
	//マスク適用
	float4 mask = tex2Dfix( MaskSamp, Tex, 0 );
	Color *= mask.r;
	//Color = lerp(Color, 1.0, step(1.1, mask.r));
	
	//レベル補正
	float lumi = lumiXYZLinear(Color);
	float amp = max(0.0, lumi - CntVmin) / (CntVmax - CntVmin);
	amp = lerp(amp, max(1.0, lumi), step(CntVmax, lumi));
	amp = amp / lumi;
	Color = lerp(Color * amp, 0.0, step(lumi, 0.0));

	//色変更
	float3 ColorMonoHSL;
	ColorMonoHSL.x = CntHue * 360.0;
	ColorMonoHSL.y = CntSat;
	ColorMonoHSL.z = rgb2hsl(Color.rgb).z;
	//ColorMonoHSL.y = min(CntSat, 1.0 - abs(ColorMonoHSL.z - 0.5) * 2.0);//明度1.0で彩度0
	ColorMonoHSL.y *= saturate( ColorMonoHSL.z * 2.0 );//明度1.0で彩度1.0を許す
	float4 ColorMonoLinear = (hsl2rgb(ColorMonoHSL).xyzz);
	
	Color = lerp(Color, ColorMonoLinear, CntMnC);
	Color.a = ColorOrg.a;
	
	return Color;
}

//単方向ぼかし
float4 PS_Gaussian(VS_OUTPUT IN, uniform sampler2D smp, uniform int mipLevelSize, uniform int mipLevel, uniform bool isX) : COLOR
{   
	float4 SampColor1, SampColor2;
	float w, wSum = 1.0;

	float4 Color = tex2Dfix( smp, IN.Tex, mipLevel);
	
	float2 step = float2(1.0,1.0)/(ViewportSize*ScreenScale*LEVEL(mipLevelSize));
	
	for (int i = 1; i <= SAMP_NUM; ++i) {
		SampColor1 = tex2Dfix( smp, IN.Tex - step * i * bool2(isX, !isX), mipLevel );
		SampColor2 = tex2Dfix( smp, IN.Tex + step * i * bool2(isX, !isX), mipLevel );
		w = tex2Dfix( WeightSamp, float2(i / float(SAMP_NUM), 0.5), 0 );
		Color += w * (SampColor1 + SampColor2);
		wSum += w * 2.0;
	}
	
	Color /= wSum;
	Color.a = 1.0;
	return Color;
}

//最終合成
float4 PS_Diffusion(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 ColorOrg = tex2Dfix( ScnSamp, Tex, 0);
	float4 ColorOrgLinear = LINEARIZE(ColorOrg);
	float4 ColorY1 = tex2Dfix( DownScaleSampY1, Tex - ViewportOffset * ( 1.0 - 1.0 / LEVEL(1)), 0);
	float4 ColorY2 = tex2Dfix( DownScaleSampY2, Tex - ViewportOffset * ( 1.0 - 1.0 / LEVEL(2)), 0);
	float4 ColorY3 = tex2Dfix( DownScaleSampY3, Tex - ViewportOffset * ( 1.0 - 1.0 / LEVEL(3)), 0);
	float4 ColorY4 = tex2Dfix( DownScaleSampY4, Tex - ViewportOffset * ( 1.0 - 1.0 / LEVEL(4)), 0);
	float4 ColorY5 = tex2Dfix( DownScaleSampY5, Tex - ViewportOffset * ( 1.0 - 1.0 / LEVEL(5)), 0);
	
	float4 ColorLinear = ColorOrgLinear;
	
	ColorLinear = lerp(ColorLinear + ColorY1, screenBlend(ColorLinear, ColorY1), CntY1mod);
	ColorLinear = screenBlend(ColorLinear, ColorY2);
	ColorLinear = screenBlend(ColorLinear, ColorY3);
	ColorLinear = screenBlend(ColorLinear, ColorY4);
	ColorLinear = lerp(ColorLinear + ColorY5, screenBlend(ColorLinear, ColorY5), CntY5mod);
	
	ColorLinear = lerp(ColorLinear, ColorOrgLinear, CntTra);
	
	//テスト用
	const float item_num = 7.0;
	float current = 0.0;
	ColorLinear = lerp(ColorLinear, tex2Dfix( ScnSamp2, Tex, 0 ), step( ++current / (item_num + 1), CntTes ) );
	ColorLinear = lerp(ColorLinear, float4(ColorY1.rgb, 1.0), step( ++current / (item_num + 1), CntTes ) );
	ColorLinear = lerp(ColorLinear, float4(ColorY2.rgb, 1.0), step( ++current / (item_num + 1), CntTes ) );
	ColorLinear = lerp(ColorLinear, float4(ColorY3.rgb, 1.0), step( ++current / (item_num + 1), CntTes ) );
	ColorLinear = lerp(ColorLinear, float4(ColorY4.rgb, 1.0), step( ++current / (item_num + 1), CntTes ) );
	ColorLinear = lerp(ColorLinear, float4(ColorY5.rgb, 1.0), step( ++current / (item_num + 1), CntTes ) );
	ColorLinear = lerp(ColorLinear, tex2Dfix( MaskSamp, Tex, 0 )/2.0, step( ++current / (item_num + 1), CntTes ) );
	
	float4 Color = NONLINEARIZE(ColorLinear);
	Color.a = ColorOrg.a;
	return Color;

}

////////////////////////////////////////////////////////////////////////////////////////////////

#define DOWNSCALE_PASS( _pass, _samp, _miplevelsize, _miplevel, _isx) \
	pass _pass < string Script= "Draw=Buffer;"; > { \
		AlphaBlendEnable = FALSE; \
		VertexShader = compile vs_3_0 VS_DrawBuffer(ViewportOffset, _miplevelsize); \
		PixelShader  = compile ps_3_0 PS_Gaussian(_samp, _miplevelsize, _miplevel, _isx); \
	}

technique PostEffect <
	string Script = 
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"
		
		"RenderColorTarget0=WeightMap;"
		"Pass=WeightPass;"
		
		"RenderColorTarget0=ScnMap2;"
		"Pass=ChromaPass;"
		
		"RenderColorTarget0=DownScaleMapX1;"
		"Pass=DownScalePassX1;"
		"RenderColorTarget0=DownScaleMapX2;"
		"Pass=DownScalePassX2;"
		"RenderColorTarget0=DownScaleMapX3;"
		"Pass=DownScalePassX3;"
		"RenderColorTarget0=DownScaleMapX4;"
		"Pass=DownScalePassX4;"
		"RenderColorTarget0=DownScaleMapX5;"
		"Pass=DownScalePassX5;"
		
		"RenderColorTarget0=DownScaleMapY1;"
		"Pass=DownScalePassY1;"
		"RenderColorTarget0=DownScaleMapY2;"
		"Pass=DownScalePassY2;"
		"RenderColorTarget0=DownScaleMapY3;"
		"Pass=DownScalePassY3;"
		"RenderColorTarget0=DownScaleMapY4;"
		"Pass=DownScalePassY4;"
		"RenderColorTarget0=DownScaleMapY5;"
		"Pass=DownScalePassY5;"
		
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=DiffusionPass;"
		
	;
> {
	pass WeightPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DrawBuffer(float2(0.5,0.5)/SAMP_NUM, 0);
		PixelShader  = compile ps_3_0 PS_Weight();
	}
	pass ChromaPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DrawBuffer(ViewportOffset, 0);
		PixelShader  = compile ps_3_0 PS_Chroma();
	}
	DOWNSCALE_PASS( DownScalePassX1, ScnSamp2, 1, 1, true)
	DOWNSCALE_PASS( DownScalePassX2, ScnSamp2, 2, 2, true)
	DOWNSCALE_PASS( DownScalePassX3, ScnSamp2, 3, 3, true)
	DOWNSCALE_PASS( DownScalePassX4, ScnSamp2, 4, 4, true)
	DOWNSCALE_PASS( DownScalePassX5, ScnSamp2, 5, 5, true)
	DOWNSCALE_PASS( DownScalePassY1, DownScaleSampX1, 1, 0, false)
	DOWNSCALE_PASS( DownScalePassY2, DownScaleSampX2, 2, 0, false)
	DOWNSCALE_PASS( DownScalePassY3, DownScaleSampX3, 3, 0, false)
	DOWNSCALE_PASS( DownScalePassY4, DownScaleSampX4, 4, 0, false)
	DOWNSCALE_PASS( DownScalePassY5, DownScaleSampX5, 5, 0, false)
	pass DiffusionPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DrawBuffer(ViewportOffset, 0);
		PixelShader  = compile ps_3_0 PS_Diffusion();
	}
	pass DammyPass < string Script= "Draw=Geometry;"; > {
	}

}
////////////////////////////////////////////////////////////////////////////////////////////////
