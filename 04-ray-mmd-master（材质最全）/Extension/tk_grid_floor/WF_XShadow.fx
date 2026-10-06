////////////////////////////////////////////////////////////////////////////////////////////////
//
//  WF_XShadow.fx ver0.0.3  Xシャドー描画
//  ( WorkingFloorAL.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P( 舞力介入P氏のfull.fx改変,mqdl氏のxshadow.fx参考 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
float BoneMaxHeight = 6.0;    // Xシャドーが描画される足首ボーンの最大高さ(モデルサイズで変動有り)
float XShadowSize = 1.3;      // Xシャドーのサイズ
float XShadowAlpha = 0.6;     // Xシャドーの透過度
float XShadowZOffset = -0.3;  // Xシャドーの前後方向位置補正値

#define ConstSize    1   // モデルの大きさによるXシャドーサイズの自動調整を 0:行わない, 1:行う
#define ConstDensity 1   // ライト照度によるXシャドー濃度の自動調整を 0:行わない, 1:行う


// 解らない人はここから下はいじらないでね

///////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 ViewProjMatrix : VIEWPROJECTION;
float4x4 MirrorWorldMatrix: CONTROLOBJECT < string Name = "(OffscreenOwner)"; >; // 鏡面アクセのワールド変換行列

// 足ボーンパラメータ
float4x4 AnkleWldMatR : CONTROLOBJECT < string name = "(self)"; string item = "右足首"; >;
float4x4 AnkleWldMatL : CONTROLOBJECT < string name = "(self)"; string item = "左足首"; >;
static float3 FootPosR = AnkleWldMatR._41_42_43;
static float3 FootPosL = AnkleWldMatL._41_42_43;
static float rotR = atan2(AnkleWldMatR._13, AnkleWldMatR._33);
static float rotL = atan2(AnkleWldMatL._13, AnkleWldMatL._33);

#if(ConstSize == 1)
// 足の長さをモデルの大きさとする
float3 KneeWldPosR : CONTROLOBJECT < string name = "(self)"; string item = "右ひざ"; >;
float3 KneeWldPosL : CONTROLOBJECT < string name = "(self)"; string item = "左ひざ"; >;
float3 LegWldPosR : CONTROLOBJECT < string name = "(self)"; string item = "右足"; >;
float3 LegWldPosL : CONTROLOBJECT < string name = "(self)"; string item = "左足"; >;
static float FootLenR = (length(FootPosR - KneeWldPosR) + length(KneeWldPosR - LegWldPosR)) / 9.42f + 0.001f;
static float FootLenL = (length(FootPosL - KneeWldPosL) + length(KneeWldPosL - LegWldPosL)) / 9.42f + 0.001f;
#else
float FootLenR = 1.0f;
float FootLenL = 1.0f;
#endif

// 人型でないモデルのX影を非表示にするフラグ
static float PmdType = step( 0.0f, abs(FootPosR.x)+abs(FootPosR.y)+abs(FootPosL.x)+abs(FootPosL.y) );

// X影の濃度
#if(ConstDensity == 1)
float3 LightAmbient : AMBIENT  < string Object = "Light"; >;
static float BrightNess = 0.5f + max( (3.0f-LightAmbient.r-LightAmbient.g-LightAmbient.b)*0.83f, 0.0f );
#else
float BrightNess = 1.5f;
#endif

// X影のテクスチャ
texture2D XShadowTex1 <
    string ResourceName = "XS1.png";
