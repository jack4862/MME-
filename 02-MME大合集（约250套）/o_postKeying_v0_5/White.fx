//-----------------------------------------------------------------------------
// パラメータ宣言
#define KEY_COLOR 1.0f

//-----------------------------------------------------------------------------
//ここから先はエフェクトに詳しい方以外はいじらないほうが良いです

// 座法変換行列
float4x4 WorldViewProjMatrix	  : WORLDVIEWPROJECTION;
float4x4 WorldMatrix			  : WORLD;
float4x4 ViewMatrix			   : VIEW;

// マテリアル色
float4 MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
static const float  MaterialAlpha = MaterialDiffuse.a;
float4   GroundShadowColor : GROUNDSHADOWCOLOR;

float4 EdgeColor		 : EDGECOLOR;
static const float  EdgeAlpha = EdgeColor.a;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state
{
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

bool use_texture;  //テクスチャの有無
//bool use_toon;	 //トゥーンの有無

struct VS_OUTPUT
{
	float4 Pos		: POSITION;		// 射影変換座標
	float2 TexCoord	: TEXCOORD0;	// UV
	float4 Depth	: TEXCOORD1;	// 頂点深度
};

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　オブジェクト描画

// 頂点シェーダ
#ifndef MIKUMIKUMOVING
VS_OUTPUT Basic_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD0)
#else
VS_OUTPUT Basic_VS(MMM_SKINNING_INPUT IN)
#endif
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	//　MikuMikuMoving 独自のスキニング関数(MMM_SkinnedPosition)。
	#ifdef MIKUMIKUMOVING
	float4 Pos = MMM_SkinnedPosition(IN.Pos, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);
	float2 Tex = IN.Tex;
	#endif

	// カメラ視点のワールドビュー射影変換
	Out.Pos = mul( Pos, WorldViewProjMatrix );
	
	Out.Depth = Out.Pos;
	Out.TexCoord = Tex;
	
	return Out;
}

// ピクセルシェーダ（テクスチャなし）
float4 Basic_PS(VS_OUTPUT IN) : COLOR
{
	return float4(KEY_COLOR, KEY_COLOR, KEY_COLOR, MaterialAlpha);
}
// ピクセルシェーダ（テクスチャあり）
float4 Tex_PS(VS_OUTPUT IN) : COLOR
{
	return float4(KEY_COLOR, KEY_COLOR, KEY_COLOR, MaterialAlpha * tex2D(ObjTexSampler,IN.TexCoord).a);
}

// オブジェクト描画（セルフシャドウ：なし、テクスチャ：なし）用テクニック
technique MainTec <
	string MMDPass = "object";
	bool UseTexture = false;
> {
	pass DrawObject
	{
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS();
	}
}
// オブジェクト描画（セルフシャドウ：なし、テクスチャ：あり）用テクニック
technique MainTexTec <
	string MMDPass = "object";
	bool UseTexture = true;
> {
	pass DrawObject
	{
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Tex_PS();
	}
}

// オブジェクト描画（セルフシャドウ：あり、テクスチャ：なし）用テクニック
technique MainTecBS  <
	string MMDPass = "object_ss";
	bool UseTexture = false;
> {
	pass DrawObject {
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS();
	}
}
// オブジェクト描画（セルフシャドウ：あり、テクスチャ：あり）用テクニック
technique MainTexTecBS  <
	string MMDPass = "object_ss";
	bool UseTexture = true;
> {
	pass DrawObject {
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Tex_PS();
	}
}
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// 輪郭描画

// 頂点シェーダ
#ifdef MIKUMIKUMOVING
float4 ColorRender_VS(MMM_SKINNING_INPUT IN) : POSITION
#else
float4 ColorRender_VS(float4 Pos : POSITION) : POSITION
#endif
{
	//　MikuMikuMoving 独自のスキニング関数(MMM_SkinnedPosition)
	#ifdef MIKUMIKUMOVING
	float4 Pos = MMM_SkinnedPosition(IN.Pos, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);
	#endif

	// カメラ視点のワールドビュー射影変換
	return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 ColorRender_PS() : COLOR
{
	return float4(KEY_COLOR, KEY_COLOR, KEY_COLOR, EdgeAlpha);
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
	pass DrawEdge {
//		AlphaBlendEnable = TRUE;
		AlphaBlendEnable = FALSE;
		AlphaTestEnable  = FALSE;

		VertexShader = compile vs_2_0 ColorRender_VS();
		PixelShader  = compile ps_2_0 ColorRender_PS();
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット
//technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 頂点シェーダ
#ifndef MIKUMIKUMOVING
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
#else
float4 Shadow_VS(MMM_SKINNING_INPUT IN) : POSITION
#endif
{
	//================================================================================
	//MikuMikuMoving独自のスキニング関数(MMM_SkinnedPosition)。座標を取得する。
	//================================================================================
	#ifdef MIKUMIKUMOVING
	float4 Pos = MMM_SkinnedPosition(IN.Pos, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);
	#endif

    // カメラ視点のワールドビュー射影変換
    return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
    // 白色で塗りつぶし
    return float4(1,1,1,GroundShadowColor.a);
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
    pass DrawShadow {
        VertexShader = compile vs_2_0 Shadow_VS();
        PixelShader  = compile ps_2_0 Shadow_PS();
    }
}

