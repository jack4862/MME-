////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:トーンマッピング
//	作成;kion
//	種類:ポストエフェクト
//	説明:
//		トーンマッピング		
//
////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
float Scale	: CONTROLOBJECT < string name = "ToneMapping.x"; >;
// マテリアル色
float4   MaterialDiffuse: DIFFUSE < string Object = "Geometry"; >;
// ライトカラー
float3 LightAmbient		: AMBIENT < string Object = "Light"; >;
// 輝度計算係数
float3 RGB2L = float3(0.29891f, 0.58661f, 0.11448f);
//static float LightY = dot(RGB2L, LightAmbient);

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ //
// 明るさ
//static float LValue = LightY*Scale/10.0+0.25;
static float LValue = Scale/10.0;
// 輝度計算の対象領域(全体を1とする)
static float ViewScale = MaterialDiffuse.a;
// 輝度への対応速度(大きいほど速く)
static float AdaptLuminanceSpeed = 32;

////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2)0.5/ViewportSize;
// レンダリングターゲットのクリア値
float4 ClearColorB = {0,0,0,1}, ClearColorW = {1,1,1,1};
float ClearDepth = 1.0;

// 時間[s]
float Time : TIME;				// 再生時間
float ElapsedTime : ELAPSEDTIME;// 1フレームの時間

// レンダリングターゲット
// オリジナル
shared texture2D texOut : RENDERCOLORTARGET <
	float2 ViewportRatio = {2.0, 2.0};	int MipLevels = 1;
	//string Format = "A8R8G8B8"; >;	
	string Format = "A32B32G32R32F"; >;
shared texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewportRatio = {2.0, 2.0};	string Format = "D24S8"; >;
// 512x512
texture2D tex512 : RENDERCOLORTARGET <
	int2 Dimensions = {512, 512}; int MipLevels = 1;
	//string Format = "A8R8G8B8"; >;
	string Format = "A32B32G32R32F"; >;
texture2D db512 : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = {512, 512};	string Format = "D24S8"; >;
// 256x256
texture2D tex256 : RENDERCOLORTARGET <
	int2 Dimensions = {256, 256}; int MipLevels = 1;
	string Format = "A32B32G32R32F"; >;
texture2D db256 : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = {256, 256};	string Format = "D24S8"; >;
// 128x128
texture2D tex128 : RENDERCOLORTARGET <
	int2 Dimensions = {128, 128}; int MipLevels = 1;
	string Format = "A32B32G32R32F"; >;
texture2D db128 : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = {512, 512};	string Format = "D24S8"; >;
// 64x64
texture2D tex64 : RENDERCOLORTARGET <
	int2 Dimensions = {64, 64}; int MipLevels = 1;
	string Format = "A32B32G32R32F"; >;
texture2D db64 : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = {512, 512};	string Format = "D24S8"; >;
// 32x32
texture2D tex32 : RENDERCOLORTARGET <
	int2 Dimensions = {32, 32}; int MipLevels = 1;
	string Format = "A32B32G32R32F"; >;
texture2D db32 : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = {32, 32};	string Format = "D24S8"; >;
// 16x16
texture2D tex16 : RENDERCOLORTARGET <
	int2 Dimensions = {16, 16}; int MipLevels = 1;
	string Format = "A32B32G32R32F"; >;
texture2D db16 : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = {16, 16};	string Format = "D24S8"; >;
// 8x8
texture2D tex8 : RENDERCOLORTARGET <
	int2 Dimensions = {8, 8}; int MipLevels = 1;
	string Format = "A32B32G32R32F"; >;
texture2D db8 : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = {8, 8};	string Format = "D24S8"; >;
// 4x4
texture2D tex4 : RENDERCOLORTARGET <
	int2 Dimensions = {4, 4}; int MipLevels = 1;
	string Format = "A32B32G32R32F"; >;
texture2D db4 : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = {4, 4};	string Format = "D24S8"; >;
// 2x2
texture2D tex2 : RENDERCOLORTARGET <
	int2 Dimensions = {2, 2}; int MipLevels = 1;
	string Format = "A32B32G32R32F"; >;
