//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　デフュージョンエフェクト v0.5
//　　　by おたもん（user/5145841）
//
//　　　※このフィルタはそぼろ様のディフュージョンフィルタを元に
//　　　　明るい部分だけをボカす本来の効果のみ得られるようにしたものです。
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ユーザーパラメータ

//　非透過モード（ 0: 透明部分はそのまま出力、1: 透明部分を白背景として出力）
#define NON_TRANSPARENT 1

//ぼかしのサンプリング数
#define SAMP_NUM  7

//　使用テクスチャ（ 0: 整数テクスチャ、1: 浮動小数点数テクスチャ）
#define USE_FLOAT_TEXTURE 0

//　ぼかし範囲(サンプリング数は固定のため、大きくしすぎると縞が出ます)
//　　初期設定 0.001953125（=2^-9）
float Extent = 0.001953125;

//　簡易色調補正（ 赤, 緑, 青（,α）の順に指定、1で変化なし）
//　　初期設定 1.0, 1.0, 1.0, 1.0
float3 ColorFilter
<
   string UIName = "簡易色調補正";
   string UIWidget = "Spinner";
   bool UIVisible =  true;
   float3 UIMin = float3( 0.0, 0.0, 0.0 );
   float3 UIMax = float3( 2.0, 2.0, 2.0 );
> = float3( 1.0, 1.0, 1.0 );

//　MMD出力と合成する比率（0で変化なし、1に近づくほどエフェクトが強くかかる）
//　　初期設定 0.6666667（= 2/3）
float Strength
<
   string UIName = "合成比率";
   string UIWidget = "Spinner";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = 2.0/3.0;


//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　初期定義
#define B_COLOR 0.5

//　レンダリングターゲットのクリア値
#if NON_TRANSPARENT
float4 ClearColor = {1.0, 1.0, 1.0, 1.0};
#else
float4 ClearColor = {B_COLOR, B_COLOR, B_COLOR, 0.0};
#endif
float ClearDepth  = 1.0;

//　ポストエフェクト宣言
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

//　アクセサリ操作設定値を取得
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;

float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1;

float3 ObjXYZ0 : CONTROLOBJECT < string name = "(self)"; >;
static float3 ObjXYZ = ObjXYZ0 + 1.0;

//　スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 SampStep = (float2(Extent,Extent)/ViewportSize*ViewportSize.y) * scaling;

//　深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

//　オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
#if USE_FLOAT_TEXTURE
	string Format = "A16B16G16R16F";
#else
	string Format = "A8R8G8B8";
#endif
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

//　自己乗算とX方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
#if USE_FLOAT_TEXTURE
	string Format = "A16B16G16R16F";
#else
	string Format = "A8R8G8B8";
#endif
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
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


//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// X方向ぼかし

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 sum = 0;
    float e, f, n = 0;
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
		f = float(i);

		e = exp(-pow(f / (SAMP_NUM / 2.0), 2.0) / 2.0); //正規分布
        sum += pow(tex2D(ScnSamp, float2(Tex.x + SampStep.x * f, Tex.y)), 2.0) * e; //RGBを2乗
        n += e;
    }
    
    return sum / n;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// Y方向ぼかし + 合成

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color, sum = 0;
    
    float e, f, n = 0;
    
    [unroll] //ループ展開
    for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
		f = float(i);

		e = exp(-pow(f / (SAMP_NUM / 2.0), 2.0) / 2.0); //正規分布
		sum += tex2D(ScnSamp2, float2(Tex.x, Tex.y + SampStep.y * f)) * e;
		n += e;
    }
    Color = sum / n;

	float4 ColorOrg = tex2D(ScnSamp, Tex);
    float4 ColorSrc = float4(pow(ColorOrg.rgb, 2), ColorOrg.a);

    // Color = 乗算 + ボカし（Pb）　ColorW = 白画面　ColorSrc = 乗算（Pa）　ColorOrg = MMD
    //　スクリーン合成
    Color = ColorSrc + Color - ColorSrc * Color;

	//　色調補正量を暗さに比例させて合成
	Color.rgb = lerp(Color.rgb * ObjXYZ * ColorFilter, Color.rgb, Color.rgb);

	//　MMD 出力と合成結果を比較（明）でブレンド
	Color = max(Color, ColorOrg);

	//　合成比率とアクセサリの不透明度を元にオリジナルと合成
	Color = lerp(ColorOrg, Color, Strength * alpha1);
#if NON_TRANSPARENT == 0
//	Color.a = max(ColorOrg.a, Color.a);	//　透明部分にもボカシをはみ出させたい場合
	Color.a = ColorOrg.a;				//　透明部分にはボカシをはみ出させない場合
#endif
	return Color;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

technique Diffusion <
    string Script = 
        
        "RenderColorTarget0=ScnMap;"
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
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passY();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
