////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:コントラスト
//	種類:ポストエフェクト
//	対応:MMEver0.23
//	作成:kion
//	説明:
//		指数関数でコントラスト調整
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
// パラメータ操作用オブジェクト
float4x4 Matrix : CONTROLOBJECT < string name = "(self)"; >;	// 座標
float3 Rxyz : CONTROLOBJECT < string name = "(self)"; string item="Rxyz";>;	// 角度
float Scale : CONTROLOBJECT < string name = "(self)"; string item = "Si";>;	// スケール
float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr";>;	// 透過度
// カーブ調整
// 大きいほど変化がなだらかになる。
// Xが手前、Yが奥
// デフォルトは(X,Y)=(1,2);
// (X,Y)=(1,1)で変化が直線になる。
static float2 Param={Scale*0.1+Matrix._41, Scale*0.1+Matrix._42};
// 色の範囲
static float2 Offset= Rxyz.xy*0.22353f;

////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2)0.5/ViewportSize;
// レンダリングターゲットのクリア値
float4 ClearColorB = {0,0,0,1}, ClearColorW = {1,1,1,1};
float ClearDepth = 1.0;

// レンダーターゲット
// オリジナル
texture2D texOut : RENDERCOLORTARGET <
	float2 ViewportRatio = {1.0, 1.0};	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewportRatio = {1.0, 1.0};	string Format = "D24S8";
>;
// サンプラー
sampler2D smpOut = sampler_state {
	texture = <texOut>;
	MinFilter = LINEAR; MagFilter=LINEAR; MipFilter = NONE;
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
	Color.rgb = 1.0-pow(1.0-pow(saturate((Color.rgb-Offset.x)/(Offset.y-Offset.x)), Param.x), Param.y);
	Color = saturate(Color);
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
		"RenderColorTarget0=; RenderDepthStencilTarget=;"
			"Pass=Pass1;"
	;
> {
	pass Pass1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_0 PS();
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////