>;
sampler XShadowSamp1 = sampler_state {
    texture = <XShadowTex1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D XShadowTex2 <
    string ResourceName = "XS2.png";
>;
sampler XShadowSamp2 = sampler_state {
    texture = <XShadowTex2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////
// 座標の2D回転
float3 Rotation2D(float3 pos, float rot)
{
    float sinR, cosR;
    sincos(rot, sinR, cosR);
    float x = pos.x * cosR - pos.z * sinR;
    float z = pos.x * sinR + pos.z * cosR;

    return float3(x, pos.y, z);
}

///////////////////////////////////////////////////////////////////////////////////////////////
// X影描画

struct VS_OUTPUT {
    float4 Pos   : POSITION;    // 射影変換座標
    float2 Tex   : TEXCOORD0;   // テクスチャ
    float4 Color : COLOR0;      // α値
};

// 頂点シェーダ
VS_OUTPUT XShadow_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD,
                     uniform bool RorL, uniform float coefScale,  uniform float coefAlpha)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    float  FootLen, rot;
    float3 FootPos;
    if( RorL ){
        // 右足パラメータ
        FootLen = FootLenR;
        FootPos = FootPosR;
        rot = rotR;
    }else{
        // 左足パラメータ
        FootLen = FootLenL;
        FootPos = FootPosL;
        rot = rotL;
    }

    // "Draw=Buffer;"で得た矩形板ポリを通常のオブジェクトとして扱う
    Pos.z = Pos.y;
    Pos.y = 0.0f;
    Pos.w = 1.0f;

    // X影の大きさ
    Pos.xyz *= coefScale * XShadowSize * FootLen * PmdType;

    // X影のワールド座標
    float3 offset = Rotation2D( float3(0.0f, 0.0f, XShadowZOffset * FootLen), rot );
    Pos.xyz += float3(FootPos.x, 0.0f, FootPos.z) + offset;

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );

    // X影の透過度
    float alpha = ( 1.0f - saturate((FootPos.y - coefAlpha) / (BoneMaxHeight - coefAlpha) / FootLen) ) * XShadowAlpha;
    Out.Color = float4(alpha, alpha, alpha, 1.0f);

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}


// ピクセルシェーダ
float4 XShadow_PS(VS_OUTPUT IN, uniform sampler XShadowSamp) : COLOR0
{
   // 人型モデル以外は描画しない
   clip( PmdType - 0.0001f );

    // X影の色
   float4 Color = tex2D( XShadowSamp, IN.Tex );
   float3 Color1 = float3(1.0f, 1.0f ,1.0f);
   Color.xyz = Color1 - ( Color1 - Color.xyz ) * IN.Color.xyz;
   Color.xyz = saturate( 1.0f - (1.0f - Color.xyz ) * BrightNess );

   return Color;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec < string MMDPass = "object"; string Subset = "0"; >
{
    pass DrawXShadowR1 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadow_VS( false, 7.0f, 1.0f );
        PixelShader  = compile ps_2_0 XShadow_PS( XShadowSamp1 );
    }
    pass DrawXShadowR2 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadow_VS( false, 0.9f, 1.5f );
        PixelShader  = compile ps_2_0 XShadow_PS( XShadowSamp2 );
    }
    pass DrawXShadowL1 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadow_VS( true, 7.0f, 1.0f );
        PixelShader  = compile ps_2_0 XShadow_PS( XShadowSamp1 );
    }
    pass DrawXShadowL2 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadow_VS( true, 0.9f, 1.5f );
        PixelShader  = compile ps_2_0 XShadow_PS( XShadowSamp2 );
    }
}

technique MainTecSS < string MMDPass = "object_ss"; string Subset = "0"; >
{
    pass DrawXShadowR1 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadow_VS( false, 7.0f, 1.0f );
        PixelShader  = compile ps_2_0 XShadow_PS( XShadowSamp1 );
    }
    pass DrawXShadowR2 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadow_VS( false, 0.9f, 1.5f );
        PixelShader  = compile ps_2_0 XShadow_PS( XShadowSamp2 );
    }
    pass DrawXShadowL1 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadow_VS( true, 7.0f, 1.0f );
        PixelShader  = compile ps_2_0 XShadow_PS( XShadowSamp1 );
    }
    pass DrawXShadowL2 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadow_VS( true, 0.9f, 1.5f );
        PixelShader  = compile ps_2_0 XShadow_PS( XShadowSamp2 );
    }
}

technique MainTec2 < string MMDPass = "object"; > { }
technique MainTec3 < string MMDPass = "object_ss"; > { }

//エッジや地面影は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

