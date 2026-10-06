////////////////////////////////////////////////////////////////////////////////////////////////
//
//msUnsharp ver1.0
//
//Author: ましまし
//
////////////////////////////////////////////////////////////////////////////////////////////////
////設定ここから////

//ぼかしの半径pixel
//大きくするほどシャープ効果が強くなるが、悪いハロー効果も増える
#define SAMP_NUM  3

//編集画面と出力サイズの比
//出力サイズが2倍なら2。出力するときは1に戻す
#define ScreenScale  2

////設定ここまで////

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

// ポストエフェクトでは必ず以下の設定をする。
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "sceneorobject";
	string ScriptOrder = "postprocess";
> = 0.8;

// 背景のクリア値
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

// パラメータ取得
//float3 XYZ : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
//float  SiNative  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
//static float Si = SiNative * 0.1;
float  Tr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;


// オリジナルの描画結果を記録するためのレンダーターゲット
texture ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {ScreenScale, ScreenScale};
	string Format = "A16B16G16R16F";
>;
sampler ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
//ぼかしX用ターゲット
texture ScnMap2 : RENDERCOLORTARGET <
	float2 ViewPortRatio = {ScreenScale, ScreenScale};
	string Format = "A16B16G16R16F";
>;
sampler ScnSamp2 = sampler_state {
	texture = <ScnMap2>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
//重み用ターゲット
texture WeightMap : RENDERCOLORTARGET <
	float2 Dimensions = {SAMP_NUM, 1.0};
	string Format = "R16F";
>;
sampler WeightSamp = sampler_state {
	texture = <WeightMap>;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};


// 深度バッファ
texture DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {ScreenScale, ScreenScale};
>;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

// 半ピクセル
static float2 ViewportOffset = (float2(0.5,0.5)/(ViewportSize * ScreenScale));
static float2 SampStep = (float2(1,1)/(ViewportSize * ScreenScale));

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// シェーダ

VS_OUTPUT VS_DrawBuffer( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
	VS_OUTPUT Out; 
	
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	
	return Out;
}

VS_OUTPUT VS_WeightDrawBuffer( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
	VS_OUTPUT Out; 
	
	Out.Pos = Pos;
	Out.Tex = Tex + (float2(0.5,0.5)/SAMP_NUM);
	
	return Out;
}

float4 PS_Weight(float2 Tex: TEXCOORD0) : COLOR
{   
	return exp(-0.5 * pow(float(Tex.x * SAMP_NUM) / (SAMP_NUM / 2.0), 2.0));
}

//X方向ぼかし
float4 PS_GaussianX(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 Color = tex2D( ScnSamp, Tex );
	float4 SampColor1, SampColor2;
	float w, wSum = 1.0;
	
	[unroll]
	for (int i = 1; i <= SAMP_NUM; ++i) {
		SampColor1 = tex2D( ScnSamp, Tex-float2(SampStep.x*i,0) );
		SampColor2 = tex2D( ScnSamp, Tex+float2(SampStep.x*i,0) );
		w = tex2D( WeightSamp, float2(i / float(SAMP_NUM), 0.5) );
		Color += w * (SampColor1 + SampColor2);
		wSum += w * 2.0;
	}
	return Color / wSum;
}

//Y方向ぼかしとアンシャープマスク
float4 PS_GaussianY(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 Color = tex2D( ScnSamp2, Tex );
	float4 SampColor1, SampColor2;
	float w ,wSum = 1.0;
	
	[unroll]
	for (int i = 1; i <= SAMP_NUM; ++i) {
		SampColor1 = tex2D( ScnSamp2, Tex-float2(0,SampStep.y*i) );
		SampColor2 = tex2D( ScnSamp2, Tex+float2(0,SampStep.y*i) );
		w = tex2D( WeightSamp, float2(i / float(SAMP_NUM), 0.5) );
		Color += w * (SampColor1 + SampColor2);
		wSum += w * 2.0;
	}
	
	Color /= wSum;
	
	float4 ColorOrg = tex2D( ScnSamp, Tex );
	float4 ColorHSY = rgb2hsy( ColorOrg );
	ColorHSY.z = ColorHSY.z * 2.0 - rgb2hsy( Color ).z;

	Color = lerp( ColorOrg, hsy2rgb( ColorHSY ), Tr );
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
		
		"RenderColorTarget0=WeightMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=Weight;"
		
		"RenderColorTarget0=ScnMap2;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=GaussianX;"
		
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=GaussianY;"
		
	;
> {
	pass Weight < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_WeightDrawBuffer();
		PixelShader  = compile ps_3_0 PS_Weight();
	}
		pass GaussianX < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DrawBuffer();
		PixelShader  = compile ps_3_0 PS_GaussianX();
	}
	
	pass GaussianY < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DrawBuffer();
		PixelShader  = compile ps_3_0 PS_GaussianY();
	}
	

	
	pass DammyPass < string Script= "Draw=Geometry;"; > {}

}
////////////////////////////////////////////////////////////////////////////////////////////////
