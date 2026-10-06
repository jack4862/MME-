////////////////////////////////////////////////////////////////////////////////////////////////
//
//	名前:暗視ゴーグル
//	種類:ポストエフェクト
//	対応:MMEver0.23
//	参考:OldTV.fx
//	作成:kion
//	説明:
//		画面にノイズ+グリーンカラーに
//
///////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;
///////////////////////////////////////////////////////////////////////////////////////
// パラメータ //
// パラメータ操作用オブジェクト
float3 XYZ : CONTROLOBJECT < string name = "(self)"; string item = "XYZ";>;	// 座標
float3 Rxyz : CONTROLOBJECT < string name = "(self)"; string item="Rxyz";>;	// 角度
float Scale : CONTROLOBJECT < string name = "(self)"; string item = "Si";>;	// スケール
float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr";>;	// 透過度
// ノイズ
// ノイズ強さ(0.0～1.0)
// デフォルト0.49
static float interference = Tr;
// ランダムテクスチャ(3D)
// ノイズ用
texture3D Rand_Tex < string ResourceName = "Random3D.dds"; >;
// ノイズの色
static float3 NoiseColor = {1,1,1};//Rxyz*0.22353f;
// ノイズ濃度
static float NoiseDens = 1.0;

// 暗視ゴーグル色
static float3 NightVisionColor = {0, Scale*0.1, 0};

// フレーム
// フレーム範囲(-1.0～1.0)
static float frameLimit = 0.58;
// フレーム形状(0.0～2.0)
float frameShape =0.24;
// フレームのシャープ具合(0.0～40.0)
float frameSharpness = 8.40;

///////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
float3 RGB2Y = {0.29891f, 0.58661f, 0.11448f};
// 時間
float time_0_X : TIME;
// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2)0.5/ViewportSize;
// バッファクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;
// オリジナル画像
texture2D texOut : RenderColorTarget
	< float2 ViewPortRatio={1.0,1.0}; string Format="A8R8G8B8"; >;
texture2D DepthBuffer : RenderDepthStencilTarget
	< float2 ViewPortRatio = {1.0,1.0}; string Format = "D24S8"; >;
// サンプラー
sampler2D smpOut = sampler_state{
	Texture = <texOut>;
	MAGFILTER = LINEAR; MINFILTER = LINEAR; MIPFILTER = NONE;
	ADDRESSU = CLAMP; ADDRESSV = CLAMP;
};
sampler3D Rand = sampler_state{
	Texture = <Rand_Tex>;
	MAGFILTER = LINEAR; MINFILTER = LINEAR; MIPFILTER = NONE;
	ADDRESSU = WRAP; ADDRESSV = WRAP; ADDRESSW = WRAP;
};

///////////////////////////////////////////////////////////////////////////////////////
// 頂点シェーダー出力
struct VS_OUTPUT {
	float4 Pos		: POSITION;
	float2 TexRaw	: TEXCOORD0;
	float2 Tex		: TEXCOORD1;
};
// 頂点シェーダ
VS_OUTPUT VS( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0;
	// 頂点
	Out.Pos = Pos;
	Out.TexRaw = Pos.xy;
	// テクスチャ座標
	Out.Tex = Tex + ViewportOffset;
	return Out;
}
// ピクセルシェーダー
float4 PS(VS_OUTPUT In) : COLOR
{
	// オリジナル画像を取得
	float4 Color = tex2D(smpOut, In.Tex);
	Color.rgb= pow(Color.rgb*2, 0.5);
	float Y = dot(Color, RGB2Y);
	Color.rgb = Y * NightVisionColor;

	// ノイズ
	float rand = tex3D(Rand, float3(1.5*NoiseDens*In.TexRaw, time_0_X)).r+0.2;
	// ノイズを合成
	Color.rgb -= interference * rand * NoiseColor * 0.5;

	// フレーム
	// r = (1-x^2) * (1-y^2)
	// frame = r^z-k
	float2 pos = (In.Tex-0.5)*2;
	float f = (1 - pos.x * pos.x) * (1 - pos.y * pos.y);
	float frame = saturate(frameSharpness * (pow(f, frameShape) - frameLimit));
	Color = lerp(float4(0,0,0,1), Color, frame);

	Color.a = 1;
	return saturate(Color);
}

///////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique ScreenNoise<
    string Script = 
		// オリジナル画像
		"RenderColorTarget0=texOut; RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
		"Clear=Color; Clear=Depth;"
			"ScriptExternal=Color;"
		"RenderColorTarget0=; RenderDepthStencilTarget=;"
			"Pass=Noise;";
> {
	pass Noise < string Script= "Draw=Buffer;"; >{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_0 PS();
	}
}

