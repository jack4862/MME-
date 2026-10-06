////////////////////////////////////////////////////////////////////////////////
//
//  PostRimlightShilhouette.fx
//  by P.I.P  
//
//  M4Layer(ミーフォ茜様)をベースにGaussianVariable(そぼろ様）とEdgeControl（針金P）のコードを参照しています。
//
////////////////////////////////////////////////////////////////////////////////

//背景色  //アルファ抜きをする場合は{ 1, 1, 1, 0 }に変更した方がいいです
float4 ClearColor2 = { 0, 0, 0, 0 };
//float4 ClearColor2 = { 1, 1, 1, 0 };


//発光ぼかしを利用するフラグ //ぼかさない方がエフェクトは軽い
#define USE_GAUSSIAN

// ぼかし範囲 (サンプリング数は固定のため、大きくしすぎると縞が出ます)
#define EXTENT  0.0035

//エフェクト描画直前のモデルの色を加算に利用する
//#define USE_REDERCOLOR

//リムライト強度
#define RIMPOWER 0.5 //0.0-1.0 発光させる場合は弱めでいい

//ガウス強度
#define GAUPOWER 1.5 //0.0-3.0くらい、リムライトをぼかして弱めた上で加算される

//合成モードをスクリーン合成にする
//#define SCREEN_MODE

bool opadd;

// ポストエフェクト宣言
float Script : STANDARDSGLOBAL
<
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float Si : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

//static float Tr = Tr0 * POWER;

float RimPowerCTR1 : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "ﾘﾑﾗｲﾄ強"; >;
float RimPowerCTR2 : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "ﾘﾑﾗｲﾄ弱"; >;
float GauPowerCTR1 : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "発光強く"; >;
float GauPowerCTR2 : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "発光弱く"; >;
float GauWidthCTR1 : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "ぼかし広く"; >;
float GauWidthCTR2 : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "ぼかし狭く"; >;
float FullPowerCTR1 : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "全体強く"; >;
float FullPowerCTR2 : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "全体弱く"; >;



float Red   : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "Red"; >;
float Green : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "Green"; >;
float Blue  : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "Blue"; >;


float3 CtrRGB : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "RGB XYZ"; >;

static float FullPower = (1 +  FullPowerCTR1*2) * (1 - FullPowerCTR2);


static float GauPower = (1 + GauPowerCTR1*2) * (1 - GauPowerCTR2)  * GAUPOWER * FullPower;
static float RimPower = (1 + RimPowerCTR1*2) * (1 - RimPowerCTR2)  * RIMPOWER * FullPower;


float3 AddColor : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
float3 AddColorRxyz0 : CONTROLOBJECT < string name = "(self)"; string item = "Rxyz"; >;

static float3 AddColorRxyz = AddColorRxyz0 + CtrRGB/10 - float3(Red, Green, Blue);

float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = float2(0.5, 0.5) / ViewportSize;

