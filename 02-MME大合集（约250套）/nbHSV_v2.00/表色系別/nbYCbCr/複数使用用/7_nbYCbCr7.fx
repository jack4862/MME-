////////////////////////////////////////////////////////////////////////////////////////////////

#define MODELNAME "7_Controller_nbYCbCr7.pmd"

float Morph01 : CONTROLOBJECT < string name = MODELNAME ; string item = "輝度(Y)+"; >;
float Morph02 : CONTROLOBJECT < string name = MODELNAME ; string item = "輝度(Y)-"; >;
float Morph03 : CONTROLOBJECT < string name = MODELNAME ; string item = "Cb+"; >;
float Morph04 : CONTROLOBJECT < string name = MODELNAME ; string item = "Cb-"; >;
float Morph05 : CONTROLOBJECT < string name = MODELNAME ; string item = "Cr+"; >;
float Morph06 : CONTROLOBJECT < string name = MODELNAME ; string item = "Cr-"; >;
float Morph07 : CONTROLOBJECT < string name = MODELNAME ; string item = "輝度差+"; >;
float Morph08 : CONTROLOBJECT < string name = MODELNAME ; string item = "輝度差-"; >;
float Morph09 : CONTROLOBJECT < string name = MODELNAME ; string item = "輝度基準"; >;
float Morph11 : CONTROLOBJECT < string name = MODELNAME ; string item = "Cb_0収束"; >;
float Morph14 : CONTROLOBJECT < string name = MODELNAME ; string item = "Cr_0収束"; >;
float Morph16 : CONTROLOBJECT < string name = MODELNAME ; string item = "境界_OFF強"; >;
float Morph17 : CONTROLOBJECT < string name = MODELNAME ; string item = "境界_ON強"; >;


float3 PanelXYZ : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
float3 PanelR : CONTROLOBJECT < string name = "(self)"; string item = "Rxyz"; >;
static float Degrees = 45/atan(1);
float PanelSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float PanelTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;




////////////////////////////////////////////////////////////////////////////////////////////////

// 背景のクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

////////////////////////////////////////////////////////////////////////////////////////////////

// ポストエフェクトでは必ず以下の設定をする。
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// オリジナルの描画結果を記録するためのレンダーターゲット
texture ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
>;
sampler ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
};

// 深度バッファ
texture DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
>;


////////////////////////////////////////////////////////////////////////////////////////////////
// 作業用テクスチャ
texture YCbCr7 : OFFSCREENRENDERTARGET <
	string Description = "for nbYCbCr";
	float4 ClearColor = { 0, 0, 0, 0 };
	float ClearDepth = 1.0;
	bool AntiAlias = true;
	int Miplevels = 1;
	string DefaultEffect =
		"self = hide;"
		"* = ../ycbcr_OFF.fx"
		;
>;
sampler HSVSampler = sampler_state {
	texture = <YCbCr7>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
////////////////////////////////////////////////////////////////////////////////////////////////





// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

// 半ピクセル
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);


struct VS_OUTPUT {
    float4 Pos			: POSITION;
    float2 Tex			: TEXCOORD0;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// シェーダ

VS_OUTPUT VS_DrawBuffer( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out; 
    
    Out.Pos = Pos;
    //Out.Tex = Tex;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

float4 PS_DrawBuffer(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color = tex2D( ScnSamp, Tex );
    float4 OnOff = tex2D( HSVSampler, Tex);
    float4 OriginalC = Color;
    float GrayCheck = 1 + Morph16 - Morph17 + (1 - PanelTr);  //nbYCbCrではTrが空いたので境界_OFF強できるようにした。

    float YCheck1 = Morph07 * 10 - Morph08 + PanelR[0] * Degrees;
    float YCheck2 = Morph01 - Morph02 + PanelXYZ[0];
    float CbCheck1 = - Morph11 - PanelR[1] * Degrees;
    float CbCheck2 = Morph03 - Morph04 + PanelXYZ[1];
    float CrCheck1 = - Morph14 - PanelR[2] * Degrees;
    float CrCheck2 = Morph05 - Morph06 + PanelXYZ[2];


  if (OnOff.r != 0)
  {   
    if (YCheck1 != 0 || YCheck2 != 0 || CbCheck1 != 0 || CbCheck2 != 0 || CrCheck1 != 0 || CrCheck2 != 0) {

    // 処理
    float3 YCbCr = {0,0,0};
    YCbCr[0] = 0.299 * Color.r + 0.587 * Color.g + 0.114 * Color.b;
    YCbCr[1] = -0.168736 * Color.r - 0.331264 * Color.g + 0.5 * Color.b;
    YCbCr[2] = 0.5 * Color.r - 0.418688 * Color.g - 0.081312 * Color.b;

    //輝度調整
    YCbCr[0] = YCbCr[0] + (YCbCr[0] - Morph09 - (1 - PanelSi * 0.1)) * YCheck1;
    YCbCr[0] += YCheck2;
    if (YCbCr[0] < 0) {YCbCr[0] = 0;}
    if (YCbCr[0] > 1) {YCbCr[0] = 1;}
 
    //Cb調整
    YCbCr[1] = YCbCr[1] + YCbCr[1] * CbCheck1;
    YCbCr[1] += CbCheck2;
    if (YCbCr[1] < -0.5) {YCbCr[1] = -0.5;}
    if (YCbCr[1] > 0.5) {YCbCr[1] = 0.5;}

    //Cr調整
    YCbCr[2] = YCbCr[2] + YCbCr[2] * CrCheck1;
    YCbCr[2] += CrCheck2;
    if (YCbCr[2] < -0.5) {YCbCr[2] = -0.5;}
    if (YCbCr[2] > 0.5) {YCbCr[2] = 0.5;}


    Color.r = YCbCr[0] + 1.402 * YCbCr[2];
    Color.g = YCbCr[0] - 0.344136 * YCbCr[1] - 0.714136 * YCbCr[2];
    Color.b = YCbCr[0] + 1.772 * YCbCr[1];

    if (OnOff.r != 1 && GrayCheck != 0) {Color.rgb = OriginalC.rgb * (1-OnOff.r/GrayCheck) + Color.rgb * OnOff.r/GrayCheck;}

    }
  }


    
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
        "Pass=DrawBuffer;"
    ;
> {
    pass DrawBuffer < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_DrawBuffer();
        PixelShader  = compile ps_3_0 PS_DrawBuffer();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////


