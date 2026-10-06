////////////////////////////////////////////////////////////////////////////////////////////////
//
//  AnimatedHatchingShader_v1.0
//  作成: eye
//  元ネタ: PostHatchingShader (データP様 & Ogugu様)
//
////////////////////////////////////////////////////////////////////////////////////////////////

// パラメータ宣言

// ハッチングパターンファイルの設定
#define HATCHING_IMAGE_FILE		"hatchingSuisai2.gif"
#define AnimeStart 0.0              // アニメーション開始時間(単位：秒)
#define AnimeFPS 12                 // アニメーションフレーム数(単位：fps)

float HatchingTileRepeat_Default <
	string UIName = "ハッチングの細かさ";
	string UIWidget = "Slider";
	bool UIVisible =  true;
	float UIMin = 0.0;
	float UIMax = 10.0;
	float UIDefault = 3.0;
> = float( 3.0 );

float Si : CONTROLOBJECT <string name="(self)"; string item="Si";>;
static const float Siz=0.1*Si;

static const float HATCIHNG_TILE_REPEAT = HatchingTileRepeat_Default*Siz;

// ポストエフェクト宣言
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

float Tr : CONTROLOBJECT <string name="(self)"; string item="Tr";>;

float2 ViewportSize : VIEWPORTPIXELSIZE;

static const float2 ViewportOffset = float2(0.5,0.5)/ViewportSize;

// ハッチングパターンイメージ
texture HatchingImage : ANIMATEDTEXTURE <
   string ResourceName = HATCHING_IMAGE_FILE;
    float Offset = AnimeStart;
    float Speed = AnimeFPS / 30.00 ;
>;
sampler HatchingSampler = sampler_state {
	Texture = (HatchingImage);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = WRAP;
	AddressV  = WRAP;
};

// 処理用テクスチャ
texture OrgScreen : RENDERCOLORTARGET <
	string Format = "A8R8G8B8";
	float2 ViewPortRatio = {1,1};
>;
sampler OrgSampler = sampler_state {
	texture = <OrgScreen>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV  = CLAMP;
};
texture OrgSizeDepth : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

// UV map
texture UVMap : OFFSCREENRENDERTARGET <
	string Description = "UVMap";
	string Format = "A16B16G16R16F";
	float4 ClearColor = {0,0,0,0};
	float ClearDepth = 1.0;
	int Miplevels = 1;
	string DefaultEffect =
	    "self=hide;"
	    "*=DrawUV.fx;";
>;
sampler UVMapSampler = sampler_state {
	texture = <UVMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
float2 UVFromPoint(float2 xy){
	return tex2D(UVMapSampler, xy).rg;
}

/////////////////////////////
// コピー用の汎用頂点シェーダ
struct VS_OUTPUT {
	float4 Pos: POSITION;
	float2 Tex: TEXCOORD0;
};

VS_OUTPUT CopyVS(float4 Pos : POSITION, float2 Tex : TEXCOORD0 ){ 
	VS_OUTPUT Out;
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	return Out;
}

/////////////////////////////////////////////////
// ハッチングPS
static const float3 LuminousCoef = {0.29891, 0.58661, 0.11448 };
float LuminousFromColor(float3 color){
	return dot(LuminousCoef, color);
}
float4 HatchingPS(float2 Tex: TEXCOORD0):COLOR{
	float4 org = tex2D(OrgSampler, Tex);
	const float2 uv = UVFromPoint(Tex);
	const float luminous = LuminousFromColor(org.rgb);

	const int index = min(15, luminous*16);
	const float weight = frac(luminous*16);

	float f0 = tex2D( HatchingSampler, 0.25*(frac(uv*float2(-1,1)*HATCIHNG_TILE_REPEAT) + float2(3-index%4, index/4))).r;

	const int uindex=index+1;
	float f1=1; // ハッチングマップを超えた白
	if(uindex<16){
		f1 = tex2D( HatchingSampler, 0.25*(frac(uv*float2(-1,1)*HATCIHNG_TILE_REPEAT) + float2(3-uindex%4, uindex/4))).r;
	}
	const float f = lerp(f0, f1, weight);
	float3 color = lerp(org.rgb, float3(1,1,1), f);
	return float4(lerp(org.rgb, color, Tr), org.a);
}

float4 ClearColor = {1, 1, 1, 0};
float ClearDepth  = 1;

technique PostEffectTec <
	string Script =
		"RenderColorTarget=OrgScreen;"
		"RenderDepthStencilTarget=OrgSizeDepth;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		"RenderColorTarget=;"
		"RenderDepthStencilTarget=;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=Effect;"
	;
>{
	pass Effect < string Script = "Draw=Buffer;"; >{
		AlphaBlendEnable = false;
		AlphaTestEnable  = false;
		VertexShader = compile vs_2_0 CopyVS();
		PixelShader  = compile ps_2_0 HatchingPS();
	}
};
