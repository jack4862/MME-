////////////////////////////////////////////////////////////////////////////////////////////////
//
//  LocalShadow.fx ver0.0.1  局所的に独自設定のセルフシャドウ描画を行う
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "standard";
> = 0.8;

#define LOCALSHADOW_MAIN
#include "LocalShadow_Header.fxh"

// シャドウマップバッファサイズ
#define SMAPSIZE_WIDTH   LS_ShadowMapBuffSize
#define SMAPSIZE_HEIGHT  LS_ShadowMapBuffSize

#if LS_UseSoftShadow==1
    #define TEX_FORMAT  "D3DFMT_G32R32F"
    #define TEX_MIPLEVELS  0
#else
    #define TEX_FORMAT  "D3DFMT_R32F"
    #define TEX_MIPLEVELS  1
#endif

// オフスクリーンシャドウマップバッファ
texture LSMapRT2 : OFFSCREENRENDERTARGET <
    string Description = "PAToonコントローラーのシャドウマップ";
    int Width  = SMAPSIZE_WIDTH;
    int Height = SMAPSIZE_HEIGHT;
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
    string Format = "D3DFMT_R32F";
    bool AntiAlias = false;
    int Miplevels = 1;
    string DefaultEffect = 
        "self = hide;"
        "MMM_DummyModel = LocalShadow_ShadowMap.fxsub;"
        "* = LocalShadow_ShadowMap.fxsub;";
>;
sampler2D SampLocalShadowMap = sampler_state {
    texture = <LSMapRT2>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

// シャドウマップバッファのコピー
shared texture2D LocalShadow_SMapBuff : RENDERCOLORTARGET <
    int Width  = SMAPSIZE_WIDTH;
    int Height = SMAPSIZE_HEIGHT;
    int Miplevels = TEX_MIPLEVELS;
    string Format = TEX_FORMAT;
>;
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    int Width  = SMAPSIZE_WIDTH;
    int Height = SMAPSIZE_HEIGHT;
    string Format = "D3DFMT_D24S8";
>;

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;


////////////////////////////////////////////////////////////////////////////////////////////////
// オフスクリーンシャドウマップの受け渡し

struct VS_OUTPUT0 {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

// 頂点シェーダ
VS_OUTPUT0 VS_SMapCopy( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
    VS_OUTPUT0 Out = (VS_OUTPUT0)0; 
    Out.Pos = Pos;
    Out.Tex = Tex + float2(0.5f/SMAPSIZE_WIDTH, 0.5f/SMAPSIZE_HEIGHT);
    return Out;
}

// ピクセルシェーダ
float4 PS_SMapCopy( float2 Tex: TEXCOORD0 ) : COLOR
{
    float z = tex2D( SampLocalShadowMap, Tex ).r;

    #if LS_UseSoftShadow==1
    return float4(z, z*z, 0, 1);
    #else
    return float4(z, 0, 0, 1);
    #endif
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

// 座標変換行列
float4x4 WorldMatrix    : WORLD;
float4x4 ViewMatrix     : VIEW;
float4x4 ProjMatrix     : PROJECTION;
float4x4 ViewProjMatrix : VIEWPROJECTION;

// カメラ位置
float3 CameraPosition : POSITION  < string Object = "Camera"; >;
// ライト方向
float3 LightDirection : DIRECTION < string Object = "Light"; >;

// マテリアル色
float4 MaterialDiffuse  : DIFFUSE  < string Object = "Geometry"; >;
float3 MaterialAmbient  : AMBIENT  < string Object = "Geometry"; >;
float3 MaterialEmmisive : EMISSIVE < string Object = "Geometry"; >;
float3 MaterialToon     : TOONCOLOR;
static float3 AmbientColor  = MaterialAmbient * float3(0.6f, 0.6f, 0.6f) + MaterialEmmisive;


//MMM対応
#ifndef MIKUMIKUMOVING
    struct VS_INPUT{
        float4 Pos    : POSITION;
        float3 Normal : NORMAL;
    };
    #define MMM_SKINNING
    #define GETPOS     (IN.Pos)
    #define GETNORMAL  (IN.Normal)
    #define GET_VPMAT(p) (ViewProjMatrix)
#else
    #define VS_INPUT  MMM_SKINNING_INPUT
    #define MMM_SKINNING  MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);
    #define GETPOS     (SkinOut.Position)
    #define GETNORMAL  (SkinOut.Normal)
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif


struct VS_OUTPUT {
    float4 Pos    : POSITION;    // 射影変換座標
    float3 Normal : TEXCOORD2;   // 法線
    float4 Color  : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT VS_Object( VS_INPUT IN )
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    MMM_SKINNING

    // ワールド座標変換
    float4 Pos = mul( GETPOS, WorldMatrix );

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );

    // 頂点法線
    Out.Normal = normalize( mul( GETNORMAL, (float3x3)WorldMatrix ) );

    // ディフューズ色＋アンビエント色 計算
    Out.Color = float4(AmbientColor, MaterialDiffuse.a);

    return Out;
}

// ピクセルシェーダ
float4 PS_Object(VS_OUTPUT IN) : COLOR0
{
    float4 Color = IN.Color;

    clip( Color.a - 0.1f );

    // トゥーン適用
    float LightNormal = dot( IN.Normal, -LightDirection );
    Color.rgb *= lerp(MaterialToon, float3(1,1,1), saturate(LightNormal * 16 + 0.5));

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTech0 < string MMDPass = "object"; string Subset = "0";
    string Script = 
        "RenderColorTarget0=LocalShadow_SMapBuff;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=SMapCopyPass;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
    ;
> {
    pass SMapCopyPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_2_0 VS_SMapCopy();
        PixelShader  = compile ps_2_0 PS_SMapCopy();
    }
    pass DrawObject {
        VertexShader = compile vs_2_0 VS_Object();
        PixelShader  = compile ps_2_0 PS_Object();
    }
}

technique MainTech1 < string MMDPass = "object"; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 VS_Object();
        PixelShader  = compile ps_2_0 PS_Object();
    }
}

technique MainTechSS0 < string MMDPass = "object_ss"; string Subset = "0";
    string Script = 
        "RenderColorTarget0=LocalShadow_SMapBuff;"
            "RenderDepthStencilTarget=DepthBuffer;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "Pass=SMapCopyPass;"
        "RenderColorTarget0=;"
            "RenderDepthStencilTarget=;"
            "Pass=DrawObject;"
    ;
> {
    pass SMapCopyPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_2_0 VS_SMapCopy();
        PixelShader  = compile ps_2_0 PS_SMapCopy();
    }
    pass DrawObject {
        VertexShader = compile vs_2_0 VS_Object();
        PixelShader  = compile ps_2_0 PS_Object();
    }
}

technique MainTechSS1 < string MMDPass = "object_ss"; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 VS_Object();
        PixelShader  = compile ps_2_0 PS_Object();
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////

// エッジ・地面影・Zプロットは描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }


