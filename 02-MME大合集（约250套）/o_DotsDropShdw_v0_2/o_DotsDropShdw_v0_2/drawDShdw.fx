//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　縁取りのみシェーダ for 水玉ドロップシャドウエフェクト v0.2
//　　　by おたもん（user/5145841）
//
//　　　※このエフェクトは針金Ｐの EdgeControl を改造したものです
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

//=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=
//　ユーザーパラメータ　ここから

//　ドロップシャドウ自体の太さ設定の基準
float ThicknessRate = 1.0;

//　エッジを描画する材質番号（初期値：すべて "0-"）
#define EDGE_ON "0-"

//　ユーザーパラメータ　ここまで
//　ここから先はエフェクトに詳しい方向け
//=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=


//=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=
//　初期定義
#define fmRange 0.8f	// モデルを小さく広く描画することで画面縁の不具合を軽減する

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　各種変数定義

float DotsScale : CONTROLOBJECT < string name = "o_DotsDropShdw.x"; string item = "Si"; >;
static float EdgeThickness = ThicknessRate * (DotsScale + 5.0);

//　座標変換行列
float4x4 WorldMatrix    : WORLD;
float4x4 ViewMatrix     : VIEW;
float4x4 ProjMatrix     : PROJECTION;
float4x4 ViewProjMatrix : VIEWPROJECTION;

float3 CameraPosition   : POSITION  < string Object = "Camera"; >;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
#ifndef MIKUMIKUMOVING
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);
#endif

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state
{
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

bool use_texture;  //テクスチャの有無
bool use_toon;     //トゥーンの有無

//=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=
//　モデルを太らせて描画する
struct VS_OUTPUT
{
	float4 Pos		: POSITION;		// 射影変換座標
	float3 Normal	: COLOR0;		// 法線
	float2 TexCoord	: TEXCOORD0;	// UV
};

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　頂点シェーダ
#ifndef MIKUMIKUMOVING
VS_OUTPUT VS_Draw(float4 Pos: POSITION, float3 Normal: NORMAL, float2 Tex: TEXCOORD0)
#else
VS_OUTPUT VS_Draw(MMM_SKINNING_INPUT IN)
#endif
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	//MikuMikuMoving独自のスキニング関数(MMM_SkinnedPositionNormal)。
	#ifdef MIKUMIKUMOVING
	MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);

	float4 Pos = SkinOut.Position;
	float3 Normal = SkinOut.Normal;
	float2 Tex = IN.Tex;
	#endif

	//　ワールド座標変換
    Out.Pos = mul(Pos, WorldMatrix);
    Out.Normal = normalize(mul(Normal, (float3x3)WorldMatrix));

    // カメラとの距離
    float len = max(length(CameraPosition - Out.Pos), 5.0);

    // 頂点を法線方向に押し出す
    Out.Pos.xyz += Out.Normal * (len * EdgeThickness * 0.0015 * pow(2.4142 / ProjMatrix._11, 0.7));

    // カメラ視点のビュー射影変換
	ProjMatrix._11 *= fmRange;
	ProjMatrix._22 *= fmRange;

	Out.Pos = mul(Out.Pos, mul(ViewMatrix, ProjMatrix));

	Out.TexCoord = Tex;

    return Out;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ピクセルシェーダ（テクスチャ無し材質用）
float4 PS_Draw(VS_OUTPUT IN) : COLOR
{
    return float4(1.0, 1.0, 1.0, 1.0);
}

//　ピクセルシェーダ(テクスチャ有り材質用)
float4 PS_DrawTex(VS_OUTPUT IN) : COLOR
{
    return float4(1.0, 1.0, 1.0, tex2D(ObjTexSampler, IN.TexCoord).a);
}

//=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=
// 輪郭描画用テクニック
technique MainTec < string MMDPass = "object"; bool UseTexture = false; > {
    pass DrawObject {
        CullMode = None;

    	VertexShader = compile vs_2_0 VS_Draw();
        PixelShader  = compile ps_2_0 PS_Draw();
    }
}

technique MainTecBS < string MMDPass = "object_ss"; bool UseTexture = false; > {
    pass DrawObject {
        CullMode = None;

    	VertexShader = compile vs_2_0 VS_Draw();
        PixelShader  = compile ps_2_0 PS_Draw();
    }
}

technique MainTexTec < string MMDPass = "object"; bool UseTexture = true; > {
    pass DrawObject {
        CullMode = None;
        AlphaBlendEnable = true;
        AlphaTestEnable  = false;

    	VertexShader = compile vs_2_0 VS_Draw();
        PixelShader  = compile ps_2_0 PS_DrawTex();
    }
}

technique MainTexTecBS < string MMDPass = "object_ss"; bool UseTexture = true; > {
    pass DrawObject {
        CullMode = None;
        AlphaBlendEnable = true;
        AlphaTestEnable  = false;

    	VertexShader = compile vs_2_0 VS_Draw();
        PixelShader  = compile ps_2_0 PS_DrawTex();
    }
}

technique EdgeTec < string MMDPass = "edge"; > {
}

technique ShadowTec < string MMDPass = "shadow"; > {
}
//=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=
