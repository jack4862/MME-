////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ShadowDraw.fx v0.3
//  作成: データP
//
////////////////////////////////////////////////////////////////////////////////////////////////

#include "config.h"

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// 各種テクニックを見えないように潰す
technique MainTec < string MMDPass = "object"; > { }
technique MainTec < string MMDPass = "zplot"; > { }
technique MainTec < string MMDPass = "edge"; > { }
technique MainTec < string MMDPass = "shadow"; > { }

float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

#ifndef ShadowMinTr // 透過の固定化対応
float ShadowMinTr : CONTROLOBJECT <string name = "(OffscreenOwner)"; string item = "Tr"; >;
#endif

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット
struct VS_ZValuePlot_OUTPUT {
    float4 Pos : POSITION;              // 射影変換座標
    float4 ShadowMapTex : TEXCOORD0;    // Zバッファテクスチャ
    float2 Tex : TEXCOORD1;				// テクスチャ
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

    // ライトの目線によるワールドビュー射影変換をする
    Out.Pos = mul(Pos, LightWorldViewProjMatrix);

    // テクスチャ座標を頂点に合わせる
    Out.ShadowMapTex = Out.Pos;

	Out.Tex = Tex;
    return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS(VS_ZValuePlot_OUTPUT IN, uniform bool useTexture ) : COLOR
{
	float alph = MaterialDiffuse.a * (useTexture ? tex2D(ObjTexSampler, IN.Tex).a : 1);
	clip((MaterialDiffuse.a==0.98) ? -1 : alph - ShadowMinTr);
    // R色成分にZ値を記録する
    return float4(IN.ShadowMapTex.z/IN.ShadowMapTex.w,0,0,1);
}

technique ZplotTec < 
	string MMDPass = "object_ss";
	bool UseTexture = false;
>
{
    pass ZValuePlot {
		AlphaBlendEnable = false;
        CullMode = NONE;
        VertexShader = compile vs_2_0 ZValuePlot_VS();
        PixelShader  = compile ps_2_0 ZValuePlot_PS(false);
    }
}

technique ZplotTec2 < 
	string MMDPass = "object_ss";
	bool UseTexture = true;
>
{
    pass ZValuePlot {
		AlphaBlendEnable = false;
        CullMode = NONE;
        VertexShader = compile vs_2_0 ZValuePlot_VS();
        PixelShader  = compile ps_2_0 ZValuePlot_PS(true);
    }
}
