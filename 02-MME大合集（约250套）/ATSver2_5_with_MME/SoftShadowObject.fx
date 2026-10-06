////////////////////////////////////////////////////////////////////////////////////////////////
//
//  SoftShadowObject.fx ver0.0.1  オフスクリーンへの非セルフシャドウ影描画(ATステージ専用)
//  ( SoftShadow.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P( 舞力介入P氏のMirrorObject.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////

// ワールド変換行列限定で、逆行列を計算する。
// - 行列が、等倍スケーリング、回転、平行移動しか含まないことを前提条件とする。
float4x4 InverseWorldMatrix(float4x4 mat) {
    float scaling = length(mat._11_12_13);
    float scaling_inv = 1.0 / scaling;

    float3x3 mat3x3_inv = transpose((float3x3)mat) * scaling_inv;
    return float4x4( mat3x3_inv[0], 0, 
                     mat3x3_inv[1], 0, 
                     mat3x3_inv[2], 0, 
                     -mul(mat._41_42_43,mat3x3_inv), 1 );
}

// 座標変換パラメータ
float4x4 WorldMatrix  : WORLD;
float4x4 MirrorWorldMatrix: CONTROLOBJECT < string name = "ATS半透明ver2[SoftShadow.fx].pmd"; string item = "センター"; >; // 地面のワールド変換行列
static float4x4 InvMirrorWorldMatrix = InverseWorldMatrix(MirrorWorldMatrix);    // 地面のワールド変換逆行列
static float3 PlanarPos = MirrorWorldMatrix._41_42_43;                           // 投影する平面上の任意の座標
static float3 PlanarNormal = mul( float3(0.0, 1.0, 0.0), (float3x3)MirrorWorldMatrix);  // 投影する平面の法線ベクトル
static float scaling = length(MirrorWorldMatrix._11_12_13);

// ライト方向
float3 LightDirection : DIRECTION < string Object = "Light"; >;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
    // ワールド座標変換
    Pos = mul( Pos, WorldMatrix );

    // 光源の仮位置(平行光源なので)
    float3 LightPos = (float3)Pos + LightDirection;

    // 任意平面に投影
    float a = dot(PlanarNormal, PlanarPos - LightPos);
    float b = dot(PlanarNormal, (float3)Pos - PlanarPos);
    float c = dot(PlanarNormal, (float3)Pos - LightPos);
    Pos = float4((float3)Pos * a + LightPos * b, c);

    // 地面位置へ戻す(ビュー座標変換もどき)
    Pos = mul( Pos, InvMirrorWorldMatrix );

    // 射影座標変換もどき
    Pos.y = Pos.z;
    Pos.z = 0.0f;
    Pos.w *= 31.43f*scaling; // 地面範囲が-31.43～31.43なので

    return Pos;
}

// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
    return float4(1.0f, 1.0f, 1.0f, 1.0f);
}

// 影描画用テクニック(エッジ･通常オブジェクトで描画)
technique ShadowTec < string MMDPass = "edge"; > {
    pass DrawShadow {
        VertexShader = compile vs_2_0 Shadow_VS();
        PixelShader  = compile ps_2_0 Shadow_PS();
    }
}

technique ShadowTec < string MMDPass = "object"; > {
    pass DrawShadow {
        VertexShader = compile vs_2_0 Shadow_VS();
        PixelShader  = compile ps_2_0 Shadow_PS();
    }
}

technique ShadowTec < string MMDPass = "object_ss"; > {
    pass DrawShadow {
        VertexShader = compile vs_2_0 Shadow_VS();
        PixelShader  = compile ps_2_0 Shadow_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////

// MMD標準影は非表示にする
technique MainTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

