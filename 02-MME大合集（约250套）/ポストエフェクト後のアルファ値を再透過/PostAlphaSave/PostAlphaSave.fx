


////////////////////////////////////////////////////////////////////////////////////////////////
// 以下は改造に興味のある方だけ触ってみてください

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);


// レンダリングターゲットのクリア値
float4 ClearColorWhite = float4(1.0f, 1.0f, 1.0f, 0.0f);
float4 ClearColorBlack = float4(0.0f, 0.0f, 0.0f, 0.0f);
float ClearDepth  = 1.0f;

// 共有マスク
shared texture2D CommonClippingMask : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8";
>;

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

// オリジナル画像処理用テクスチャ
texture OrgScreen : RENDERCOLORTARGET <
    string Format = "A8R8G8B8";
    float2 ViewPortRatio = {1,1};
>;
sampler OrgSampler = sampler_state {
    texture = <OrgScreen>;
    MinFilter = POINT;
    MagFilter = POINT;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};






////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
static float Scaling = AcsSi * 0.1f;

texture CCM_SimpleMask: OFFSCREENRENDERTARGET <
    string Description = "ORT for CCM_SimpleMask";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = "*=hide;";
>;
sampler MaskSmp = sampler_state {
    texture = <CCM_SimpleMask>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};



// コピー用のシェーダ
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

float4 MaskPS(float2 Tex: TEXCOORD0) : COLOR {
    float4 org = tex2D(OrgSampler, Tex);
    return org.a;
}

float4 CopyPS(float2 Tex: TEXCOORD0) : COLOR {
    float4 org = tex2D(OrgSampler, Tex);
    return org;
}




////////////////////////////////////////////////////////////////////////////////////////////////

technique MainTec < string MMDPass = "object";
    string Script = 
        "RenderColorTarget=OrgScreen;"
        "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColorBlack;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"
            
        "RenderColorTarget0=CommonClippingMask;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColorBlack;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;" "Clear=Depth;"
            "Pass=DrawMask;"
            
        "RenderColorTarget=;"
        "RenderDepthStencilTarget=;"
            "ClearSetColor=ClearColorBlack;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=CopyOrg;"
    ;
> {
    pass DrawMask < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable  = false;
        VertexShader = compile vs_2_0 CopyVS();
        PixelShader  = compile ps_2_0 MaskPS();
    }
    pass CopyOrg < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable  = false;
        VertexShader = compile vs_2_0 CopyVS();
        PixelShader  = compile ps_2_0 CopyPS();
    }
}


// エッジは描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
// 地面影は描画しない
technique ShadowTec < string MMDPass = "shadow"; > { }
// MMD標準のセルフシャドウは描画しない
technique ZplotTec < string MMDPass = "zplot"; > { }

