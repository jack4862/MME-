////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "object";
    string ScriptOrder = "postprocess";
> = 0.8;

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrix          : WORLDVIEW;

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;


///////////////////////////////////////////////////////////////////////////////////////////////
// 鏡関連

// テクスチャのサイズ
#define WIDTH   1024
#define HEIGHT  1024

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;

// 鏡に反射したオブジェクトの描画結果を記録するためのレンダーターゲット
shared texture MirrorTex : RENDERCOLORTARGET <
    float Width = WIDTH;
    float Height = HEIGHT;
>;
shared texture MirrorDepthBuffer : RENDERDEPTHSTENCILTARGET <
    float Width = WIDTH;
    float Height = HEIGHT;
>;

sampler MirrorView = sampler_state {
    texture = <MirrorTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT Mirror_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( dot(WorldViewMatrix[2].xyz,WorldViewMatrix[3].xyz) > 0 ) {
        // 鏡の表の面の場合、X軸を反転して描画しているので、ここで反転する。
        Out.Tex.x = 1 - Out.Tex.x;
    }
    
    return Out;
}

// ピクセルシェーダ
float4 Mirror_PS(VS_OUTPUT IN) : COLOR0
{
    return tex2D(MirrorView, IN.Tex);
}

technique MainTec <
    string Script = 
        "RenderColorTarget0=MirrorTex;"
	    "RenderDepthStencilTarget=MirrorDepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "ScriptExternal=Color;"
	    "Pass=DrawObject;"
    ;
> {
    pass DrawObject {
        CULLMODE = NONE;
        VertexShader = compile vs_2_0 Mirror_VS();
        PixelShader  = compile ps_2_0 Mirror_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
