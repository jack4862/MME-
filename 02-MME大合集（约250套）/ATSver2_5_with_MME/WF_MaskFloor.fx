////////////////////////////////////////////////////////////////////////////////////////////////
//
//  WF_MaskFloor.fx ver0.0.1  マスク画像作成，描画範囲(床)を白,それ以外は黒(ATステージ専用)
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

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////
// 床のマスク描画

//ピクセルシェーダ
float4 PS_Mask() : COLOR {
    return float4(1.0, 1.0, 1.0, 1.0);
}

//セルフシャドウなし
technique Mask < string MMDPass = "object"; string Subset = "13"; > {
    pass DrawMask {
        CullMode = CCW;
        PixelShader = compile ps_2_0 PS_Mask();
    }
}

//セルフシャドウあり
technique MaskSS < string MMDPass = "object_ss"; string Subset = "13"; > {
    pass DrawMask {
        CullMode = CCW;
        PixelShader = compile ps_2_0 PS_Mask();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 床以外のマスク描画

//ピクセルシェーダ(透過も考慮)
float4 PS_ObjectMask(float2 Tex : TEXCOORD0, uniform bool useTexture) : COLOR
{
    float alpha = MaterialDiffuse.a;

    if ( useTexture ) {
        // テクスチャ透過値適用
        alpha *= tex2D( ObjTexSampler, Tex ).a;
    }

    return float4(0.0f, 0.0f, 0.0f, alpha); // 透過はマスクしない
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

//エッジや地面影は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

