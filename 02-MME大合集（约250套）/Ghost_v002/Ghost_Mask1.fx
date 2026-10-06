////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Ghost_Mask1.fx ver0.0.2  マスク画像作成，適用モデルをを白に
//  ( Ghost.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P( 舞力介入P氏のfull.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 WorldMatrix              : WORLD;
float4x4 ViewProjMatrix           : VIEWPROJECTION;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
    float4 Pos  : POSITION;    // 射影変換座標
    float4 VPos : TEXCOORD1;   // ワールド変換座標
};

// 頂点シェーダ
VS_OUTPUT VS_Mask(float4 Pos : POSITION)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // ワールド座標変換
    Pos = mul( Pos, WorldMatrix );
    Out.VPos = Pos;

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );

    return Out;
}

//ピクセルシェーダ
float4 PS_Mask(VS_OUTPUT IN) : COLOR
{
    float h = max( IN.VPos.y/IN.VPos.w, 0.0f );
    float h10 = saturate( int(h/10.0f) * 0.1f );
    float h1 = saturate( fmod(h,10.0f) * 0.1f );
    return float4(1.0, h10, h1, 1.0);
}

technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawMask {
        VertexShader = compile vs_2_0 VS_Mask();
        PixelShader  = compile ps_2_0 PS_Mask();
    }
}

//セルフシャドウなし
technique Mask < string MMDPass = "object"; > {
    pass DrawMask {
        VertexShader = compile vs_2_0 VS_Mask();
        PixelShader  = compile ps_2_0 PS_Mask();
    }
}

//セルフシャドウあり
technique MaskSS < string MMDPass = "object_ss"; > {
    pass DrawMask {
        VertexShader = compile vs_2_0 VS_Mask();
        PixelShader  = compile ps_2_0 PS_Mask();
    }
}

//描画しない
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

