////////////////////////////////////////////////////////////////////////////////////////////////
//
//  WF_MaskFloor.fx ver0.0.4  マスク画像作成，描画範囲(床)を白に
//  ( WorkingFloorX.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P( 舞力介入P氏のfull.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 WorldMatrix    : WORLD;
float4x4 ViewProjMatrix : VIEWPROJECTION;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////

float4 VS_Mask(float4 Pos : POSITION) : POSITION
{
    // ワールド座標変換
    Pos = mul( Pos, WorldMatrix );
    Pos.y += 0.01f;

    // カメラ視点のビュー射影変換
    Pos = mul( Pos, ViewProjMatrix );

    return Pos;
}

//ピクセルシェーダ
float4 PS_Mask() : COLOR
{
    return float4(1.0, 1.0, 1.0, 1.0);
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

//エッジや地面影は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

