////////////////////////////////////////////////////////////////////////////////////////////////
//
//
//  参考：Color.fx / ビームマンP様
//        simple.fx ver1.0 / 舞力介入P様
////////////////////////////////////////////////////////////////////////////////////////////////

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;

float4 MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

bool use_texture;  //テクスチャの有無

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};


// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
};

////////////////////////////////////////////////////////////////////////////////////////////////
// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION0,  float2 Tex : TEXCOORD0)
{
	VS_OUTPUT Out;
	Out.Pos = mul(Pos,WorldViewProjMatrix);
    Out.Tex = Tex;
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(float2 Tex : TEXCOORD1) : COLOR0
{
    float4 Color = 0;   
    Color.a = MaterialDiffuse.a;
    
    if ( use_texture ) {
        // テクスチャ適用。テクスチャが指定されている場合のみ。
        Color *= tex2D( ObjTexSampler, Tex );
    }
    Color.rgb = float3(1.0, 1.0, 1.0); 
    //Color = float4(1.0, 1.0, 1.0, 1.0); 
    
    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
technique MainTec < string MMDPass = "object";> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}
technique MainTec_ss < string MMDPass = "object_ss";> {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
}


// 他は非表示
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }






