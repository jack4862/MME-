////////////////////////////////////////////////////////////////////////////////////////////////
//
//  WF_XShadow.fx ver0.0.1  Xシャドー描画
//  ( WorkingFloorX.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P( 舞力介入P氏のfull.fx改変,mqdl氏のxshadow.fx参考 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
float BoneMaxHeight = 6.0;    // Xシャドーが描画される足首ボーンの最大高さ(モデルサイズで変動有り)
float XShadowSize = 1.2;      // Xシャドーのサイズ
float XShadowAlpha = 0.6;     // Xシャドーの透過度
float XShadowZOffset = -0.3;  // Xシャドーの前後方向位置補正値

#define ConstSize    0   // モデルの大きさによるXシャドーサイズの自動調整を行わない場合はここを1にする
#define ConstDensity 0   // ライトの照度によるXシャドー濃度の自動調整を行わない場合はここを1にする


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////

// 足ボーンパラメータ
float4x4 AnkleWldMatR : CONTROLOBJECT < string name = "(self)"; string item = "右足首"; >;
float4x4 AnkleWldMatL : CONTROLOBJECT < string name = "(self)"; string item = "左足首"; >;
static float3 FootPosR = AnkleWldMatR._41_42_43;
static float3 FootPosL = AnkleWldMatL._41_42_43;
static float rotR = atan2(AnkleWldMatR._13, AnkleWldMatR._33);
static float rotL = atan2(AnkleWldMatL._13, AnkleWldMatL._33);

#if(ConstSize == 0)
float3 KneeWldMatR : CONTROLOBJECT < string name = "(self)"; string item = "右ひざ"; >;
float3 KneeWldMatL : CONTROLOBJECT < string name = "(self)"; string item = "左ひざ"; >;
float3 LegWldMatR : CONTROLOBJECT < string name = "(self)"; string item = "右足"; >;
float3 LegWldMatL : CONTROLOBJECT < string name = "(self)"; string item = "左足"; >;
static float FootLenR = (length(FootPosR - KneeWldMatR) + length(KneeWldMatR - LegWldMatR)) / 9.42f;
static float FootLenL = (length(FootPosL - KneeWldMatL) + length(KneeWldMatL - LegWldMatL)) / 9.42f;
#else
float FootLenR = 1.0f;
float FootLenL = 1.0f;
#endif

// 人型でないモデルのX影を非表示にするフラグ
static float PmdType = (abs(FootPosR.x)+abs(FootPosR.y)+abs(FootPosL.x)+abs(FootPosL.y) > 0.0f) ? 1.0f : 0.0f;

// 座標変換行列
float4x4 ViewProjMatrix : VIEWPROJECTION;

#if(ConstDensity == 0)
float3 LightAmbient : AMBIENT  < string Object = "Light"; >;
static float BrightNess = 0.5f + max( (LightAmbient.r+LightAmbient.g+LightAmbient.b)*0.55f, 0.0f );
#else
float BrightNess = 1.5f;
#endif

texture2D XShadowTex1 <
    string ResourceName = "XShadow1.png";
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
    string ResourceName = "XShadow2.png";
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
    float x = pos.x * cos(rot) - pos.z * sin(rot);
    float z = pos.x * sin(rot) + pos.z * cos(rot);

    return float3(x, pos.y, z);
}

///////////////////////////////////////////////////////////////////////////////////////////////
// X影描画

struct VS_OUTPUTX {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
    float4 Color      : COLOR0;      // α値
};

// 右足X影描画
VS_OUTPUTX XShadowR1_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD)
{
    VS_OUTPUTX Out = (VS_OUTPUTX)0;

    Pos.z = Pos.y;
    Pos.y = 0.0f;
    Pos.w = 1.0f;
    Pos.xyz *= 7.0f*XShadowSize*FootLenR*PmdType;

    float3 offset = Rotation2D( float3(0.0f, 0.0f, XShadowZOffset*FootLenR), rotR );

    Pos.x += FootPosR.x + offset.x;
    Pos.z += FootPosR.z + offset.z;

    Out.Pos = mul( Pos, ViewProjMatrix );

    float alpha = ( 1.0f - saturate((FootPosR.y-1.0f)/(BoneMaxHeight-1.0f)/FootLenR) ) * XShadowAlpha;
    Out.Color = float4(alpha, alpha, alpha, 1.0f);

    Out.Tex = Tex;

    return Out;
}

// 右足X影中心描画
VS_OUTPUTX XShadowR2_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD)
{
    VS_OUTPUTX Out = (VS_OUTPUTX)0;

    Pos.z = Pos.y;
    Pos.y = 0.0f;
    Pos.w = 1.0f;
    Pos.xyz *= 0.9f*XShadowSize*FootLenR*PmdType;

    float3 offset = Rotation2D( float3(0.0f, 0.0f, XShadowZOffset*FootLenR), rotR );

    Pos.x += FootPosR.x + offset.x;
    Pos.z += FootPosR.z + offset.z;

    Out.Pos = mul( Pos, ViewProjMatrix );

    float alpha = ( 1.0f - saturate((FootPosR.y-1.5f)/(BoneMaxHeight-1.5f)/FootLenR) ) * XShadowAlpha;
    Out.Color = float4(alpha, alpha, alpha, 1.0f);

    Out.Tex = Tex;

    return Out;
}

// 左足X影描画
VS_OUTPUTX XShadowL1_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD)
{
    VS_OUTPUTX Out = (VS_OUTPUTX)0;

    Pos.z = Pos.y;
    Pos.y = 0.0f;
    Pos.w = 1.0f;
    Pos.xyz *= 7.0f*XShadowSize*FootLenL*PmdType;

    float3 offset = Rotation2D( float3(0.0f, 0.0f, XShadowZOffset*FootLenL), rotL );

    Pos.x += FootPosL.x + offset.x;
    Pos.z += FootPosL.z + offset.z;

    Out.Pos = mul( Pos, ViewProjMatrix );

    float alpha = ( 1.0f - saturate((FootPosL.y-1.0f)/(BoneMaxHeight-1.0f)/FootLenL) ) * XShadowAlpha;
    Out.Color = float4(alpha, alpha, alpha, 1.0f);

    Out.Tex = Tex;

    return Out;
}

// 左足X影中心描画
VS_OUTPUTX XShadowL2_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD)
{
    VS_OUTPUTX Out = (VS_OUTPUTX)0;

    Pos.z = Pos.y;
    Pos.y = 0.0f;
    Pos.w = 1.0f;
    Pos.xyz *= 0.9f*XShadowSize*FootLenL*PmdType;

    float3 offset = Rotation2D( float3(0.0f, 0.0f, XShadowZOffset*FootLenL), rotL );

    Pos.x += FootPosL.x + offset.x;
    Pos.z += FootPosL.z + offset.z;

    Out.Pos = mul( Pos, ViewProjMatrix );

    float alpha = ( 1.0f - saturate((FootPosL.y-1.5f)/(BoneMaxHeight-1.5f)/FootLenL) ) * XShadowAlpha;
    Out.Color = float4(alpha, alpha, alpha, 1.0f);

    Out.Tex = Tex;

    return Out;
}


// ピクセルシェーダ
float4 XShadow1_PS(VS_OUTPUTX IN) : COLOR0
{
   float4 Color = tex2D( XShadowSamp1, IN.Tex );
   float3 Color1 = float3(1.0f, 1.0f ,1.0f);
   Color.xyz = Color1 - ( Color1 - Color.xyz ) * IN.Color.xyz;
   Color.xyz = saturate( 1.0f - (1.0f - Color.xyz ) * BrightNess );
   return Color;
}

float4 XShadow2_PS(VS_OUTPUTX IN) : COLOR0
{
   float4 Color = tex2D( XShadowSamp2, IN.Tex );
   float3 Color1 = float3(1.0f, 1.0f ,1.0f);
   Color.xyz = Color1 - ( Color1 - Color.xyz ) * IN.Color.xyz;
   Color.xyz = saturate( 1.0f - (1.0f - Color.xyz ) * BrightNess );
   return Color;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique MainTec0 < string MMDPass = "object"; string Subset = "0"; >
{
    pass DrawXShadowR1 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadowR1_VS();
        PixelShader  = compile ps_2_0 XShadow1_PS();
    }
    pass DrawXShadowR2 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadowR2_VS();
        PixelShader  = compile ps_2_0 XShadow2_PS();
    }
    pass DrawXShadowL1 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadowL1_VS();
        PixelShader  = compile ps_2_0 XShadow1_PS();
    }
    pass DrawXShadowL2 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadowL2_VS();
        PixelShader  = compile ps_2_0 XShadow2_PS();
    }
}

technique MainTec1 < string MMDPass = "object_ss"; string Subset = "0"; >
{
    pass DrawXShadowR1 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadowR1_VS();
        PixelShader  = compile ps_2_0 XShadow1_PS();
    }
    pass DrawXShadowR2 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadowR2_VS();
        PixelShader  = compile ps_2_0 XShadow2_PS();
    }
    pass DrawXShadowL1 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadowL1_VS();
        PixelShader  = compile ps_2_0 XShadow1_PS();
    }
    pass DrawXShadowL2 < string Script= "Draw=Buffer;"; > {
        ZENABLE = FALSE;
        AlphaBlendEnable = TRUE;
        SrcBlend = DESTCOLOR;
        DestBlend = ZERO;
        VertexShader = compile vs_2_0 XShadowL2_VS();
        PixelShader  = compile ps_2_0 XShadow2_PS();
    }
}

technique MainTec2 < string MMDPass = "object"; > { }
technique MainTec3 < string MMDPass = "object_ss"; > { }

//エッジや地面影は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

