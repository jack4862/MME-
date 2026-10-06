// パラメータ宣言
/*
DRAW_ALPHA に「1」を指定すると"テクスチャが半透明"のピクセルを
オフスクリーンバッファにレンダリングしなくなります。
(＝SSAOの計算から無視されます)
*/
#define DRAW_ALPHA 0

//-----------------------------------------------------
//ここから先はエフェクトに詳しい方はいじらないほうが良いです

float fmRange = 0.8f;

// 座法変換行列
float4x4 matWVP		: WORLDVIEWPROJECTION;
float4x4 matWV		: WORLDVIEW;
float4x4 matProj	: PROJECTION;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

struct VS_OUTPUT
{
	float4 Pos		: POSITION;		// 射影変換座標
	float2 TexCoord	: TEXCOORD0;	// UV
	float4 Depth	: TEXCOORD1;	// 頂点深度
};

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

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	matProj._11 *= fmRange;
	matProj._22 *= fmRange;

	Out.Pos = mul( Pos, mul(matWV, matProj) );
	
	Out.Depth = Out.Pos;
	Out.TexCoord = Tex;
	
	return Out;
}

// ピクセルシェーダ
float4 Basic_PS( VS_OUTPUT IN ) : COLOR
{
	float a = 1.0f;
	
	if(use_texture)
	{
		a = tex2D(ObjTexSampler,IN.TexCoord).a;
		
		if(DRAW_ALPHA && a < 1.0f)
		{
			a = 0.0f;
		}
	}
	
	return float4(IN.Depth.z/IN.Depth.w,1,1,a);
}

// オブジェクト描画用テクニック
technique MainTec < string MMDPass = "object"; > {
	pass DrawObject
	{
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS();
	}
}

// オブジェクト描画用テクニック
technique MainTecBS  < string MMDPass = "object_ss"; > {
	pass DrawObject {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS();
	}
}
technique EdgeTec < string MMDPass = "edge"; > {

}
technique ShadowTech < string MMDPass = "shadow";  > {
	
}
