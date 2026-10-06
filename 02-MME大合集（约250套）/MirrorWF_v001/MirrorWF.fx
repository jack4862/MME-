////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MirrorWF.fx ver0.0.1  任意平面への鏡像描画
//  作成: 針金P( 舞力介入P氏のMirror.fx, full.fx,改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// アクセに組み込む場合はここを適宜変更してください．
float3 MirrorColor = float3(1.0, 1.0, 1.0); // 鏡面の乗算色(RGB)
float3 MirrorAlpha = 1.0; // 鏡面の初期透過値

///////////////////////////////////////////////////////////////////////////////////////////////

// 鏡像描画のオフスクリーンバッファ
texture MirrorWFRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for MirrorWF.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "* = MWF_Object.fx;";
>;
sampler MirrorWFView = sampler_state {
    texture = <MirrorWFRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// 鏡像描画のマスクに使うオフスクリーンバッファ
texture MaskMirrorWFRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Mask of MirrorWF.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = MWF_MaskMirror.fx;"
        "* = MWF_MaskObject.fx;" 
    ;
>;
sampler MaskMirrorWF = sampler_state {
    texture = <MaskMirrorWFRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

////////////////////////////////////////////////////////////////////////////////////////////////

// マテリアル色
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float AcsAlpha = MaterialDiffuse.a;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

////////////////////////////////////////////////////////////////////////////////////////////////
// 鏡像描画シェーダ
struct VS_OUTPUT {
    float4 Pos : POSITION;
    float2 Tex : TEXCOORD0;
};

VS_OUTPUT VS_Mirror(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

float4 PS_Mirror(float2 Tex: TEXCOORD0) : COLOR
{
    float4 MaskColor = tex2D(MaskMirrorWF, Tex);

    float4 Color = tex2D(MirrorWFView, float2(1.0f-Tex.x, Tex.y)); // 左右反転しているので元に戻す
    Color.xyz *= MirrorColor;
    Color.a *= AcsAlpha * MirrorAlpha * MaskColor.r;

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

technique MainTec{
    pass DrawObject < string Script= "Draw=Buffer;"; > {
        VertexShader = compile vs_2_0 VS_Mirror();
        PixelShader  = compile ps_2_0 PS_Mirror();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////



