////////////////////////////////////////////////////////////////////////////////////////////////
//
//  SoftShadow.fx ATSver 地面影をぼかしてから投影できるようにします，ATステージ専用にカスタマイズ
//  作成: 針金P( 舞力介入P氏のMirror.fx, Gaussian.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

#define TEXSIZE   512  // 地面テクスチャのサイズ

// 地面影描画用オフスクリーンバッファ
texture SoftShadowRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for SoftShadow.fx";
    int Width = TEXSIZE;
    int Height = TEXSIZE;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "ATS半透明ver2[SoftShadow.fx].pmd = hide;"

//********** ここに適用させるオブジェクトを追加してください **********

        "*.pmd = SoftShadowObject.fx;"
        "negi.x = SoftShadowObject.fx;"

//********************************************************************

        "* = hide;";
>;


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
sampler SoftShadowView = sampler_state {
    texture = <SoftShadowRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// ぼかし処理の重み係数：
//    ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//    (WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379

// パラメータ宣言

// 地面影のマテリアル色
float3 ShadowAmbient = float3(0.5,0.5,0.5);
float3 ShadowEmmisive = float3(0.4,0.4,0.4);

// コントロールパラメータ
float GaussianVal : CONTROLOBJECT < string name = "ATS半透明ver2[SoftShadow.fx].pmd"; string item = "影ぼかし"; >;
float Thick : CONTROLOBJECT < string name = "ATS半透明ver2[SoftShadow.fx].pmd"; string item = "影濃度"; >;
float Alpha : CONTROLOBJECT < string name = "ATS半透明ver2[SoftShadow.fx].pmd"; string item = "影透過"; >;

// 座標変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;
static float3 MaterialColor = saturate((ShadowAmbient * LightAmbient + ShadowEmmisive)*Thick);

bool	 spadd;    // スフィアマップ加算合成フラグ

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

///////////////////////////////////////////////////////////////////////////////////////////////
// スクリーンサイズ
float2 ViewportSize = float2(TEXSIZE, TEXSIZE);
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 SampStep = (float2(2.0,2.0)/ViewportSize*GaussianVal);

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapX : RENDERCOLORTARGET <
    int Width = TEXSIZE;
    int Height = TEXSIZE;
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSampX = sampler_state {
    texture = <ScnMapX>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// Y方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapY : RENDERCOLORTARGET <
    int Width = TEXSIZE;
    int Height = TEXSIZE;
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSampY = sampler_state {
    texture = <ScnMapY>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    int Width = TEXSIZE;
    int Height = TEXSIZE;
    string Format = "D24S8";
>;

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

struct VS_OUTPUT {
    float4 Pos	: POSITION;
    float2 Tex	: TEXCOORD0;
};

VS_OUTPUT VS_passX( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + float2(0, ViewportOffset.y);

    return Out;
}

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR
{
    float4 Color;
    Color  = tex2D( SoftShadowView, Tex );

    Color  = WT_0 *   tex2D( SoftShadowView, Tex );
    Color += WT_1 * ( tex2D( SoftShadowView, Tex+float2(SampStep.x  ,0) ) + tex2D( SoftShadowView, Tex-float2(SampStep.x  ,0) ) );
    Color += WT_2 * ( tex2D( SoftShadowView, Tex+float2(SampStep.x*2,0) ) + tex2D( SoftShadowView, Tex-float2(SampStep.x*2,0) ) );
    Color += WT_3 * ( tex2D( SoftShadowView, Tex+float2(SampStep.x*3,0) ) + tex2D( SoftShadowView, Tex-float2(SampStep.x*3,0) ) );
    Color += WT_4 * ( tex2D( SoftShadowView, Tex+float2(SampStep.x*4,0) ) + tex2D( SoftShadowView, Tex-float2(SampStep.x*4,0) ) );
    Color += WT_5 * ( tex2D( SoftShadowView, Tex+float2(SampStep.x*5,0) ) + tex2D( SoftShadowView, Tex-float2(SampStep.x*5,0) ) );
    Color += WT_6 * ( tex2D( SoftShadowView, Tex+float2(SampStep.x*6,0) ) + tex2D( SoftShadowView, Tex-float2(SampStep.x*6,0) ) );
    Color += WT_7 * ( tex2D( SoftShadowView, Tex+float2(SampStep.x*7,0) ) + tex2D( SoftShadowView, Tex-float2(SampStep.x*7,0) ) );

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

VS_OUTPUT VS_passY( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, 0);

    return Out;
}

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{
    float4 Color;

    Color  = WT_0 *   tex2D( ScnSampX, Tex );
    Color += WT_1 * ( tex2D( ScnSampX, Tex+float2(0,SampStep.y  ) ) + tex2D( ScnSampX, Tex-float2(0,SampStep.y  ) ) );
    Color += WT_2 * ( tex2D( ScnSampX, Tex+float2(0,SampStep.y*2) ) + tex2D( ScnSampX, Tex-float2(0,SampStep.y*2) ) );
    Color += WT_3 * ( tex2D( ScnSampX, Tex+float2(0,SampStep.y*3) ) + tex2D( ScnSampX, Tex-float2(0,SampStep.y*3) ) );
    Color += WT_4 * ( tex2D( ScnSampX, Tex+float2(0,SampStep.y*4) ) + tex2D( ScnSampX, Tex-float2(0,SampStep.y*4) ) );
    Color += WT_5 * ( tex2D( ScnSampX, Tex+float2(0,SampStep.y*5) ) + tex2D( ScnSampX, Tex-float2(0,SampStep.y*5) ) );
    Color += WT_6 * ( tex2D( ScnSampX, Tex+float2(0,SampStep.y*6) ) + tex2D( ScnSampX, Tex-float2(0,SampStep.y*6) ) );
    Color += WT_7 * ( tex2D( ScnSampX, Tex+float2(0,SampStep.y*7) ) + tex2D( ScnSampX, Tex-float2(0,SampStep.y*7) ) );

    return Color;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

// 頂点シェーダ
VS_OUTPUT SoftShadow_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 SoftShadow_PS(float2 Tex : TEXCOORD0) : COLOR0
{
    float4 Color = tex2D(ScnSampY, Tex);
    return float4(MaterialColor, Color.r * (1.0f - Alpha));
}

///////////////////////////////////////////////////////////////////////////////////////////////
technique MainTec < string MMDPass = "object"; string Subset = "13";
    string Script = 
        "RenderColorTarget0=ScnMapX;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_X;"
        "RenderColorTarget0=ScnMapY;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	   "Pass=Gaussian_Y;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passY();
        PixelShader  = compile ps_2_0 PS_passY();
    }
    pass DrawObject {
        VertexShader = compile vs_2_0 SoftShadow_VS();
        PixelShader  = compile ps_2_0 SoftShadow_PS();
    }
}


technique MainTec < string MMDPass = "object_ss"; string Subset = "13";
    string Script = 
        "RenderColorTarget0=ScnMapX;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_X;"
        "RenderColorTarget0=ScnMapY;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	   "Pass=Gaussian_Y;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
    ;
> {
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passY();
        PixelShader  = compile ps_2_0 PS_passY();
    }
    pass DrawObject {
        VertexShader = compile vs_2_0 SoftShadow_VS();
        PixelShader  = compile ps_2_0 SoftShadow_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OBJOUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex      : TEXCOORD4;   // スフィアマップテクスチャ座標
    float4 Color      : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OBJOUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap)
{
    VS_OBJOUTPUT Out = (VS_OBJOUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OBJOUTPUT IN, uniform bool useTexture, uniform bool useSphereMap) : COLOR0
{
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    
    float4 Color = IN.Color;
    if ( useTexture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        if(spadd) Color += tex2D(ObjSphareSampler,IN.SpTex);
        else      Color *= tex2D(ObjSphareSampler,IN.SpTex);
    }
    
    // トゥーン適用
    float LightNormal = dot( IN.Normal, -LightDirection );
    Color.rgb *= lerp(MaterialToon, float3(1,1,1), saturate(LightNormal * 16 + 0.5));
    
    // スペキュラ適用
    Color.rgb += Specular;
    
    return Color;
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTec4 < string MMDPass = "object"; string Subset = "0-12";  bool UseTexture = false; bool UseSphereMap = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, false);
    }
}

technique MainTec5 < string MMDPass = "object"; string Subset = "0-12";  bool UseTexture = true; bool UseSphereMap = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, false);
    }
}

technique MainTec6 < string MMDPass = "object"; string Subset = "0-12";  bool UseTexture = false; bool UseSphereMap = true; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true);
        PixelShader  = compile ps_2_0 Basic_PS(false, true);
    }
}

technique MainTec7 < string MMDPass = "object"; string Subset = "0-12";  bool UseTexture = true; bool UseSphereMap = true; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, true);
    }
}


technique MainTec4 < string MMDPass = "object_ss"; string Subset = "0-12";  bool UseTexture = false; bool UseSphereMap = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, false);
    }
}

technique MainTec5 < string MMDPass = "object_ss"; string Subset = "0-12";  bool UseTexture = true; bool UseSphereMap = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, false);
    }
}

technique MainTec6 < string MMDPass = "object_ss"; string Subset = "0-12";  bool UseTexture = false; bool UseSphereMap = true; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true);
        PixelShader  = compile ps_2_0 Basic_PS(false, true);
    }
}

technique MainTec7 < string MMDPass = "object_ss"; string Subset = "0-12";  bool UseTexture = true; bool UseSphereMap = true; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
