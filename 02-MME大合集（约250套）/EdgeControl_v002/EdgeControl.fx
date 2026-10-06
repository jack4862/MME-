////////////////////////////////////////////////////////////////////////////////////////////////
//
//  EdgeControl.fx ver0.0.2  エッジをMMDの標準シェーダを用いずに独自仕様で描画します
//  作成: 針金P( 舞力介入P氏のfull.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
#define EDGE_ON   "0-"              // エッジを描画する材質番号
float EdgeThickness = 1.0;          // モデルのエッジの太さ
float3 EdgeColor = float3(0,0,0);   // エッジの色(RGBで指定)


// 解らない人はここから下はいじらないでね

// 座標変換行列
float4x4 WorldMatrix              : WORLD;
float4x4 ProjMatrix               : PROJECTION;
float4x4 ViewProjMatrix           : VIEWPROJECTION;

float3 CameraPosition             : POSITION  < string Object = "Camera"; >;

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 頂点シェーダ
float4 Edge_VS(float4 Pos : POSITION, float3 Normal : NORMAL) : POSITION
{
    // ワールド座標変換
    Pos = mul( Pos, WorldMatrix );
    Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

    // カメラとの距離
    float len = max( length( CameraPosition - Pos ), 5.0f );

    // 頂点を法線方向に押し出す
    Pos.xyz += Normal * ( len * EdgeThickness * 0.001f * pow(2.4142f / ProjMatrix._22, 0.7f) );

    // カメラ視点のビュー射影変換
    Pos = mul( Pos, ViewProjMatrix );

    return Pos;
}

// ピクセルシェーダ
float4 Edge_PS() : COLOR
{
    return float4(EdgeColor, 1);
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
   // MMD標準のエッジは描画しない
}

technique SelfEdgeTec1 < string MMDPass = "object"; string Subset = EDGE_ON; > {
    pass DrawObject {
       // モデル描画はMMD標準シェーダを用いる
    }
    pass DrawEdge {
        CullMode = CW;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_2_0 Edge_VS();
        PixelShader  = compile ps_2_0 Edge_PS();
    }
}

technique SelfEdgeTec3 < string MMDPass = "object_ss"; string Subset = EDGE_ON; > {
    pass DrawObject {
       // モデル描画はMMD標準シェーダを用いる
    }
    pass DrawEdge {
        CullMode = CW;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        VertexShader = compile vs_2_0 Edge_VS();
        PixelShader  = compile ps_2_0 Edge_PS();
    }
}

// エッジoffの材質はMMD標準シェーダでモデルのみ描画

///////////////////////////////////////////////////////////////////////////////////////////////
