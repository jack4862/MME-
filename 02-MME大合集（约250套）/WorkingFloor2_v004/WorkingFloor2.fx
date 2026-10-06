////////////////////////////////////////////////////////////////////////////////////////////////
//
//  WorkingFloor2.fx ver0.0.4  オフスクリーンレンダを使った床面鏡像描画，床に仕事をさせます
//  作成: 針金P( 舞力介入P氏のMirror.fx, full.fx,改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////

// 床面鏡像描画のオフスクリーンバッファ
texture WorkingFloorRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for WorkingFloor.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"

//********** ここに鏡像描画させるオブジェクトを指定してください **********

        "*.pmd = WF_Object.fx;"
        "*.pmx = WF_Object.fx;"
        "*.vac = WF_Object.fx;"
        "negi.x = WF_Object.fx;"

//************************************************************************

        "* = hide;" 
    ;
>;

// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
sampler WorkingFloorView = sampler_state {
    texture = <WorkingFloorRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// 鏡像描画のマスクに使うオフスクリーンバッファ
texture MaskWorkingFloorRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Mask of WorkingFloor.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = WF_MaskFloor.fx;"
        "* = WF_MaskObject.fx;" 
    ;
>;
sampler MaskWorkingFloor = sampler_state {
    texture = <MaskWorkingFloorRT>;
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
//床面鏡像描画シェーダ
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
    float4 MaskColor = tex2D(MaskWorkingFloor, Tex);

    float4 Color = tex2D(WorkingFloorView, float2(1.0f-Tex.x, Tex.y)); // 左右反転しているので元に戻す
    Color.a *= AcsAlpha * MaskColor.r;

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



