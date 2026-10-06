////////////////////////////////////////////////////////////////////////////////////////////////
//
//  FinderDrawB.fx v0.11b
//  データP
//  full.fx v1.2(舞力介入P)をベースに改変
//  FinderMonitorより改変
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define EdgeMaterial "0-"		// エッジを描画する材質番号
#define EdgeThick (1 * 0.001)	// エッジの太さ

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


#define VMatrix_Offset 0
#define PMatrix_Offset 4
#define MemorySize 8
shared texture FinderMemory : RENDERCOLORTARGET <
	int Width=MemorySize;
	int Height=1;
    bool AntiAlias = false;
	int MipLevels = 1;
	string Format = "D3DFMT_A32B32G32R32F";
>;

float4 FinderArray[MemorySize] : TEXTUREVALUE <
	string TextureName = "FinderMemory";
>;

// 座法変換行列
float4x4 WorldMatrix				: WORLD;
static const float4x4 ViewMatrix = float4x4(FinderArray[VMatrix_Offset+0], FinderArray[VMatrix_Offset+1], FinderArray[VMatrix_Offset+2], FinderArray[VMatrix_Offset+3] );
static const float4x4 ProjMatrix = float4x4(FinderArray[PMatrix_Offset+0], FinderArray[PMatrix_Offset+1], FinderArray[PMatrix_Offset+2], FinderArray[PMatrix_Offset+3] );
static const float4x4 WorldViewProjMatrix = mul(WorldMatrix, mul(ViewMatrix, ProjMatrix));

float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
static const float3   CameraPosition=-ViewMatrix[3].xyz;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
float3   EdgeColor         : EDGECOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画
// tan(22.5)=2.414213562373
static const float EdgeSize = EdgeThick * 2.414213562373 / ProjMatrix._22;
float4 SelfEdge_VS(float4 Pos : POSITION, float3 Norm : NORMAL) : POSITION {
	// カメラとの距離と、視野角で太さを補正
	float thickness = max(length(mul(Pos, WorldMatrix) - CameraPosition) , 5) * EdgeSize;
	Pos.xyz += thickness * Norm;
	return mul(Pos, WorldViewProjMatrix);
}

// ピクセルシェーダ
float4 ColorRender_PS() : COLOR {
    return float4(EdgeColor,1);
}

// 輪郭描画用テクニック
// 輪郭は"object","object_ss"で描く
technique EdgeTec < string MMDPass = "edge";>{}

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
        VertexShader = compile vs_2_0 Shadow_VS();
        PixelShader  = compile ps_2_0 Shadow_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex      : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 Color      : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR0
{
    float4 Color = IN.Color;
    if ( useTexture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }
    if ( useSphereMap) {
        // スフィアマップ適用
        if(spadd) Color.rgb += tex2D(ObjSphareSampler,IN.SpTex).rgb;
        else      Color *= tex2D(ObjSphareSampler,IN.SpTex);
    }
    if ( useToon ) {
        // トゥーン適用
        float LightNormal = dot( IN.Normal, -LightDirection );
        Color.rgb *= lerp(MaterialToon, float3(1,1,1), saturate(LightNormal * 2 + 0.5));
    }
    
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;

    // スペキュラ適用
    Color.rgb += Specular;
    return Color;
}


// オブジェクト描画用テクニック
// 不要なものは削除可
#define BASIC_TEC(name, tex, sphere, toon) \
	technique name < string MMDPass = "object"; bool UseTexture = tex; bool UseSphereMap = sphere; bool UseToon = toon; \
	> { \
		pass DrawObject { \
			VertexShader = compile vs_2_0 Basic_VS(tex, sphere, toon); \
			PixelShader  = compile ps_2_0 Basic_PS(tex, sphere, toon); \
		} \
	}

BASIC_TEC(MainTec0, false, false, false)
BASIC_TEC(MainTec1, true,  false, false)
BASIC_TEC(MainTec2, false, true,  false)
BASIC_TEC(MainTec3, true,  true,  false)

// オブジェクト描画用テクニック（PMDモデル用） エッジ描画
#define BASIC_TEC_E(name, tex, sphere) \
	technique name < string MMDPass = "object"; string Subset = EdgeMaterial; bool UseTexture = tex; bool UseSphereMap = sphere; bool UseToon = true; \
	> { \
		pass DrawEdge { \
			CullMode = CW; \
			AlphaBlendEnable = TRUE; \
			AlphaTestEnable  = TRUE; \
			VertexShader = compile vs_2_0 SelfEdge_VS(); \
			PixelShader  = compile ps_2_0 ColorRender_PS(); \
		} \
		pass DrawObject { \
			VertexShader = compile vs_2_0 Basic_VS(tex, sphere, true); \
			PixelShader  = compile ps_2_0 Basic_PS(tex, sphere, true); \
		} \
	}

