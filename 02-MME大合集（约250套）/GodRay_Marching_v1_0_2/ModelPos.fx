#define CULL NONE

// パラメータ宣言
// 座標変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};
//----


// 輪郭描画用テクニック

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex : TEXCOORD0;
    float4 WPos	 	  : TEXCOORD1;	 // ワールド座標
};

// 頂点シェーダ
VS_OUTPUT ColorRender_VS(float4 Pos : POSITION)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
	Out.WPos = mul(Pos,WorldMatrix);
	return Out;
}

// ピクセルシェーダ
float4 ColorRender_PS(VS_OUTPUT IN) : COLOR
{
	float a = MaterialDiffuse.a;

	a = a > 0.1;
	
    return float4(IN.WPos.xyz,a);
}
// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawEdge {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        
        VertexShader = compile vs_2_0 ColorRender_VS();
        PixelShader  = compile ps_2_0 ColorRender_PS();
    }
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {

}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）


// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION,float2 Tex: TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    Out.Tex = Tex;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
	Out.WPos = mul(Pos,WorldMatrix);

    return Out;
}
///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

// ピクセルシェーダ
float4 BufferShadow_PS(VS_OUTPUT IN) : COLOR0
{
	float a = MaterialDiffuse.a * tex2D(ObjTexSampler,IN.Tex).a;

	a = a > 0.1;
	
    return float4(IN.WPos.xyz,a);
}
technique MainTec0 < string MMDPass = "object";> {
    pass DrawObject {
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Basic_VS();
        PixelShader  = compile ps_3_0 BufferShadow_PS();
    }
}
// オブジェクト描画用テクニック（アクセサリ用）
technique MainTecBS0  < string MMDPass = "object_ss"; > {
    pass DrawObject {
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Basic_VS();
        PixelShader  = compile ps_3_0 BufferShadow_PS();
    }
}
///////////////////////////////////////////////////////////////////////////////////////////////