/////////////////////////////////////////
// ポスト前髪影用シェーダー by P.I.P
// 
// そぼろ様のEdgeOnly.fxを改変
// 
/////////////////////////////////////////

//前髪影が出ない場合にオンにしたりオフにしたりする
//#define CULLING CCW

// 前髪影色デフォルト
static float3 HairShadowColorDefault255 = float3(229, 204, 178)/255;


// 前髪影色デフォルト(R,G,B)
static float3 HairShadowColorDefault
<
   string UIName = "Color";
   string UIWidget = "Color";
> = HairShadowColorDefault255;


// 前髪影初期方向
float3 HairShadowDirection
<
   string UIName = "Position";
   string UIWidget = "Numeric";
   float3 UIMin = float3(-0.5, -0.5, -0.5);
   float3 UIMax = float3( 0.5,  0.5,  0.5); 
> = float3(-0.05, -0.05, 0.05);

// 前髪影位置ずらし倍率（MMDの照明方向の影響を受ける場合のみ有効）
float Zurashi = 0.1;


// 前髪影がMMDの照明方向を受けないようにする（影響を受けるようにする場合は下の行に「//」を付ける。 例「//#define MMDLightOFF」）
#define MMDLightOFF


float3 XYZ : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "XYZ"; >;
float3 Rxyz : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "Rxyz"; >;
float Si : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "Si"; >;


////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
//float4   EdgeColor         : EDGECOLOR;

static float4 HairShadowColor = float4(HairShadowColorDefault, 1.0) + float4(Rxyz/10, 0);


// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

////////////////////////////////////////////////////////////////////////////////////////////////


struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    //float2 Tex        : TEXCOORD1;
    
};


#ifdef MIKUMIKUMOVING
// 頂点シェーダ
VS_OUTPUT ColorRender_VS(MMM_SKINNING_INPUT IN)
{

	MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);
	
	float4 Pos = SkinOut.Position;
    float3 Normal = SkinOut.Normal;
    //float2 Tex = IN.Tex;

#else
VS_OUTPUT ColorRender_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{

#endif
	
	VS_OUTPUT Out = (VS_OUTPUT)0;

	
	#ifdef MMDLightOFF	
	Pos.xy += HairShadowDirection.xy + XYZ.xy/10;
	
	#else
	Pos.xy += LightDirection.xy * Zurashi * Si/10 + XY.xy/10;
	
	#endif

	
	// カメラ視点のワールドビュー射影変換
	Out.Pos = mul( Pos, WorldViewProjMatrix );
	//Out.Tex = Tex;
	
	
    return Out;
	

}

// ピクセルシェーダ
float4 ColorRender_PS() : COLOR
{
    
	// 単色塗りつぶし
	return HairShadowColor;
}


// 輪郭描画
// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
}






///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
    
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

//struct VS_OUTPUT {
//    float4 Pos        : POSITION;    // 射影変換座標
//    
//};

// 頂点シェーダ

#ifdef MIKUMIKUMOVING

VS_OUTPUT Basic_VS(MMM_SKINNING_INPUT IN)
{
    MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);
    
    float4 Pos = SkinOut.Position;
    float3 Normal = SkinOut.Normal;
    //float2 Tex = IN.Tex;
    
#else
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{

#endif
    
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN) : COLOR0
{
    
    return float4(0,0,0,0);
}

// オブジェクト描画用テクニック（アクセサリ用）
// 不要なものは削除可
technique MainTec0 < string MMDPass = "object"; > {
    pass DrawObject {
        AlphaTestEnable=false;

        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
	pass DrawEdge {
	
	    #ifdef CULLING
	    CullMode = CULLING;
	    #else
        //CullMode = CW;
        #endif
        VertexShader = compile vs_2_0 ColorRender_VS();
        PixelShader  = compile ps_2_0 ColorRender_PS();
    }
	
	
}

technique MainTecBS0  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        AlphaTestEnable=false;

        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS();
    }
	pass DrawEdge {
        #ifdef CULLING
	    CullMode = CULLING;
	    #else
        //CullMode = CW;
        #endif
        VertexShader = compile vs_2_0 ColorRender_VS();
        PixelShader  = compile ps_2_0 ColorRender_PS();
    }
	
	
}

///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
    
}


///////////////////////////////////////////////////////////////////////////////////////////////
