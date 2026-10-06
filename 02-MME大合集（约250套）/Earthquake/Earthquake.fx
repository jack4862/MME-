////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Earthquake.fx ver0.0.1  地震エフェクト
//  作成: 針金P( 舞力介入P氏のGaussian.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
#define ScnScale 1.0      // 外縁の歪みが気になる場合はこの数値を上げる(1～1.25程度)
float AmplitudeX = 0.03;  // 横揺れ振幅(画面幅の比率で入力)
float AmplitudeY = 0.02;  // 縦揺れ振幅(画面高の比率で入力)
float Frequency = 10.0;   // 周波数(大きくすると振動が速くなります)


// 解らない人はここから下はいじらないでね

float time_0_X : Time;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize/ScnScale);
static float2 SampStep = (float2(1,1)/ViewportSize/ScnScale);

// アクセサリパラメータ
float4x4 WorldMatrix : WORLD;
static float3 AcsOffset = WorldMatrix._41_42_43;
static float AcsScaling = length(WorldMatrix._11_12_13)/10; 


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {ScnScale, ScnScale};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {ScnScale, ScnScale};
    string Format = "D24S8";
>;


////////////////////////////////////////////////////////////////////////////////////////////////
// 地震シェーダ

struct VS_OUTPUT {
    float4 Pos			: POSITION;
    float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_Earthquake( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex;

    return Out;
}

float4 PS_Earthquake( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;

    float offset = 0.5 - 0.5/ScnScale;

    float ax = AmplitudeX * AcsScaling;
    float ay = AmplitudeY * AcsScaling;
    float freq = Frequency + AcsOffset.z;

    float x = 0.66*ax*(sin(2*(int)(time_0_X*freq+2)) + 0.33*cos(3*(int)(time_0_X*freq/2)));
    float y = 0.66*ay*(sin(3*(int)(time_0_X*freq)) + 0.33*cos(2*(int)(time_0_X*freq/1.2+1)));

    x = offset + (Tex.x + x)/ScnScale;
    y = offset + (Tex.y + y)/ScnScale;

    x = (int)(x/SampStep.x)*SampStep.x + ViewportOffset.x;
    y = (int)(y/SampStep.y)*SampStep.y + ViewportOffset.y;

    Color = tex2D( ScnSamp, float2(x, y) );

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique EarthquakeTech <
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
	    "Pass=EarthquakePass;"
    ;
> {
    pass EarthquakePass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Earthquake();
        PixelShader  = compile ps_2_0 PS_Earthquake();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////

