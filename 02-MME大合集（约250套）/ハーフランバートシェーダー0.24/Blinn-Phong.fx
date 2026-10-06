////////////////////////////////////////////////////////////////////////////////////////////////
//　Blinn-Phongシェーダーっぽいの　いじった人：納豆カレー
//		参考	Maverick Project(http://maverickproj.web.fc2.com/pg00.html)
//			Phong.fx(NVIDIA Shader Library)
//			full.fx(舞力介入P)
//			advancedTexureMapping2(Furia氏)
////////////////////////////////////////////////////////////////////////////////////////////////

// パラメータ宣言

// 光源を増やす場合はここを追加して下さい（編集箇所はピクセルシェーダ内にもう一つあります）
// 光源位置
float3 LightPosition0 : CONTROLOBJECT < string name = "PointLight0.x";>;
float3 LightPosition1 : CONTROLOBJECT < string name = "PointLight1.x";>;
float3 LightPosition2 : CONTROLOBJECT < string name = "PointLight2.x";>;
float3 LightPosition3 : CONTROLOBJECT < string name = "PointLight3.x";>;

// 光源色
float3 LightColor0 : CONTROLOBJECT < string name = "PointLight0.x"; string item = "Rxyz"; >;
float3 LightColor1 : CONTROLOBJECT < string name = "PointLight1.x"; string item = "Rxyz"; >;
float3 LightColor2 : CONTROLOBJECT < string name = "PointLight2.x"; string item = "Rxyz"; >;
float3 LightColor3 : CONTROLOBJECT < string name = "PointLight3.x"; string item = "Rxyz"; >;

// 光源の明るさ
float LightPower0 : CONTROLOBJECT < string name = "PointLight0.x"; string item = "Si"; >;
float LightPower1 : CONTROLOBJECT < string name = "PointLight1.x"; string item = "Si"; >;
float LightPower2 : CONTROLOBJECT < string name = "PointLight2.x"; string item = "Si"; >;
float LightPower3 : CONTROLOBJECT < string name = "PointLight3.x"; string item = "Si"; >;

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 ViewProjMatrix           : VIEWPROJECTION;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

//float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;

// ライト色
//float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
//float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float3 AmbientColor  = saturate(MaterialEmmisive*MaterialToon*LightAmbient/0.60);

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
//bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE<
	int MipLevels = 1;
	string Format = "A8R8G8B8" ;
>;

sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = LINEAR;
	MAXANISOTROPY = 16;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {}


