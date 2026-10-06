// アルファ透過時の背景色（各値はRGBAで0～1。一番右は0のままにする）
float4 ClearColor = { 0, 0, 0, 0 };








// ポストエフェクト宣言
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// オリジナル画像
texture OrgTex : RENDERCOLORTARGET <
    string Format = "A8R8G8B8";
    float2 ViewPortRatio = {1,1};
>;
sampler OrgSamp = sampler_state {
    texture = <OrgTex>;
    MinFilter = POINT;
    MagFilter = POINT;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// アルファ再描画
texture AlphaMap: OFFSCREENRENDERTARGET <
    string Description = "アルファ値を無視したいモデルはチェックをはずしてください";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = "*=main_default;";
>;
sampler AlphaSamp = sampler_state {
    texture = <AlphaMap>;
    MinFilter = POINT;
    MagFilter = POINT;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = float2(0.5,0.5)/ViewportSize;

////////////////////////////////////////////////////////////////


/////////////////////////////
// 合成用のシェーダ
struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 Tex: TEXCOORD0;
};

VS_OUTPUT CopyVS(float4 Pos : POSITION, float2 Tex : TEXCOORD0 ){ 
    VS_OUTPUT Out;
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    return Out;
}

float4 MixPS(float2 Tex: TEXCOORD0) : COLOR {
    float4 OrgColor = tex2D(OrgSamp, Tex);
    float4 MaskColor = tex2D(AlphaSamp, Tex);
    OrgColor.a = MaskColor.a;
    return OrgColor;
}


////////////////////////////////////////////////////////////////
// エフェクトテクニック
//
float ClearDepth  = 1;

technique PostEffectTec <
    string Script =
        "RenderColorTarget=OrgTex;"
        "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"

        "RenderColorTarget=;"
        "RenderDepthStencilTarget=;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=PassMix;"
    ;
>{
    pass PassMix < string Script = "Draw=Buffer;"; >{
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_2_0 CopyVS();
        PixelShader  = compile ps_2_0 MixPS();
    }
};
