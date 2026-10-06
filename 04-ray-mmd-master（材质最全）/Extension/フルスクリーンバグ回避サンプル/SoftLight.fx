// ソフトライトエフェクト(オリジナル：そぼろさんのDiffusion7)
// HgSAOと併用時のフルスクリーンバグ対策済み
////////////////////////////////////////////////////////////////////////////////////////////////

// ユーザーパラメータ

// ぼかし範囲(大きくしすぎると縞が出ます)
#define EXTENT 0.0001

// フィルタ強度
#define STRENGTH 1.0

// 背景色
uniform float4 ClearColor = float4(1,1,1,0);

// ぼかしのサンプリング数
#define SAMP_NUM  7

// レンダーターゲットのフォーマット
#define FMT "A8R8G8B8"

///////////////////////////////////////////////////////////////////////////////////
//これ以降はエフェクトの知識のある人以外は触れないこと

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;

// マテリアル色
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;

float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1;
float3 objpos : CONTROLOBJECT < string name = "(self)"; >;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 SampStep = (float2(EXTENT,EXTENT)/ViewportSize*ViewportSize.y) * objpos.x;

// レンダリングターゲットのクリア値
uniform float ClearDepth  = 1.0;

// 深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = FMT ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = FMT ;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 共通頂点シェーダ
struct VS_OUTPUT {
    float4 Pos            : POSITION;
    float2 Tex            : TEXCOORD0;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color, sum = 0;
    float e, n = 0;
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
        float2 stex = Tex + float2(SampStep.x * (float)i, 0);
        e = exp(-pow((float)i / (SAMP_NUM / 2.0), 2) / 2); //正規分布
        
        float4 org_color = tex2D( ScnSamp, stex );
        //org_color.rgb = pow(org_color.rgb, 2); //RGBを2乗
        sum += org_color * e;
        n += e;
    }
    
    Color = sum / n;
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし + 合成

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color, sum = 0;
    float4 ColorS, ColorScr, ColorOrg;
    
    float e, n = 0;
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
        float2 stex = Tex + float2(0, SampStep.y * (float)i);
        e = exp(-pow((float)i / (SAMP_NUM / 2.0), 2) / 2); //正規分布
        sum += tex2D( ScnSamp2, stex ) * e;
        n += e;
    }
    
    Color = sum / n;

    // オリジナル
    ColorOrg = tex2D( ScnSamp, Tex );

    // スクリーン合成
    ColorScr.rgb = 2*Color-Color*Color;

    ColorS.a = ColorScr.a = ColorOrg.a;
    
    // ソフトライト(オーバーレイ)合成　暗い部分はより明るくする
    float M = (ColorOrg.r+ColorOrg.g+ColorOrg.b)/3;
    ColorS = lerp( ColorOrg*(ColorOrg+(2*pow(ColorScr,1/scaling))*(1-ColorOrg)),
                   ColorOrg*(ColorOrg+(2*ColorScr*ColorScr)*(1-ColorOrg)), M*M );

    return lerp(ColorOrg,ColorS,STRENGTH*alpha1);
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique Diffusion <
    string Script = 
        
        "RenderColorTarget0=ScnMap;"
        "RenderColorTarget1=;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "ScriptExternal=Color;"
        
        "RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=Gaussian_X;"
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=Gaussian_Y;"
    ;
    
> {
    
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_passY();
    }
    pass DammyPass < string Script= "Draw=Geometry;"; > {}
}
////////////////////////////////////////////////////////////////////////////////////////////////