BASIC_TEC_E(MainTec4E, false, false)
BASIC_TEC_E(MainTec5E, true,  false)
BASIC_TEC_E(MainTec6E, false, true )
BASIC_TEC_E(MainTec7E, true,  true )

BASIC_TEC(MainTec4, false, false, true)
BASIC_TEC(MainTec5, true,  false, true)
BASIC_TEC(MainTec6, false, true,  true)
BASIC_TEC(MainTec7, true,  true,  true)


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
    float2 SpTex    : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 Color    : COLOR0;       // ディフューズ色
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul(Pos,WorldViewProjMatrix);

    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	// ライト視点によるワールドビュー射影変換
    Out.ZCalcTex = mul(Pos, LightWorldViewProjMatrix);

    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
    return Out;
}

// ピクセルシェーダ
// シャドウマップが違うので、自前描画の時は、モード１相当とする。
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
    float4 Color = IN.Color;
    float4 ShadowColor = float4(AmbientColor, Color.a);  // 影の色
    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        Color *= TexColor;
        ShadowColor *= TexColor;
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) {
            Color.rgb += TexColor.rgb;
            ShadowColor.rgb += TexColor.rgb;
        } else {
            Color *= TexColor;
            ShadowColor *= TexColor;
        }
    }
    float comp = 1;
    if(useToon){
		comp = saturate(dot(IN.Normal,-LightDirection)*Toon);
		ShadowColor.rgb *= MaterialToon;
	}
    // スペキュラ適用
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    Color.rgb += Specular;

    // テクスチャ座標に変換
    IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
    
    if( !any( saturate(TransTexCoord) != TransTexCoord ) ) {
		float shadow = max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r, 0);
		comp = min(comp, 1 - saturate(shadow *
			(parthf ? SKII2*TransTexCoord.y // セルフシャドウモード2
					: SKII1 // セルフシャドウモード1
			) - 0.3));
    }
	Color = lerp(ShadowColor, Color, comp);
    if( transp ) Color.a *= 0.5f;
    return Color;
}

// オブジェクト描画用テクニック（アクセサリ用）
#define SELFSHADOW_TEC(name, tex, sphere, toon) \
	technique name < string MMDPass = "object_ss"; bool UseTexture = tex; bool UseSphereMap = sphere; bool UseToon = toon; \
	> { \
		pass DrawObject { \
			VertexShader = compile vs_2_0 BufferShadow_VS(tex, sphere, toon); \
			PixelShader  = compile ps_2_0 BufferShadow_PS(tex, sphere, toon); \
		} \
	}

SELFSHADOW_TEC(MainTecBS0, false, false, false)
SELFSHADOW_TEC(MainTecBS1, true,  false, false)
SELFSHADOW_TEC(MainTecBS2, false, true,  false)
SELFSHADOW_TEC(MainTecBS3, true,  true,  false)

// オブジェクト描画用テクニック（PMDモデル用） エッジ描画
#define SELFSHADOW_TEC_E(name, tex, sphere) \
	technique name < string MMDPass = "object_ss"; string Subset = EdgeMaterial; bool UseTexture = tex; bool UseSphereMap = sphere; bool UseToon = true; \
	> { \
		pass DrawEdge { \
			CullMode = CW; \
			AlphaBlendEnable = TRUE; \
			AlphaTestEnable  = TRUE; \
			VertexShader = compile vs_2_0 SelfEdge_VS(); \
			PixelShader  = compile ps_2_0 ColorRender_PS(); \
		} \
		pass DrawObject { \
			VertexShader = compile vs_2_0 BufferShadow_VS(tex, sphere, true); \
			PixelShader  = compile ps_2_0 BufferShadow_PS(tex, sphere, true); \
		} \
	}

SELFSHADOW_TEC_E(MainTecBS4E, false, false)
SELFSHADOW_TEC_E(MainTecBS5E, true,  false)
SELFSHADOW_TEC_E(MainTecBS6E, false, true )
SELFSHADOW_TEC_E(MainTecBS7E, true,  true )

SELFSHADOW_TEC(MainTecBS4, false, false, true )
SELFSHADOW_TEC(MainTecBS5, true,  false, true )
SELFSHADOW_TEC(MainTecBS6, false, true,  true )
SELFSHADOW_TEC(MainTecBS7, true,  true,  true )

///////////////////////////////////////////////////////////////////////////////////////////////
