////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言


float4 Color_White = {1,1,1,1};
float4 Color_Black = {0,0,0,1};

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrixInverse        : WORLDVIEWINVERSE;

static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};

///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
};


// 頂点シェーダ
VS_OUTPUT VS_Inv(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;
    
    // ビルボード
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    // テクスチャ座標
    Out.Tex = Tex;
    
    return Out;
}

// ピクセルシェーダ
float4 PS_Inv( float2 Tex :TEXCOORD0 ) : COLOR0
{
    return Color_White;
}


technique Invert {
    
    pass Single_Pass {
    	ZENABLE = false;
    	SRCBLEND = INVDESTCOLOR;
        DESTBLEND = ZERO;
    	VertexShader = compile vs_2_0 VS_Inv();
        PixelShader  = compile ps_2_0 PS_Inv();
    }
    
}

