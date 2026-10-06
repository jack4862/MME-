////////////////////////////////////////////////////////////////////////////////////////////////

#define MODELNAME "Controller_nbHSV.pmd"

float Morph01 : CONTROLOBJECT < string name = MODELNAME ; string item = "色相(H)+"; >;
float Morph02 : CONTROLOBJECT < string name = MODELNAME ; string item = "色相(H)-"; >;
float Morph03 : CONTROLOBJECT < string name = MODELNAME ; string item = "彩度(S)+"; >;
float Morph04 : CONTROLOBJECT < string name = MODELNAME ; string item = "彩度(S)-"; >;
float Morph05 : CONTROLOBJECT < string name = MODELNAME ; string item = "明度(V)+"; >;
float Morph06 : CONTROLOBJECT < string name = MODELNAME ; string item = "明度(V)-"; >;
float Morph07 : CONTROLOBJECT < string name = MODELNAME ; string item = "色相差+"; >;
float Morph08 : CONTROLOBJECT < string name = MODELNAME ; string item = "色相差-"; >;
float Morph09 : CONTROLOBJECT < string name = MODELNAME ; string item = "色相基準"; >;
float Morph10 : CONTROLOBJECT < string name = MODELNAME ; string item = "彩度差+"; >;
float Morph11 : CONTROLOBJECT < string name = MODELNAME ; string item = "彩度差-"; >;
float Morph12 : CONTROLOBJECT < string name = MODELNAME ; string item = "彩度基準"; >;
float Morph13 : CONTROLOBJECT < string name = MODELNAME ; string item = "明度差+"; >;
float Morph14 : CONTROLOBJECT < string name = MODELNAME ; string item = "明度差-"; >;
float Morph15 : CONTROLOBJECT < string name = MODELNAME ; string item = "明度基準"; >;
float Morph16 : CONTROLOBJECT < string name = MODELNAME ; string item = "境界_OFF強"; >;
float Morph17 : CONTROLOBJECT < string name = MODELNAME ; string item = "境界_ON強"; >;

float Morph21 : CONTROLOBJECT < string name = MODELNAME ; string item = "輝度(Y)+"; >;
float Morph22 : CONTROLOBJECT < string name = MODELNAME ; string item = "輝度(Y)-"; >;
//float Morph23 : CONTROLOBJECT < string name = MODELNAME ; string item = "Cb+"; >;
//float Morph24 : CONTROLOBJECT < string name = MODELNAME ; string item = "Cb-"; >;
//float Morph25 : CONTROLOBJECT < string name = MODELNAME ; string item = "Cr+"; >;
//float Morph26 : CONTROLOBJECT < string name = MODELNAME ; string item = "Cr-"; >;
float Morph27 : CONTROLOBJECT < string name = MODELNAME ; string item = "輝度差+"; >;
float Morph28 : CONTROLOBJECT < string name = MODELNAME ; string item = "輝度差-"; >;
float Morph29 : CONTROLOBJECT < string name = MODELNAME ; string item = "輝度基準"; >;
//float Morph31 : CONTROLOBJECT < string name = MODELNAME ; string item = "Cb_0収束"; >;
float Morph32 : CONTROLOBJECT < string name = MODELNAME ; string item = "CbCr_0収束"; >;
//float Morph34 : CONTROLOBJECT < string name = MODELNAME ; string item = "Cr_0収束"; >;

float Morph41 : CONTROLOBJECT < string name = MODELNAME ; string item = "赤(R)+"; >;
float Morph42 : CONTROLOBJECT < string name = MODELNAME ; string item = "赤(R)-"; >;
float Morph43 : CONTROLOBJECT < string name = MODELNAME ; string item = "緑(G)+"; >;
float Morph44 : CONTROLOBJECT < string name = MODELNAME ; string item = "緑(G)-"; >;
float Morph45 : CONTROLOBJECT < string name = MODELNAME ; string item = "青(B)+"; >;
float Morph46 : CONTROLOBJECT < string name = MODELNAME ; string item = "青(B)-"; >;
float Morph47 : CONTROLOBJECT < string name = MODELNAME ; string item = "赤差+"; >;
float Morph48 : CONTROLOBJECT < string name = MODELNAME ; string item = "赤差-"; >;
float Morph49 : CONTROLOBJECT < string name = MODELNAME ; string item = "赤基準"; >;
float Morph50 : CONTROLOBJECT < string name = MODELNAME ; string item = "緑差+"; >;
float Morph51 : CONTROLOBJECT < string name = MODELNAME ; string item = "緑差-"; >;
float Morph52 : CONTROLOBJECT < string name = MODELNAME ; string item = "緑基準"; >;
float Morph53 : CONTROLOBJECT < string name = MODELNAME ; string item = "青差+"; >;
float Morph54 : CONTROLOBJECT < string name = MODELNAME ; string item = "青差-"; >;
float Morph55 : CONTROLOBJECT < string name = MODELNAME ; string item = "青基準"; >;

float Morph99 : CONTROLOBJECT < string name = MODELNAME ; string item = "透過判定確認"; >;


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
texture HSV1 : OFFSCREENRENDERTARGET <
	string Description = "for nbHSV";
	float4 ClearColor = { 0, 0, 0, 0 };
	float ClearDepth = 1.0;
	bool AntiAlias = true;
	int Miplevels = 1;
	string DefaultEffect =
		"self = hide;"
		"* = hsv_ON.fx"
		;
>;
sampler HSVSampler = sampler_state {
	texture = <HSV1>;
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
// 式


static float3 ToHSV(float3 rgb) {
     float MAXRGB = max(max(rgb[0],rgb[1]), rgb[2]);
     float MINRGB = min(min(rgb[0],rgb[1]), rgb[2]);
     float3 VALHSV = {0,0,MAXRGB};
     float DIFRGB = MAXRGB - MINRGB;
     
     if (DIFRGB != 0)
     {
      if (MAXRGB == rgb[0]) {VALHSV[0] = (rgb[1] - rgb[2]) / DIFRGB;}
      else if (MAXRGB == rgb[1]) {VALHSV[0] = ((rgb[2] - rgb[0]) / DIFRGB ) + 2;}
      else {VALHSV[0] = ((rgb[0] - rgb[1]) / DIFRGB ) + 4;}

      VALHSV[1] = DIFRGB / MAXRGB;
     }
       
     VALHSV[0] = (VALHSV[0] < 0) * 6 + VALHSV[0]; //RGBに戻す時都合がよいのでHは0～6の範囲にする。

     return VALHSV;
}

static float3 ToRGB(float3 hsv) {
     float MINHSV =  hsv[2] - hsv[1] *  hsv[2];
     float3 VALRGB = {hsv[2], hsv[2], hsv[2]};
     float DIFHSV =  hsv[2] - MINHSV;

       if (hsv[0] <= 1) {
          VALRGB[1] = hsv[0] * DIFHSV + MINHSV;
          VALRGB[2] = MINHSV;}
       else if (hsv[0] <= 2) {
          VALRGB[0] = (2 - hsv[0]) * DIFHSV + MINHSV;
          VALRGB[2] = MINHSV;}
       else if (hsv[0] <= 3) {
          VALRGB[0] = MINHSV;
          VALRGB[2] = (hsv[0] - 2) * DIFHSV + MINHSV;}
       else if (hsv[0] <= 4) {
          VALRGB[0] = MINHSV;
          VALRGB[1] = (4 - hsv[0]) * DIFHSV + MINHSV;}
       else if (hsv[0] <= 5) {
          VALRGB[0] = (hsv[0] - 4) * DIFHSV + MINHSV;
          VALRGB[1] = MINHSV;}
       else {
          VALRGB[1] = MINHSV;
          VALRGB[2] = (6 - hsv[0]) * DIFHSV + MINHSV;}
          
     return VALRGB;
}





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
    float GrayCheck = 1 + Morph16 - Morph17;

  if (OnOff.r == 0)
  {Color.rgb = OriginalC.rgb;} else {

    //★HSV
    //処理(HSV)
    float3 ConC1 = ToHSV(Color.rgb);

    if (PanelR[0] > 0) {PanelR[0] *= 10;}
    if (PanelR[1] > 0) {PanelR[1] *= 10;}
    if (PanelR[2] > 0) {PanelR[2] *= 10;}

    //色相調整
    ConC1[0] = ConC1[0] + (ConC1[0] - Morph09 * 6 - (1 - PanelSi * 0.1) * 6) * (Morph07 * 10 - Morph08 + PanelR[0] * Degrees);
    //if (ConC1[0] < 0) {ConC1[0] = 0;}
    //if (ConC1[0] > 6) {ConC1[0] = 6;}
    ConC1[0] += (Morph01 - Morph02 + PanelXYZ[0]) * 6;    
    if (ConC1[0] < 0) {ConC1[0] = 6 + (ConC1[0] % 6);}
    if (ConC1[0] > 6) {ConC1[0] %= 6;}

    //彩度調整
    ConC1[1] = ConC1[1] + (ConC1[1] - Morph12 - 1 + PanelTr) * (Morph10 * 10 - Morph11 + PanelR[1] * Degrees);
    ConC1[1] += (Morph03 - Morph04 + PanelXYZ[1]);
    if (ConC1[1] < 0) {ConC1[1] = 0;}
    if (ConC1[1] > 1) {ConC1[1] = 1;}

    //明度調整
    ConC1[2] = ConC1[2] + (ConC1[2] - Morph15 - 1 + PanelTr) * (Morph13 * 10 - Morph14 + PanelR[2] * Degrees);
    ConC1[2] += (Morph05 - Morph06 + PanelXYZ[2]);
    if (ConC1[2] < 0) {ConC1[2] = 0;}
    if (ConC1[2] > 1) {ConC1[2] = 1;}
    
    //HSVからRGB
    float3 ConC2 = ToRGB(ConC1); 
    Color.rgb = float3(ConC2[0], ConC2[1], ConC2[2]); 

    
    //★RGB
    //処理(RGB)
    float3 RgbC1 = Color.rgb; 

    //R調整
    RgbC1[0] = RgbC1[0] + (RgbC1[0] - Morph49) * (Morph47 * 10 - Morph48);
    RgbC1[0] += (Morph41 - Morph42);
    if (RgbC1[0] < 0) {RgbC1[0] = 0;}
    if (RgbC1[0] > 1) {RgbC1[0] = 1;}

    //G調整
    RgbC1[1] = RgbC1[1] + (RgbC1[1] - Morph52) * (Morph50 * 10 - Morph51);
    RgbC1[1] += (Morph43 - Morph44);
    if (RgbC1[1] < 0) {RgbC1[1] = 0;}
    if (RgbC1[1] > 1) {RgbC1[1] = 1;}

    //B調整
    RgbC1[2] = RgbC1[2] + (RgbC1[2] - Morph55) * (Morph53 * 10 - Morph54);
    RgbC1[2] += (Morph45 - Morph46);
    if (RgbC1[2] < 0) {RgbC1[2] = 0;}
    if (RgbC1[2] > 1) {RgbC1[2] = 1;}
    
    Color.rgb = float3(RgbC1[0], RgbC1[1], RgbC1[2]);


    //★YCbCr
    float YCheck1 = Morph27 * 10 - Morph28;
    float YCheck2 = Morph21 - Morph22;
    //float CbCheck1 = - Morph31;
    //float CbCheck2 = Morph23 - Morph24;
    //float CrCheck1 = - Morph34;
    //float CrCheck2 = Morph25 - Morph26;
    float CbCrCheck = - Morph32;
 
    if (YCheck1 != 0 || YCheck2 != 0 || CbCrCheck != 0) {

    //処理(YCbCr)
    float3 YCbCr = {0,0,0};
    YCbCr[0] = 0.299 * Color.r + 0.587 * Color.g + 0.114 * Color.b;
    YCbCr[1] = -0.168736 * Color.r - 0.331264 * Color.g + 0.5 * Color.b;
    YCbCr[2] = 0.5 * Color.r - 0.418688 * Color.g - 0.081312 * Color.b;

    //輝度調整
    YCbCr[0] = YCbCr[0] + (YCbCr[0] - Morph29) * YCheck1;
    YCbCr[0] += YCheck2;
    if (YCbCr[0] < 0) {YCbCr[0] = 0;}
    if (YCbCr[0] > 1) {YCbCr[0] = 1;}
 
    //Cb調整
    YCbCr[1] = YCbCr[1] + YCbCr[1] * CbCrCheck;
    //YCbCr[1] += CbCheck2;
    if (YCbCr[1] < -0.5) {YCbCr[1] = -0.5;}
    if (YCbCr[1] > 0.5) {YCbCr[1] = 0.5;}

    //Cr調整
    YCbCr[2] = YCbCr[2] + YCbCr[2] * CbCrCheck;
    //YCbCr[2] += CrCheck2;
    if (YCbCr[2] < -0.5) {YCbCr[2] = -0.5;}
    if (YCbCr[2] > 0.5) {YCbCr[2] = 0.5;}

    Color.r = YCbCr[0] + 1.402 * YCbCr[2];
    Color.g = YCbCr[0] - 0.344136 * YCbCr[1] - 0.714136 * YCbCr[2];
    Color.b = YCbCr[0] + 1.772 * YCbCr[1];
    }


    //境界処理
    if (OnOff.r != 1 && GrayCheck != 0) {Color.rgb = OriginalC.rgb * (1-OnOff.r/GrayCheck) + Color.rgb * OnOff.r/GrayCheck;}


    //★透過判定確認
    if (Morph99 == 1) {
      if (OnOff.r != 1) {Color = float4(1.0,0,0,1.0);}
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