///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
    // カメラ視点のワールドビュー射影変換
    return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
    // アンビエント色で塗りつぶし
    return float4(AmbientColor.rgb, 0.65f);
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
    pass DrawShadow {
        VertexShader = compile vs_3_0 Shadow_VS();
        PixelShader  = compile ps_3_0 Shadow_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
    float4 Pos : POSITION;              // 射影変換座標
    float4 ShadowMapTex : TEXCOORD;    // Zバッファテクスチャ
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION )
{
    VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

    // ライトの目線によるワールドビュー射影変換をする
    Out.Pos = mul( Pos, LightWorldViewProjMatrix );

    // テクスチャ座標を頂点に合わせる
    Out.ShadowMapTex = Out.Pos;

    return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0 ) : COLOR
{
    // R色成分にZ値を記録する
    return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
    pass ZValuePlot {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 ZValuePlot_VS();
        PixelShader  = compile ps_3_0 ZValuePlot_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float4 ZCalcTex : TEXCOORD0;    // Z値
    float2 Tex      : TEXCOORD1;    // テクスチャ
    float3 Normal   : TEXCOORD2;    // 法線
    float3 Eye      : TEXCOORD3;    // カメラとの相対位置
    float4 WPos     : TEXCOORD5;    // ワールド位置
    float4 Color    : COLOR0;       // ディフューズ色
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.WPos= mul( Pos, WorldMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - Out.WPos;

    // 頂点法線
    Out.Normal = mul( Normal, (float3x3)WorldMatrix );

    // ライト視点によるワールドビュー射影変換
    Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
    
    // 環境色計算
    Out.Color.rgb = AmbientColor;
    Out.Color.a = MaterialDiffuse.a + 0.01; // α=0.99等で透けるのを防止
       
    // テクスチャ座標
    Out.Tex = Tex;
    
    return Out;
}

// 拡散反射光と鏡面反射光の計算
float2 LightVec(float3 L, float LightPower, float3 Nn, float3 Vn) {

    // 距離減衰の計算
    float Distance = length(L);
    Distance *= Distance * 0.01 / LightPower;

    // ほとんど光の届かない部分はライティングをスキップ
    [ifAny] if(Distance>100.0f) {
        return (0,0);
    }
    else {

        float3 Ln = normalize(L);
        float3 Hn = normalize(Vn + Ln);  

        // リムライティング
        float RimPower = max( 0.0f, dot( -Vn, Ln ) );
        float Rim = 1.0f - max( 0.0f, dot( Nn, Vn ) );

        // ハーフランバート照明
        float lit = dot(Ln,Nn);
        lit = lit*0.5f + 0.5;

        // リムライティング加算
        lit += Rim*RimPower*0.8;
        lit *= lit;

        return float2( lit, pow( max(0, dot(Hn, Nn)), SpecularPower ) )/Distance;
    }
}

// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture) : COLOR
{
    float3 Nn = normalize(IN.Normal);
    float3 Vn = normalize(IN.Eye);
    float4 Color = IN.Color;
    float4 ShadowColor = IN.Color;

    // 反射光計算
    float2 litV0 = LightVec(LightPosition0-IN.WPos.xyz, LightPower0, Nn, Vn);
    float3 diffContrib = litV0.x*LightColor0;
    float3 specContrib = litV0.y*LightColor0;

    // 光源を増やした場合はこの固まりも増やしていけばOK
    // 光源4つもいらない場合は不要なものを削除すれば少し軽くなるかも
    float2 litV1 = LightVec(LightPosition1-IN.WPos.xyz, LightPower1, Nn, Vn);
    diffContrib += litV1.x*LightColor1;
    specContrib += litV1.y*LightColor1;

    float2 litV2 = LightVec(LightPosition2-IN.WPos.xyz, LightPower2, Nn, Vn);
    diffContrib += litV2.x*LightColor2;
    specContrib += litV2.y*LightColor2;

    float2 litV3 = LightVec(LightPosition3-IN.WPos.xyz, LightPower3, Nn, Vn);
    diffContrib += litV3.x*LightColor3;
    specContrib += litV3.y*LightColor3;
	
    // 材質色適用
    Color.rgb += MaterialDiffuse.rgb*diffContrib;

    // テクスチャ適用   
    if ( useTexture ) {
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        Color *= TexColor;
        ShadowColor *= TexColor;
    }

    // テクスチャ座標に変換
    IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;

    if(any( saturate(TransTexCoord) != TransTexCoord ) ) {
        // シャドウバッファ外
        Color.rgb += specContrib*MaterialSpecular;
        return (Color);
    } else {
	float comp;
        if(parthf) {
            // セルフシャドウ mode2
            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
        } else {
            // セルフシャドウ mode1
            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII1-0.3f);
        }
        
        comp = min(diffContrib*Toon,comp);

        // セルフシャドウの色
        ShadowColor.rgb = Color.rgb * 0.9;
        float4 ans = lerp(ShadowColor , Color, comp);

        // 影の部分はスペキュラを加算しない
        ans.rgb += specContrib*MaterialSpecular*comp;

        if( transp ) ans.a = 0.5f;

            return (ans);
    } 
}

// オブジェクト描画用テクニック
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false;> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false);
    }
}

technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true;> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true);
    }
}
///////////////////////////////////////////////////////////////////////////////////////////////