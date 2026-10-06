////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:光学迷彩
//	作成;kion
//	種類:ポストエフェクト
//	説明:
//		光学迷彩
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// コントロールオブジェクト //
float4x4 Matrix : CONTROLOBJECT < string name = "(self)"; >;				// 座標
float Scale : CONTROLOBJECT < string name = "(self)"; string item = "Si";>;	// スケール
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ //
// 先頭に「//」でコメントアウトすると無効化できる
#define FLASH				// 点滅させる


////////////////////////////////////////////////////////////////////////////////////////////////
// 詳細な設定 //
// 歪み強さ
static float DistortionRatio = Scale * 0.001;

#ifdef FLASH
// 点滅速度
static float FlashSpeed = Matrix._41;
#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
float time_0_X : Time;	// 時間[s]
// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2)0.5/ViewportSize;
// レンダリングターゲットのクリア値
float4 ClearColorB = {0,0,0,1}, ClearColorW = {1,1,1,1};
float ClearDepth = 1.0;

// オフスクリーンレンダーターゲット
// 法線マップ
// 通常モデルは黒でマスク
texture2D texNormal: OFFSCREENRENDERTARGET <
	string Description = "texNormal For OCamoflage.fx";
	float2 ViewPortRatio = {1.0,1.0};
	float4 ClearColor = { 0, 0, 0, 1 }; float ClearDepth = 1.0;
	string Format="A8R8G8B8";
	bool AntiAlias = true; int Miplevels=1;
	string DefaultEffect =
		"self=hide;"
		"*[OCamoflage]*=NormalMapView.fx;"
		"*=NoCamoflageObject.fx;";
>;
sampler2D smpNormal = sampler_state {
	texture = <texNormal>;
	Filter=NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
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
	MinFilter = LINEAR; MagFilter=LINEAR; MipFilter = 1;
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
	// 法線
	float3 normal = (tex2D(smpNormal, In.Tex).xyz - 0.5) * 2.0;

	// テクスチャ座標をずらす
	// 輪郭付近は消す
	float2 tex = float2(-normal.x, normal.y) * DistortionRatio * normal.z;

#ifdef FLASH
	// 点滅
	float x = (noise(time_0_X*FlashSpeed)+1.0)/2.0;
	tex *= saturate((x-0.1)*2);
#endif

	// 出力
	return tex2D(smpOut, In.Tex+tex);
//	return float4(tex2D(smpNormal, In.Tex).xyz, 1);
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

