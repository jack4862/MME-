////////////////////////////////////////////////////////////////////////////////////////////////
//
//  FunyaFunya_Post.fx ver0.0.1  ふにゃふにゃエフェクト(ポストエフェクトver)
//  作成: 針金P( 舞力介入P氏のGaussian.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
#define WAVETYPE  1                // 0とそれ以外で揺れ方が変わります
float Amplitude = 0.01;            // 波の振幅(画面幅の比率で入力)
float2 WaveNumber = {0.0, 20.0};   // 波数ベクトル(大きくすると波形が小刻みになります)
float AngularFrequency = 2.0;      // 角周波数(大きくすると波の進行が速くなります)


// 解らない人はここから下はいじらないでね

float time_0_X : Time;

// アクセサリパラメータ
float4x4 WorldMatrix : WORLD;
static float3 AcsOffset = WorldMatrix._41_42_43;
static float AcsScaling = length(WorldMatrix._11_12_13)/10; 


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

static float2 SampStep = (float2(2,2)/ViewportSize);


// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
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
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;


////////////////////////////////////////////////////////////////////////////////////////////////
// ふにゃふにゃシェーダ

struct VS_OUTPUT {
    float4 Pos			: POSITION;
    float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_Funya( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + float2(0, ViewportOffset.y);

    return Out;
}

float4 PS_Funya( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;

    float a = Amplitude*AcsScaling;
    float kx = WaveNumber.x + AcsOffset.x;
    float ky = WaveNumber.y + AcsOffset.y;
    float freq = AngularFrequency + AcsOffset.z;

#if(WAVETYPE)
    float x = a*sin(kx*Tex.x - ky*Tex.y - freq*time_0_X);
    float y = a*sin(ky*Tex.x + kx*Tex.y - freq*time_0_X);
#else
    float x = a*sin(ky*Tex.y - freq*time_0_X);
    float y = a*sin(kx*Tex.x - freq*time_0_X);
#endif

    Color = tex2D( ScnSamp, Tex+float2(x, y) );

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique FunyaTech <
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
	    "Pass=FunyaPass;"
    ;
> {
    pass FunyaPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Funya();
        PixelShader  = compile ps_2_0 PS_Funya();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
