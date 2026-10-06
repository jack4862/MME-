////////////////////////////////////////////////////////////////////////////////////////////////
//
//	名前:ガウスフォーカス
//	種類:ポストエフェクト
//	対応:MMEver0.2x
//	作成:kion
//	説明:
//		画面の周囲をガウスぼかし
//	参考:OldTV.fx
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクトの宣言
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ //
float Tr : CONTROLOBJECT <string name="(self)"; string item = "Tr"; >;	// サイズ
// フレーム
// フレーム範囲(-1.0～1.0)
static float frameLimit = 0.88*Tr;
// フレーム形状(0.0～2.0)
float frameShape =0.24;
// フレームのシャープ具合(0.0～40.0)
float frameSharpness = 8.40;

////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// コントロールオブジェクト //
float Scale : CONTROLOBJECT <string name="(self)";>;	// サイズ
// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2)0.5/ViewportSize;
// レンダリングターゲットのクリア値
float4 ClearColorB = {0,0,0,1}, ClearColorW = {1,1,1,1};
float ClearDepth = 1.0;

// ガウス分散
#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379
float Weights[8]={ WT_0, WT_1, WT_2, WT_3, WT_4, WT_5, WT_6, WT_7 };
// ぼかしの強さ
static float2 SampStep = (float2)(0.004*Scale*0.1*ViewportSize.y) / ViewportSize;


// オリジナルの描画結果を記録するためのレンダーターゲット
// オリジナル
texture2D texOut : RENDERCOLORTARGET
	< float2 ViewportRatio = {1.0, 1.0}; int MipLevels = 1; string Format = "A8R8G8B8"; >;
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET
	< float2 ViewportRatio = {1.0, 1.0}; string Format = "D24S8"; >;
// サンプラー
sampler2D smpOut = sampler_state {
	texture = <texOut>;
	MinFilter = LINEAR; MagFilter=LINEAR; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
// ブラー用
texture2D texBlur1 : RENDERCOLORTARGET
	< float2 ViewportRatio = {1.0, 1.0}; int MipLevels = 1; string Format = "A8R8G8B8"; >;
texture2D texBlur2 : RENDERCOLORTARGET
	< float2 ViewportRatio = {1.0, 1.0}; int MipLevels = 1; string Format = "A8R8G8B8"; >;
// サンプラー
sampler2D smpBlur1 = sampler_state {
	texture = <texBlur1>;
	MinFilter = LINEAR; MagFilter=LINEAR; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
sampler2D smpBlur2 = sampler_state {
	texture = <texBlur2>;
	MinFilter = LINEAR; MagFilter=LINEAR; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// ガウスぼかし //
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
// ガウスぼかし //
float4 PS_Gauss( float2 Tex: TEXCOORD0, uniform float2 GaussDir, uniform sampler2D smp ) : COLOR {   
    float4 Color=(float4)0;
	Color = WT_0*tex2D(smp, Tex);
	for(int i=1;i<8;i++){
		float2 tex = SampStep*i * GaussDir;
		Color += Weights[i] * ( tex2D(smp, Tex+tex) + tex2D(smp, Tex-tex) );
	}
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// フレーム合成 //
float4 PS( float2 Tex: TEXCOORD0) : COLOR
{
	float4 Color = tex2D(smpOut, Tex);
	float4 BColor = tex2D(smpBlur2, Tex);
	// フレーム
	// r = (1-x^2) * (1-y^2)
	// frame = r^z-k
	float2 pos = (Tex-0.5)*2;
	float f = (1 - pos.x * pos.x) * (1 - pos.y * pos.y);
	float frame = saturate(frameSharpness * (pow(f, frameShape) - frameLimit));
	Color = lerp(BColor, Color, frame);
	//Color.rgb = frame;
	// フレーム画像を合成
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック //
technique Gaussian <
	string Script = 
		"RenderColorTarget0=texOut; RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColorW; ClearSetDepth=ClearDepth;"
		"Clear=Color; Clear=Depth;"
			"ScriptExternal=Color;"
        "RenderColorTarget0=texBlur1;"
		"Clear=Color; Clear=Depth;"
			"Pass=PassBlur1;"
		"RenderColorTarget0=texBlur2;"
		"Clear=Color; Clear=Depth;"
			"Pass=PassBlur2;"

        "RenderColorTarget0=; RenderDepthStencilTarget=;"
		"Clear=Color; Clear=Depth;"
			"Pass=PassL;"
	;
> {
	pass PassBlur1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_0 PS_Gauss(float2(1,0),smpOut);
	}
	pass PassBlur2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_0 PS_Gauss(float2(0,1),smpBlur1);
	}
	pass PassL < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_0 PS();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