////////////////////////////////////////////////////////////////
// 作業用テクスチャ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;
texture2D ScreenBuffer : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "A8R8G8B8" ;
>;
sampler2D ScreenSampler = sampler_state {
	texture = <ScreenBuffer>;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

#ifdef USE_GAUSSIAN

static float GauWidth = ( 1 + GauWidthCTR1 ) * (1-GauWidthCTR2);

static float2 SampStep = (float2( EXTENT*GauWidth + 0/1000 , EXTENT*GauWidth + 0/1000 )/ViewportSize*ViewportSize.y);


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

// M4Layerの描画を記録するためのレンダーターゲット
texture2D M4Map : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D M4Sampler = sampler_state {
    texture = <M4Map>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// Y方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp3 = sampler_state {
    texture = <ScnMap3>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
#endif //USE_GAUSSIAN



#ifndef USE_REDERCOLOR// LAYER_RT
texture RimShilouhette : OFFSCREENRENDERTARGET
<
    
    string Description = "PostRimShilouhette.fx 背景はチェックを外す"; //モード説明の変更必要かな？？
    float4 ClearColor = { 0, 0, 0, 0 };
    string DefaultEffect = "self = hide; * = RimShilouhette.fx;";
    
	float ClearDepth = 1.0;
	bool AntiAlias = true;
	int Miplevels = 1;
    
    
>;

sampler LayerSampler = sampler_state
{
	texture = <RimShilouhette>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
#endif

texture Rim_Mask : OFFSCREENRENDERTARGET
<
    string Description = "PostRimShilouhette.fxのマスク 背景はチェックを外す";
    float4 ClearColor = { 0, 0, 0, 0 };
    string DefaultEffect = "self = hide; * = RimMask.fx;";
    
	float ClearDepth = 1.0;
	bool AntiAlias = true;
	int Miplevels = 1;
	
	
>;
sampler LayerMaskSampler = sampler_state
{
	texture = <Rim_Mask>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};


struct VS_OUTPUT
{
   float4 Pos: POSITION;
   float2 Tex: TEXCOORD0;
};

VS_OUTPUT BlendVS(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{ 
	VS_OUTPUT Out;
	
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	
	return Out;
}



float4 BlendPS(float2 Tex: TEXCOORD0) : COLOR
{
	float4 background = tex2D(ScreenSampler, Tex);//オリジナルの描画
	
	
#ifndef USE_REDERCOLOR // LAYER_RT
	float4 foreground = tex2D(LayerSampler, Tex);
	foreground.r += AddColorRxyz.g + AddColorRxyz.b;
	foreground.g += AddColorRxyz.r + AddColorRxyz.b;
	foreground.b += AddColorRxyz.r + AddColorRxyz.g;
	
	
#else
	float4 foreground = background;
	foreground.r += AddColorRxyz.g + AddColorRxyz.b;
	foreground.g += AddColorRxyz.r + AddColorRxyz.b;
	foreground.b += AddColorRxyz.r + AddColorRxyz.g;

#endif


	float4 m = tex2D(LayerMaskSampler, Tex);
	foreground.a *= 1 - m.r * m.a;
	
	foreground = saturate(foreground);
	
	#ifdef USE_GAUSSIAN //ガウスぼかしを使う場合はここではオリジナル描画に合成しない
	return foreground;
	#else
	return background;
	#endif
	
}


#ifdef USE_GAUSSIAN

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   


    float4 Color;

    float step = SampStep.x;

    Color  = WT_0 *   tex2D( M4Sampler, Tex );
    Color += WT_1 * ( tex2D( M4Sampler, Tex+float2(step  ,0) ) + tex2D( M4Sampler, Tex-float2(step  ,0) ) );
    Color += WT_2 * ( tex2D( M4Sampler, Tex+float2(step*2,0) ) + tex2D( M4Sampler, Tex-float2(step*2,0) ) );
    Color += WT_3 * ( tex2D( M4Sampler, Tex+float2(step*3,0) ) + tex2D( M4Sampler, Tex-float2(step*3,0) ) );
    Color += WT_4 * ( tex2D( M4Sampler, Tex+float2(step*4,0) ) + tex2D( M4Sampler, Tex-float2(step*4,0) ) );
    Color += WT_5 * ( tex2D( M4Sampler, Tex+float2(step*5,0) ) + tex2D( M4Sampler, Tex-float2(step*5,0) ) );
    Color += WT_6 * ( tex2D( M4Sampler, Tex+float2(step*6,0) ) + tex2D( M4Sampler, Tex-float2(step*6,0) ) );
    Color += WT_7 * ( tex2D( M4Sampler, Tex+float2(step*7,0) ) + tex2D( M4Sampler, Tex-float2(step*7,0) ) );

    return Color;
    

    
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
    
    
    float step = SampStep.y;
    
    Color  = WT_0 *   tex2D( ScnSamp2, Tex );
    Color += WT_1 * ( tex2D( ScnSamp2, Tex+float2(0,step  ) ) + tex2D( ScnSamp2, Tex-float2(0,step  ) ) );
    Color += WT_2 * ( tex2D( ScnSamp2, Tex+float2(0,step*2) ) + tex2D( ScnSamp2, Tex-float2(0,step*2) ) );
    Color += WT_3 * ( tex2D( ScnSamp2, Tex+float2(0,step*3) ) + tex2D( ScnSamp2, Tex-float2(0,step*3) ) );
    Color += WT_4 * ( tex2D( ScnSamp2, Tex+float2(0,step*4) ) + tex2D( ScnSamp2, Tex-float2(0,step*4) ) );
    Color += WT_5 * ( tex2D( ScnSamp2, Tex+float2(0,step*5) ) + tex2D( ScnSamp2, Tex-float2(0,step*5) ) );
    Color += WT_6 * ( tex2D( ScnSamp2, Tex+float2(0,step*6) ) + tex2D( ScnSamp2, Tex-float2(0,step*6) ) );
    Color += WT_7 * ( tex2D( ScnSamp2, Tex+float2(0,step*7) ) + tex2D( ScnSamp2, Tex-float2(0,step*7) ) );
    
    
    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////

float4 FinalBlendPS(float2 Tex: TEXCOORD0) : COLOR
{
	float4 background = tex2D(ScreenSampler, Tex);//オリジナル描画
	
	float4 background2 = tex2D(M4Sampler, Tex);//リムライト描画
	
	float4 foreground = tex2D(ScnSamp3, Tex);//リムライトぼかし描画
	
	
	#ifndef SCREEN_MODE
    
    
    background.rgb = background.rgb + background2.rgb * RimPower * Tr + foreground.rgb * GauPower * Tr;
    
    background.a += foreground.a;
 	
	#else
	background.rgb = float3(1,1,1) - (float3(1,1,1) - background.rgb) * ( float3(1,1,1) - background2.rgb * RimPower * Tr);
	background.rgb = 1 - (1 - background.rgb) * ( 1 -  foreground.rgb* GauPower * Tr);
	
	background.a += foreground.a;
	
	
	#endif
	
	
	//background = saturate(background);
	
	
	return background;
}


////////////////////////////////////////////////////////////////


#endif


////////////////////////////////////////////////////////////////
// エフェクトテクニック
//
float4 ClearColor = { 0, 0, 0, 0 };


float ClearDepth = 1;

technique PostEffectTec
<
	string Script =
		"RenderColorTarget0=ScreenBuffer;"
		"RenderDepthStencilTarget=DepthBuffer;"

		"ClearSetColor=ClearColor2;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"

		"ScriptExternal=Color;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"

		"ClearSetColor=ClearColor2;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		
        #ifdef USE_GAUSSIAN
		"RenderColorTarget0=M4Map;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		#endif
		
		
		"Pass=PassBlend;"
		
		#ifdef USE_GAUSSIAN
		
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		
		
		"RenderColorTarget0=ScnMap2;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	
		"Pass=Gaussian_X;"
		
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		
		"RenderColorTarget0=ScnMap3;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		
        "Pass=Gaussian_Y;"
         
         
        "RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		
		
        "Pass=FinalBlend;"
        #endif
        
        ;
		
		
>
{
	pass PassBlend < string Script = "Draw=Buffer;"; >
	{
		AlphaBlendEnable = false;
		VertexShader = compile vs_3_0 BlendVS();
		PixelShader  = compile ps_3_0 BlendPS();
	}
	
	
	#ifdef USE_GAUSSIAN
	pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        VertexShader = compile vs_2_0 BlendVS();
        PixelShader  = compile ps_2_0 PS_passX();
    }
	pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        VertexShader = compile vs_2_0 BlendVS();
        PixelShader  = compile ps_2_0 PS_passY();
    }
	pass FinalBlend < string Script = "Draw=Buffer;"; >
	{
		AlphaBlendEnable = false;
		VertexShader = compile vs_3_0 BlendVS();
		PixelShader  = compile ps_3_0 FinalBlendPS();
	}
	
	#endif
	
};
