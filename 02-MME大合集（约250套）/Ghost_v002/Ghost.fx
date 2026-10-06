////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Ghost.fx ver0.0.2  オフスクリーンレンダとマスク画像を用いた幽霊表現
//  作成: 針金P( 舞力介入P氏のMirror.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
float HeightMin = 0.0;  // フェード開始基準高さ
float HeightMax = 20.0; // フェード終了基準高さ
float Threshold = 0.5;  // フェードの閾値(値が小さいとフェードの変化がシャープで大きいとマイルドになります)

// モデルのオフスクリーンレンダ
texture GhostRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Ghost.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
//********** ここに適用させるオブジェクトを指定してください **********

        "初音ミク.pmd = none;"
        "negi.x = none;"

//********************************************************************
        "* = hide;";
>;
// モデルのマスクに使うオフスクリーンバッファ
texture MaskGhostRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Mask of Ghost.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
//**** ここに適用させるオブジェクトを指定してください(必ず上と同じモデルを選択) ****

        "初音ミク.pmd = Ghost_Mask1.fx;"
        "negi.x = Ghost_Mask1.fx;"

//**********************************************************************************
        "* = Ghost_Mask2.fx;" 
    ;
>;


// 解らない人はここから下はいじらないでね

///////////////////////////////////////////////////////////////////////////////////////////////
sampler GhostView = sampler_state {
    texture = <GhostRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

sampler MaskGhost = sampler_state {
    texture = <MaskGhostRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

// アクセサリパラメータ
float4x4 WorldMatrix : WORLD;
static float AcsScaling = length(WorldMatrix._11_12_13)*0.1f; 
static float AcsX = WorldMatrix._41 + HeightMin; 
static float AcsY = WorldMatrix._42 + HeightMax; 
// マテリアル色
float4 MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
static float AcsAlpha = MaterialDiffuse.a;

////////////////////////////////////////////////////////////////////////////////////////////////
//描画シェーダ
struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

VS_OUTPUT VS_Ghost(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, ViewportOffset.y);

    return Out;
}

float4 PS_Ghost(float2 Tex: TEXCOORD0) : COLOR
{
    // オフスクリーンバッファの色
    float4 Color = tex2D(GhostView, Tex);
    float4 Color2 = tex2D(MaskGhost, Tex);
    Color.a *= Color2.r;

    // フェード透過値計算
    float h = Color2.g * 100.0f + Color2.b * 10.0f;
    float v = 1.0f-saturate( ( h - AcsX ) / ( AcsY - AcsX ) );
    float a = (1.0+Threshold)*AcsScaling - 0.5f*Threshold;
    float minLen = a - 0.5f*Threshold;
    float maxLen = a + 0.5f*Threshold;
    Color.a *= AcsAlpha*saturate( (maxLen - v)/(maxLen - minLen) );

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

technique MainTec{
    pass DrawObject < string Script= "Draw=Buffer;"; > {
        VertexShader = compile vs_2_0 VS_Ghost();
        PixelShader  = compile ps_2_0 PS_Ghost();
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////