texture2D db2 : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = {2, 2};	string Format = "D24S8"; >;
// 1x1
texture2D tex1 : RENDERCOLORTARGET <
	int2 Dimensions = {1, 1}; int MipLevels = 1;
	string Format = "A32B32G32R32F"; >;
texture2D db1 : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = {1, 1};	string Format = "D24S8"; >;
// 適応輝度
texture2D texAdapt : RENDERCOLORTARGET <
	int2 Dimensions = {1, 1}; int MipLevels = 1;
	string Format = "A32B32G32R32F"; >;
texture2D dbAdapt : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = {1, 1};	string Format = "D24S8"; >;

// サンプラー
sampler2D smpOut = sampler_state {
	texture = <texOut>;
	MinFilter = LINEAR; MagFilter=LINEAR; MipFilter = NONE;
	//MinFilter = NONE; MagFilter=NONE; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
sampler2D smp512 = sampler_state {
	texture = <tex512>;
	MinFilter = NONE; MagFilter=NONE; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
sampler2D smp256 = sampler_state {
	texture = <tex256>;
	MinFilter = NONE; MagFilter=NONE; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
sampler2D smp128 = sampler_state {
	texture = <tex128>;
	MinFilter = NONE; MagFilter=NONE; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
sampler2D smp64 = sampler_state {
	texture = <tex64>;
	MinFilter = NONE; MagFilter=NONE; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
sampler2D smp32 = sampler_state {
	texture = <tex32>;
	MinFilter = NONE; MagFilter=NONE; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
sampler2D smp16 = sampler_state {
	texture = <tex16>;
	MinFilter = NONE; MagFilter=NONE; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
sampler2D smp8 = sampler_state {
	texture = <tex8>;
	MinFilter = NONE; MagFilter=NONE; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
sampler2D smp4 = sampler_state {
	texture = <tex4>;
	MinFilter = NONE; MagFilter=NONE; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
sampler2D smp2 = sampler_state {
	texture = <tex2>;
	MinFilter = NONE; MagFilter=NONE; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
sampler2D smp1 = sampler_state {
	texture = <tex1>;
	MinFilter = NONE; MagFilter=NONE; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
sampler2D smpAdapt = sampler_state {
	texture = <texAdapt>;
	MinFilter = NONE; MagFilter=NONE; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// 頂点出力
struct VS_OUTPUT {
	float4 Pos	: POSITION;
	float2 Tex	: TEXCOORD0;
};
// 頂点シェーダ
VS_OUTPUT VS( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	return Out;
}
// ピクセルシェーダ
float4 PS( VS_OUTPUT In ) : COLOR
{
	float4 Color = (float4)1;
	Color=tex2D(smpOut, In.Tex);
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輝度計算 Step0
// 縮小バッファにコピー
// 頂点シェーダ
VS_OUTPUT PreVS( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	Out.Tex = ViewScale*Out.Tex + 0.5*(1.0-ViewScale);
	return Out;
}
// ピクセルシェーダ
float4 PrePS( VS_OUTPUT In ) : COLOR
{
	float4 Color = (float4)1;
	Color=tex2D(smpOut, In.Tex);
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輝度計算 Step1
// 頂点出力
struct VS_OUTPUT4 {
	float4 Pos	: POSITION;
	float2 Tex1	: TEXCOORD0;
	float2 Tex2	: TEXCOORD1;
	float2 Tex3	: TEXCOORD2;
	float2 Tex4	: TEXCOORD3;
};
// 最初
// 参照テクスチャのサイズを渡す
VS_OUTPUT4 VS4( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float size ) {
	VS_OUTPUT4 Out = (VS_OUTPUT4)0;
	Out.Pos = Pos;
	float2 t=0.5/size;
	Out.Tex1 = Tex + float2(t.x,t.y);
	Out.Tex2 = Tex + float2(3*t.x,t.y);
	Out.Tex3 = Tex + float2(t.x,3*t.y);
	Out.Tex4 = Tex + float2(3*t.x,3*t.y);
	return Out;
}
// ピクセルシェーダ
float4 FirstPS( VS_OUTPUT4 In , uniform sampler2D smp) : COLOR
{
	float e = 0.0001;
	float4 Color = (float4)1;
	float y1 = dot(RGB2L, tex2D(smp, In.Tex1));
	float y2 = dot(RGB2L, tex2D(smp, In.Tex2));
	float y3 = dot(RGB2L, tex2D(smp, In.Tex3));
	float y4 = dot(RGB2L, tex2D(smp, In.Tex4));
	// 輝度の最大値
	Color.r = max(max(y1,y2),max(y3,y4));
	// logの平均
	Color.g = log(e + y1) + log(e + y2) + log(e + y3) + log(e + y4);
	Color.g *= 0.25;
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輝度計算 Step2
// ピクセルシェーダ
float4 PS4( VS_OUTPUT4 In , uniform sampler2D smp) : COLOR
{
	float e = 0.0001;
	float4 Color = (float4)1;
	float4 t1 = tex2D(smp, In.Tex1);
	float4 t2 = tex2D(smp, In.Tex2);
	float4 t3 = tex2D(smp, In.Tex3);
	float4 t4 = tex2D(smp, In.Tex4);
	// 輝度の最大値
	Color.r = max(max(t1.r,t2.r),max(t3.r,t4.r));
	// logの平均
	Color.g = t1.g + t2.g + t3.g + t4.g;
	Color.g *= 0.25;
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輝度計算 Step3
// ピクセルシェーダ
float4 LastPS4( VS_OUTPUT4 In , uniform sampler2D smp) : COLOR
{
	float e = 0.0001;
	float4 Color = (float4)1;
	float4 t1 = tex2D(smp, In.Tex1);
	float4 t2 = tex2D(smp, In.Tex2);
	float4 t3 = tex2D(smp, In.Tex3);
	float4 t4 = tex2D(smp, In.Tex4);
	// 輝度の最大値
	Color.r = max(max(t1.r,t2.r),max(t3.r,t4.r));
	// logの平均
	Color.g = t1.g + t2.g + t3.g + t4.g;
	Color.g *= 0.25;

	// トーンマッピング係数計算
	//Color.g = LValue * (exp(-Color.g)+e);	// 輝度計算係数
	//Color.r = Color.g * Color.r;	// 最大輝度
	return Color;
}
////////////////////////////////////////////////////////////////////////////////////////////////
// 輝度計算 Step4
// 瞳孔シミュレーション
// ピクセルシェーダ
float4 AdaptPS( VS_OUTPUT4 In) : COLOR
{
	float4 Color = (float4)1;
	float4 y = tex2D(smp1, float2(0.5,0.5));
	float2 ay = tex2D(smpAdapt, float2(0.5,0.5)).rg;
	// 瞳孔シミュレーション
	if(Time<0.01) Color.rg = float2(1.0, 0);
	else
		Color.rg = ay + (y.rg - ay) * (1-pow(0.98f, AdaptLuminanceSpeed*ElapsedTime));
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輝度計算 LastStep
// トーンマッピング
float4 TonePS( VS_OUTPUT In ) : COLOR
{
	float4 Color = (float4)1;
	float e = 0.0001;
	// RGB - YCbCr 相互変換用行列
	float3x3 RGB2YCbCr = {	{0.29891f, 0.58661f, 0.11448f},
							{-0.16874f, -0.33126f, 0.50000f},
							{0.50000f, -0.41869f, -0.08131f} };

	float3x3 YCbCr2RGB = {	{1.0f, 0.0f, 1.40200f},
							{1.0f, -0.34414f, -0.71414f},
							{1.0f, 1.77200f, 0.0f} };
	// 元の画像
	float3 c = tex2D(smpOut, In.Tex).rgb;
	// 輝度情報
	//float2 y = tex2D(smp1, float2(0.5,0.5)).rg;
	float2 y = tex2D(smpAdapt, float2(0.5,0.5)).rg;

	// トーンマッピング
	// 係数計算
	float k = LValue * (exp(-y.g)+e);	// 輝度計算係数
	float Lmax = k * y.r;	// 最大輝度
	//float k = y.g;		// 輝度計算係数
	//float Lmax = y.r;	// 最大輝度
	// 元画像の輝度計算
	float3 YCbCr = mul(RGB2YCbCr,c);
	float L = k * YCbCr.r;	// 輝度
	// トーン調整
	YCbCr.r = L*(1.0+L/(Lmax*Lmax)) / (1.0+L);
	//YCbCr.r = L / (1.0+L);
	// YCbCrからRGBに変換
	Color.rgb = mul(YCbCr2RGB,YCbCr);

	//Color.rgb = tex2D(smp512, In.Tex).rgb;
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique Main <
	string Script =
		"RenderColorTarget0=texOut; RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColorW; ClearSetDepth=ClearDepth;"
		"Clear=Color; Clear=Depth;"
			"ScriptExternal=Color;"

		"RenderColorTarget0=tex512; RenderDepthStencilTarget=db512;"
		"Clear=Color; Clear=Depth;"
		"Pass=Pass1;"

		"RenderColorTarget0=tex256; RenderDepthStencilTarget=db256;"
		"Clear=Color; Clear=Depth;"
		"Pass=Pass2;"
		"RenderColorTarget0=tex128; RenderDepthStencilTarget=db128;"
		"Clear=Color; Clear=Depth;"
		"Pass=Pass3;"
		"RenderColorTarget0=tex64; RenderDepthStencilTarget=db64;"
		"Clear=Color; Clear=Depth;"
		"Pass=Pass4;"
		"RenderColorTarget0=tex32; RenderDepthStencilTarget=db32;"
		"Clear=Color; Clear=Depth;"
		"Pass=Pass5;"
		"RenderColorTarget0=tex16; RenderDepthStencilTarget=db16;"
		"Clear=Color; Clear=Depth;"
		"Pass=Pass6;"
		"RenderColorTarget0=tex8; RenderDepthStencilTarget=db8;"
		"Clear=Color; Clear=Depth;"
		"Pass=Pass7;"
		"RenderColorTarget0=tex4; RenderDepthStencilTarget=db4;"
		"Clear=Color; Clear=Depth;"
		"Pass=Pass8;"
		"RenderColorTarget0=tex2; RenderDepthStencilTarget=db2;"
		"Clear=Color; Clear=Depth;"
		"Pass=Pass9;"
		"RenderColorTarget0=tex1; RenderDepthStencilTarget=db1;"
		"Clear=Color; Clear=Depth;"
		"Pass=Pass10;"

		"RenderColorTarget0=texAdapt; RenderDepthStencilTarget=dbAdapt;"
		//"Clear=Color; Clear=Depth;"
		"Pass=PassAdapt;"

		"RenderColorTarget0=; RenderDepthStencilTarget=;"
		"Pass=PassTone;"
	;
> {
	pass Pass1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 PreVS();
		PixelShader = compile ps_3_0 PrePS();
	}
	pass Pass2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS4(512);
		PixelShader = compile ps_3_0 FirstPS(smp512);
	}
	pass Pass3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS4(256);
		PixelShader = compile ps_3_0 PS4(smp256);
	}
	pass Pass4 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS4(128);
		PixelShader = compile ps_3_0 PS4(smp128);
	}
	pass Pass5 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS4(64);
		PixelShader = compile ps_3_0 PS4(smp64);
	}
	pass Pass6 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS4(32);
		PixelShader = compile ps_3_0 PS4(smp32);
	}
	pass Pass7 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS4(16);
		PixelShader = compile ps_3_0 PS4(smp16);
	}
	pass Pass8 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS4(8);
		PixelShader = compile ps_3_0 PS4(smp8);
	}
	pass Pass9 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS4(4);
		PixelShader = compile ps_3_0 PS4(smp4);
	}
	pass Pass10 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS4(2);
		PixelShader = compile ps_3_0 LastPS4(smp2);
	}

	pass PassAdapt < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS();
		PixelShader = compile ps_3_0 AdaptPS();
	}

	pass PassTone < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS();
		PixelShader = compile ps_3_0 TonePS();
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////

