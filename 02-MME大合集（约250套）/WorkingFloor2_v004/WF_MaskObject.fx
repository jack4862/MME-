////////////////////////////////////////////////////////////////////////////////////////////////
//
//  WF_MaskObject.fx ver0.0.4  マスク画像作成，描画範囲をマスクする箇所を黒に
//  ( WorkingFloor2.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P( 舞力介入P氏のfull.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////

// マテリアル色
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

////////////////////////////////////////////////////////////////////////////////////////////////

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

//ピクセルシェーダ
float4 PS_EdgeMask() : COLOR {
    return float4(0.0, 0.0, 0.0, 1.0);
}

//エッジ描画
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawMask {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        DestBlend = INVSRCCOLOR;
        PixelShader = compile ps_2_0 PS_EdgeMask();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

//ピクセルシェーダ(透過も考慮)
float4 PS_ObjectMask(float2 Tex : TEXCOORD0, uniform bool useTexture) : COLOR
{
    float alpha = MaterialDiffuse.a;

    if ( useTexture ) {
        // テクスチャ透過値適用
        alpha *= tex2D( ObjTexSampler, Tex ).a;
    }
    // 透過はマスクしない(ただしdiffuse.a=0.99で両面描画設定している場合はマスクする)
    if(alpha < 0.98f) alpha = 0.0f;

    return float4(0.0f, 0.0f, 0.0f, alpha);
}

//セルフシャドウなし
technique Mask < string MMDPass = "object"; bool UseTexture = false; > {
    pass DrawMask {
        PixelShader = compile ps_2_0 PS_ObjectMask(false);
    }
}

technique Mask < string MMDPass = "object"; bool UseTexture = true; > {
    pass DrawMask {
        PixelShader = compile ps_2_0 PS_ObjectMask(true);
    }
}

//セルフシャドウあり
technique MaskSS < string MMDPass = "object_ss"; bool UseTexture = false; > {
    pass DrawMask {
        PixelShader = compile ps_2_0 PS_ObjectMask(false);
    }
}

technique MaskSS < string MMDPass = "object_ss"; bool UseTexture = true; > {
    pass DrawMask {
        PixelShader = compile ps_2_0 PS_ObjectMask(true);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
//地面影は描画しない
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

