////////////////////////////////////////////////////////////////////////////////////////////////

#define MODELNAME "4_Controller_nbRGB4.pmd"  //nbRGBと違うところ(1/4)

float Morph01 : CONTROLOBJECT < string name = MODELNAME ; string item = "赤(R)+"; >;
float Morph02 : CONTROLOBJECT < string name = MODELNAME ; string item = "赤(R)-"; >;
float Morph03 : CONTROLOBJECT < string name = MODELNAME ; string item = "緑(G)+"; >;
float Morph04 : CONTROLOBJECT < string name = MODELNAME ; string item = "緑(G)-"; >;
float Morph05 : CONTROLOBJECT < string name = MODELNAME ; string item = "青(B)+"; >;
float Morph06 : CONTROLOBJECT < string name = MODELNAME ; string item = "青(B)-"; >;
float Morph07 : CONTROLOBJECT < string name = MODELNAME ; string item = "赤差+"; >;
float Morph08 : CONTROLOBJECT < string name = MODELNAME ; string item = "赤差-"; >;
float Morph09 : CONTROLOBJECT < string name = MODELNAME ; string item = "赤基準"; >;
float Morph10 : CONTROLOBJECT < string name = MODELNAME ; string item = "緑差+"; >;
float Morph11 : CONTROLOBJECT < string name = MODELNAME ; string item = "緑差-"; >;
float Morph12 : CONTROLOBJECT < string name = MODELNAME ; string item = "緑基準"; >;
float Morph13 : CONTROLOBJECT < string name = MODELNAME ; string item = "青差+"; >;
float Morph14 : CONTROLOBJECT < string name = MODELNAME ; string item = "青差-"; >;
float Morph15 : CONTROLOBJECT < string name = MODELNAME ; string item = "青基準"; >;
float Morph16 : CONTROLOBJECT < string name = MODELNAME ; string item = "境界_OFF強"; >;
float Morph17 : CONTROLOBJECT < string name = MODELNAME ; string item = "境界_ON強"; >;

float3 PanelXYZ : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
float3 PanelR : CONTROLOBJECT < string name = "(self)"; string item = "Rxyz"; >;
static float Degrees = 45/atan(1);
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
texture RGB4 : OFFSCREENRENDERTARGET <  //nbRGBと違うところ(2/4)
	string Description = "for nbRGB";
	float4 ClearColor = { 0, 0, 0, 0 };
	float ClearDepth = 1.0;
	bool AntiAlias = true;
	int Miplevels = 1;
	string DefaultEffect =
		"self = hide;"
		"* = ../rgb_OFF.fx"  //nbRGBと違うところ(3/4)
		;
>;
sampler HSVSampler = sampler_state {
	texture = <RGB4>;  //nbRGBと違うところ(4/4)
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

    // 処理
    float3 RgbC1 = Color.rgb; 
    //反映前のColor.rgbが0～1の範囲外であっても切り捨てられない場合は(nbHSVと挙動を合すため)不要と考えたが
    //境界処理で乗算するためどちらにしても必要だと判断。

    if (PanelR[0] > 0) {PanelR[0] *= 10;}
    if (PanelR[1] > 0) {PanelR[1] *= 10;}
    if (PanelR[2] > 0) {PanelR[2] *= 10;}


    //R調整
    RgbC1[0] = RgbC1[0] + (RgbC1[0] - Morph09 - 1 + PanelTr) * (Morph07 * 10 - Morph08 + PanelR[0] * Degrees);
    RgbC1[0] += (Morph01 - Morph02 + PanelXYZ[0]);
    if (RgbC1[0] < 0) {RgbC1[0] = 0;}
    if (RgbC1[0] > 1) {RgbC1[0] = 1;}


    //G調整
    RgbC1[1] = RgbC1[1] + (RgbC1[1] - Morph12 - 1 + PanelTr) * (Morph10 * 10 - Morph11 + PanelR[1] * Degrees);
    RgbC1[1] += (Morph03 - Morph04 + PanelXYZ[1]);
    if (RgbC1[1] < 0) {RgbC1[1] = 0;}
    if (RgbC1[1] > 1) {RgbC1[1] = 1;}


    //B調整
    RgbC1[2] = RgbC1[2] + (RgbC1[2] - Morph15 - 1 + PanelTr) * (Morph13 * 10 - Morph14 + PanelR[2] * Degrees);
    RgbC1[2] += (Morph05 - Morph06 + PanelXYZ[2]);
    if (RgbC1[2] < 0) {RgbC1[2] = 0;}
    if (RgbC1[2] > 1) {RgbC1[2] = 1;}
    
    Color.rgb = float3(RgbC1[0], RgbC1[1], RgbC1[2]); 

    if (OnOff.r != 1 && GrayCheck != 0) {Color.rgb = OriginalC.rgb * (1-OnOff.r/GrayCheck) + Color.rgb * OnOff.r/GrayCheck;}
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


