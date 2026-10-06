//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　画面縁を暗くボカすエフェクト　v0.2
//　　　by おたもん（user/5145841）
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ユーザーパラメータ

//　非透過モード（ 0: 透明部分はそのまま出力、1: 透明部分を白背景として出力）
#define NON_TRANSPARENT 1

//ぼかしのサンプリング数
#define SAMP_NUM  7

//　影の濃さ（0.0～1.0：大きくなるほど濃くなります）
//　　初期設定 0.5
float Opacity
<
   string UIName = "Opacity";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 0.5 );

//　ボカす強さ（0：ボカし無し、大きくなるほど画面端のボケが強くなります）
//　　初期設定 2.0
float Strength
<
   string UIName = "Strength";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 1.0 );

//　ぼかし範囲(サンプリング数は固定のため、大きくしすぎると縞が出ます)
//　　初期設定 0.001953125（=2^-9）
float Extent
<
   string UIName = "Extent";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 0.01;
> = float( 0.001953125 );


//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　初期定義

//　レンダリングターゲットのクリア値
#if NON_TRANSPARENT
float4 ClearColor = {1,1,1,1};
#else
float4 ClearColor = {0.5,0.5,0.5,0};
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
static float alpha = MaterialDiffuse.a;

float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1;
static float Concentration = scaling * Opacity;

//　スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

static float AspectRatio = (ViewportSize.x / ViewportSize.y);
static float2 SampStep = (float2(Extent, Extent)/ViewportSize * ViewportSize.y) * scaling;

//　汚し用テクスチャ（tex169→16:9用テクスチャ、tex43→4:3用テクスチャ）
texture2D tex169 <
	string ResourceName = "noise169.png";
	int MipLevels = 1;
	string Format = "X8R8G8B8" ;
>;
sampler tex169Samp = sampler_state{
	Texture = <tex169>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

texture2D tex43 <
	string ResourceName = "noise43.png";
	int MipLevels = 1;
	string Format = "X8R8G8B8" ;
>;
sampler tex43Samp = sampler_state{
	Texture = <tex43>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

//　深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

//　オリジナルの描画結果を記録するためのレンダーターゲット
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

//　自己乗算とX方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp2 = sampler_state {
	texture = <ScnMap2>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// 共通頂点シェーダ
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_passDraw(float4 Pos : POSITION, float4 Tex : TEXCOORD0) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	
	return Out;
}


//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// X方向ぼかし

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
	float4 sum = 0;
	float e, n = 0, orgAlpha;
	
	[unroll] //ループ展開
	for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
		e = exp(-pow(i / (SAMP_NUM / 2.0), 2.0) / 2.0); //正規分布
		sum += tex2D(ScnSamp, float2(Tex.x + SampStep.x * i, Tex.y)) * e;
		n += e;
	}

	sum /= n;
#if NON_TRANSPARENT == 0
	orgAlpha = tex2D(ScnSamp, Tex).a;
	sum.a = max(tex2D(ScnSamp, Tex), sum.a);
#endif
	return sum;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// Y方向ぼかし + 合成

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
	const float4 ColorOrg = tex2D(ScnSamp, Tex);
	float4 Tonemap, shadowAlpha;		//　汚しテクスチャ
	float4 Color, sum = 0;
	
	float e, n = 0;
	
	[unroll] //ループ展開
	for(int i = -SAMP_NUM; i <= SAMP_NUM; i++){
		e = exp(-pow((float)i / (SAMP_NUM / 2.0), 2.0) / 2.0); //正規分布
		sum += tex2D(ScnSamp2, float2(Tex.x, Tex.y + SampStep.y * i)) * e;
		n += e;
	}
	
	Color = sum / n;
	Color.a = ColorOrg.a;	//　透明部分にはボカシをはみ出させない場合
	//　ここまでボカしプロセス
	
	//　アスペクト比判別→テクスチャの黒さを元にボカし→テクスチャを乗算合成
	Tonemap = AspectRatio > 1.5 ? tex2D(tex169Samp, Tex) : tex2D( tex43Samp, Tex );
	Color.rgb = lerp(Color.rgb, ColorOrg.rgb, pow(Tonemap.rgb, Strength));
	
	shadowAlpha.rgb = Tonemap.rgb * Concentration;

#if NON_TRANSPARENT
	Color.rgb *= (1.0 - Concentration) + shadowAlpha.rgb;
#else
	shadowAlpha.a = Concentration - Concentration * dot(Tonemap.rgb, (1.0f/3.0f));

	if(Color.a == 0) {
		Color.rgb = float3(0,0,0);
		Color.a = shadowAlpha.a;
	} else {
		Color.rgb *= (1.0 - Concentration) + shadowAlpha.rgb;
		Color.a = Color.a * (1.0 - shadowAlpha.a) + shadowAlpha.a;
	}
#endif

	//　アクセサリの不透明度を元にオリジナルと合成
	return lerp(ColorOrg, Color, alpha);
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
		VertexShader = compile vs_3_0 VS_passDraw();
		PixelShader  = compile ps_3_0 PS_passX();
	}
	pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_passDraw();
		PixelShader  = compile ps_3_0 PS_passY();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
