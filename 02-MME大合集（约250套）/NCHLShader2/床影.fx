////////////////////////////////////////////////////////////////////////////////////////////////
//　おまけ 床影.fx モデル周辺の地面にソフト影を表示
////////////////////////////////////////////////////////////////////////////////////////////////

// パラメータ宣言
#include "CommonParams.fxh"

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// SSAOのテクスチャ
shared texture2D SSAO_Tex3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 0;
    string Format = "D3DFMT_R16F";
>;
sampler2D SSAOSamp = sampler_state {
    texture = <SSAO_Tex3>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

//スクリーンシャドウマップ取得
shared texture2D ScreenShadowMapProcessed : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1,1};
    int MipLevels = 1;
    string Format = "D3DFMT_R16F";
>;
sampler2D ScreenShadowMapProcessedSamp = sampler_state {
    texture = <ScreenShadowMapProcessed>;
    MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
    AddressU  = CLAMP; AddressV = CLAMP;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画
// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {}

///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {}

////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

struct BufferShadow_INPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float2 Tex      : TEXCOORD;     // テクスチャ
    float3 Normal   : NORMAL;       // 法線
};

struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float4 ZCalcTex : TEXCOORD0;    // Z値
    float2 Tex      : TEXCOORD1;    // テクスチャ
    float3 Normal   : TEXCOORD2;    // 法線
    float3 Eye      : TEXCOORD3;    // カメラとの相対位置
    float4 WPos     : TEXCOORD4;    // ワールド位置
    float4 Pos2     : TEXCOORD5;    // SSAO用
    float4 ScreenTex : TEXCOORD6;   // セルフシャドウ用
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(BufferShadow_INPUT IN, uniform bool useTexture)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = Out.Pos2 = mul( IN.Pos, WorldViewProjMatrix );

    // ワールド位置
    Out.WPos= mul( IN.Pos, WorldMatrix ); 
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - Out.WPos;

    // 頂点法線
    Out.Normal = IN.Normal;

    // ライト視点によるワールドビュー射影変換
    Out.ZCalcTex = mul( IN.Pos, LightWorldViewProjMatrix );
         
    // テクスチャ座標
    Out.Tex = IN.Tex;

    //スクリーン座標取得
    Out.ScreenTex = Out.Pos;
    
    //超遠景におけるちらつき防止
    Out.Pos.z -= max(0, (int)((CameraDistance1 - 6000) * 0.04));

    return Out;
}

// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform const bool useTexture, uniform const bool useNormalMap) : COLOR
{
    // テクスチャ適用
    float4 TexColor = tex2D(ObjTexSampler, IN.Tex);

    // SSAO取得
    float2 uv = IN.Pos2.xy / IN.Pos2.w;
    uv = uv * float2( 0.5, -0.5 ) + float2( 0.5, 0.5 ) + ViewportOffset;
    float ao = tex2D( SSAOSamp, uv ).r;
    ao *= ao;
   
    // セルフシャドウ
    IN.ScreenTex.xyz /= IN.ScreenTex.w;
    float2 TransScreenTex;
    TransScreenTex.x = (1 + IN.ScreenTex.x) * 0.5f;
    TransScreenTex.y = (1 - IN.ScreenTex.y) * 0.5f;
    TransScreenTex += ViewportOffset;
    float ShadowMapVal = saturate(tex2D(ScreenShadowMapProcessedSamp, TransScreenTex).r);

    float LightPow = dot(normalize(IN.Normal),normalize(-LightDirection+IN.Eye));

    float4 Color = float4(0,0,0,0);
    Color.rgb = LightAmbient*ao*ShadowMapVal.rrr+LightPow*LightPow;
    Color.a = TexColor.r;
    return Color;
}

// オブジェクト描画用テクニック
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false;> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false,false);
    }
}

technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false;> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true,false);
    }
}

technique MainTecBS2  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true;> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true,true);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////