////////////////////////////////////////////////////////////////////////////////////////////////
//
// EmittionDraw for AutoLuminous.fx
//
////////////////////////////////////////////////////////////////////////////////////////////////

#define SpecularToneCurve  0.3333f  // 反射率に対する発光変化係数

// 発光部の床面鏡像描画のオフスクリーンバッファ
shared texture WF_EmitterRT : OFFSCREENRENDERTARGET;
sampler MirrorEmitterView = sampler_state {
    texture = <WF_EmitterRT>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5f, 0.5f)/ViewportSize);

// 座法変換行列
float4x4 WorldMatrix    : WORLD;
float4x4 ViewProjMatrix : VIEWPROJECTION;

float AcsAlpha : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float4 VPos : TEXCOORD1;
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // ワールド変換
    Pos = mul( Pos, WorldMatrix );
    Pos.y += 0.05f;

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.VPos = Out.Pos;

    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN) : COLOR0
{
    // 鏡像のスクリーンの座標(左右反転しているので元に戻す)
    float2 texCoord = float2( 1.0f - ( IN.VPos.x/IN.VPos.w + 1.0f ) * 0.5f,
                              1.0f - ( IN.VPos.y/IN.VPos.w + 1.0f ) * 0.5f ) + ViewportOffset;

    // 鏡像の色
    float4 Color = tex2D(MirrorEmitterView, texCoord);
    Color.rgb *= AcsAlpha;

    return Color;
}

float4 ShadowBuff_PS(VS_OUTPUT IN) : COLOR0
{
    // 鏡像のスクリーンの座標(左右反転しているので元に戻す)
    float2 texCoord = float2( 1.0f - ( IN.VPos.x/IN.VPos.w + 1.0f ) * 0.5f,
                              1.0f - ( IN.VPos.y/IN.VPos.w + 1.0f ) * 0.5f ) + ViewportOffset;

    // 鏡像の色
    float4 Color = tex2D(MirrorEmitterView, texCoord);
    Color.rgb *= pow(AcsAlpha, SpecularToneCurve) * step(0.01, AcsAlpha);
    return Color;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画用テクニック
technique MainTec < string MMDPass = "object"; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}

technique MainTecSS < string MMDPass = "object_ss"; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 ShadowBuff_PS();
    }
}


//影や輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

