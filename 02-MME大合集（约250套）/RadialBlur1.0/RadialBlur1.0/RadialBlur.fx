////////////////////////////////////////////////////////////////////////////////////////////////
//
//	名前:放射ブラー
//	種類:ポストエフェクト
//	作者:kion
//	説明:
//		RadialBlur.xの位置を中心にして放射ブラーをかけます。
//		RadialBlur.xのサイズでブラーの強さを設定。
//		
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ操作用オブジェクト
float Scale		: CONTROLOBJECT < string name = "RadialBlur.x"; >;	// スケール
float4x4 Matrix	: CONTROLOBJECT < string name = "RadialBlur.x"; >;	// ワールド行列
float4x4 ViewProj	: VIEWPROJECTION;	// ビューx透視 変換
static float4 MarkerPos = mul(float4(Matrix._41_42_43,1.0), ViewProj);
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ //

// ブラー中心位置
// (スクリーン座標、(0,0)中心、(-1,-1)～(1,1)の範囲)
static float2 Center = MarkerPos.xy/MarkerPos.w;

// ブラー強さ
// Powerが強すぎると、ブラーが破たんします。→SampNumを大きくするべし。
static float Power = Scale/10.0;

// 処理の細かさ(サンプリング数)
// (0～255)の範囲で指定
// 大きいほどきれいになる。大きくすると負荷増大
static int	SampNum=24;

////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクトの宣言
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// パラメータ計算
float2 ViewportSize : VIEWPORTPIXELSIZE;// スクリーンサイズ
static float2 ss_center = float2((Center.x+1.0f)*0.5f,(-Center.y+1.0f)*0.5f);
static float SampPower = 10.0f * Power/SampNum;

// スクリーンオフセット
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
// サンプリング用オフセット
static float2 SampStep = (float2(2,2)/ViewportSize);

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

////////////////////////////////////////////////////////////////////////////////////////////////
// 頂点シェーダ
struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};
VS_OUTPUT VS_pass( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    return Out;
}
// ピクセルシェーダ
float4 PS_pass( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color=(float)0;
	// 放射状にブラーをかける
	// オフセット
	float2 uvOffset;
	uvOffset = (ss_center-Tex) * (SampPower/ViewportSize);
	// サンプリング数の逆数
	float InvSampling=1.0f/(float)SampNum;	// 色の濃さ
	// テクスチャ座標
	float2 uv = Tex;
	// サンプリングの回数だけ実行
	for(int i=0; i<SampNum; i++) {
		Color+=tex2D(ScnSamp, uv)*InvSampling;
		uv+=uvOffset;// テクスチャ座標的には小さくなると拡大
	}
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique RadialBlur <
    string Script = 
        "RenderColorTarget0=ScnMap; RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
		"Clear=Color; Clear=Depth;"
		    "ScriptExternal=Color;"
        "RenderColorTarget0=; RenderDepthStencilTarget=;"
		    "Pass=RadialBlur;"
    ;
> {
    pass RadialBlur < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_pass();
        PixelShader  = compile ps_2_0 PS_pass();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
