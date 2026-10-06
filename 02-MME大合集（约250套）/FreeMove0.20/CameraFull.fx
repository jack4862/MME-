////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:独自のカメラで描画した内容を表示
//	作成;kion
//	種類:ポストエフェクト
//	説明:
//		カメラの映像をフルスクリーンで表示		
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ //
// 背景画像のサイズ
#define ANTI_ALIAS	1
// カメラ画像
texture texCamera: OFFSCREENRENDERTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	float4 ClearColor = { 1, 1, 1, 1 }; float ClearDepth = 1.0;
	bool AntiAlias = ANTI_ALIAS; int Miplevels=0;
	string DefaultEffect = "self=hide; CameraSmooth.x=hide; CameraMove.x=hide; Cam1Pos.x=hide; *=Camera1.fx;";
>;
// サンプラー
sampler smpCamera = sampler_state{
	Texture = <texCamera>;
	MAGFILTER = LINEAR; MINFILTER = LINEAR; MIPFILTER = LINEAR;
	ADDRESSU = CLAMP; ADDRESSV = CLAMP;
};

// 左右反転フラグ
#define INVERSE_X	false
// 上下反転フラグ
#define INVERSE_Y	false

////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2)0.5/ViewportSize;
// レンダリングターゲットのクリア値
float4 ClearColorB = {0,0,0,1}, ClearColorW = {1,1,1,1};
float ClearDepth = 1.0;

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
	if(INVERSE_X) Out.Tex.x=1.0-Out.Tex.x;
	if(INVERSE_Y) Out.Tex.y=1.0-Out.Tex.y;
	return Out;
}
// ピクセルシェーダ
float4 PS( VS_OUTPUT In ) : COLOR
{
	float4 Color = (float4)1;
	Color=tex2D(smpCamera, In.Tex);
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique Main <
	string Script =
		"RenderColorTarget0=; RenderDepthStencilTarget=;"
		"ClearSetColor=ClearColorW; ClearSetDepth=ClearDepth;"
		"Clear=Color; Clear=Depth;"
			"ScriptExternal=Color;"
		"RenderColorTarget0=; RenderDepthStencilTarget=;"
		"Clear=Color; Clear=Depth;"
		"Pass=Pass1;"
	;
> {
	pass Pass1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS();
		PixelShader = compile ps_3_0 PS();
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////