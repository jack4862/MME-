//水面下オブジェクト用シェーダ
//MRT0：法線
shared texture UnderNormal: RENDERCOLORTARGET;
//MRT1：座標
shared texture UnderPos: RENDERCOLORTARGET;
//深度ステンシル
shared texture UnderDepthBuffer : RENDERDEPTHSTENCILTARGET;

#define OBJECT_TEC(name, mmdpass, tex, sphere, toon)\
technique name<\
	string MMDPass = mmdpass; \
	bool UseTexture = tex; \
	bool UseSphereMap = sphere; \
	bool UseToon = toon; \
	string Script = \
		"RenderColorTarget0=;" \
		"RenderColorTarget1=UnderPos;" \
		"RenderDepthStencilTarget0=UnderDepthBuffer;" \
		"Pass=DrawObject;" \
	;\
	> { \
	pass DrawObject { \
		AlphaBlendEnable	= true; \
		AlphaTestEnable		= true; \
		ZEnable				= true; \
		ZWriteEnable		= true; \
		VertexShader = compile vs_3_0 Basic_VS(tex, sphere, toon); \
		PixelShader = compile ps_3_0 Basic_PS(tex, sphere, toon); \
	} \
}

float4 EgColor;
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
float4   EdgeColor         : EDGECOLOR;
float4   GroundShadowColor : GROUNDSHADOWCOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = MaterialAmbient  * LightAmbient + MaterialEmmisive;
static float3 SpecularColor = MaterialSpecular * LightSpecular;

// テクスチャ材質モーフ値
float4   TextureAddValue   : ADDINGTEXTURE;
float4   TextureMulValue   : MULTIPLYINGTEXTURE;
float4   SphereAddValue    : ADDINGSPHERETEXTURE;
float4   SphereMulValue    : MULTIPLYINGSPHERETEXTURE;

bool	 use_subtexture;    // サブテクスチャフラグ

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
    MIPFILTER = LINEAR;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};

// トゥーンマップのテクスチャ
texture ObjectToonTexture: MATERIALTOONTEXTURE;
sampler ObjToonSampler = sampler_state {
    texture = <ObjectToonTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = NONE;
    ADDRESSU  = CLAMP;
    ADDRESSV  = CLAMP;
};


struct PS_OUTPUT {
	float4 Normal : COLOR0;
	float4 Pos : COLOR1;
};


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex      : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float3 WPos		  : TEXCOORD5;
    float4 Color      : COLOR0;      // ディフューズ色
    float3 Specular   : COLOR1;      // スペキュラ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.WPos = mul( Pos,WorldMatrix);
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
		if ( use_subtexture ) {
			// PMXサブテクスチャ座標
			Out.SpTex = Tex2;
	    } else {
	        // スフィアマップテクスチャ座標
	        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
	        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
	        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
	    }
    }
    
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(Out.Eye) + -LightDirection );
    Out.Specular = pow( max(0,dot( HalfVector, Out.Normal )), SpecularPower ) * SpecularColor;
    
    return Out;
}
//エッジ用頂点シェーダ
VS_OUTPUT Edge_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.WPos = mul( Pos,WorldMatrix);
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
		if ( use_subtexture ) {
			// PMXサブテクスチャ座標
			Out.SpTex = Tex2;
	    } else {
	        // スフィアマップテクスチャ座標
	        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
	        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
	        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
	    }
    }
    
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(Out.Eye) + -LightDirection );
    Out.Specular = pow( max(0,dot( HalfVector, Out.Normal )), SpecularPower ) * SpecularColor;
    
    return Out;
}

// ピクセルシェーダ
PS_OUTPUT Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR0
{
	PS_OUTPUT Out = (PS_OUTPUT)0;
	
    float4 Color = IN.Color;
    if ( useTexture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) Color.rgb += TexColor.rgb;
        else      Color.rgb *= TexColor.rgb;
        Color.a *= TexColor.a;
    }
    
    if ( useToon ) {
        // トゥーン適用
        float LightNormal = dot( IN.Normal, -LightDirection );
        Color *= tex2D(ObjToonSampler, float2(0, 0.5 - LightNormal * 0.5) );
    }
    
	Out.Normal = float4(IN.Normal,Color.a > 0.9);
	Out.Pos = float4(IN.WPos,Color.a > 0.9);
	return Out;
}
technique ZplotTec < string MMDPass = "zplot"; > {}
//technique EdgeTec < string MMDPass = "edge"; > {}

technique EdgeTec < string MMDPass = "edge";
string Script = 
	"RenderColorTarget0=;" 
	"RenderColorTarget1=UnderPos;" 
	"RenderDepthStencilTarget0=UnderDepthBuffer;" 
	"Pass=DrawObject;" 
;
> { 
	pass DrawObject {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;
        
		VertexShader = compile vs_3_0 Edge_VS(false, false, false);
		PixelShader = compile ps_3_0 Basic_PS(false, false, false);
	}
}

technique ShadowTec < string MMDPass = "shadow"; > {}


OBJECT_TEC(MainTec0, "object", false, false, false)
OBJECT_TEC(MainTec1, "object", true, false, false)
OBJECT_TEC(MainTec2, "object", false, true, false)
OBJECT_TEC(MainTec3, "object", true, true, false)
OBJECT_TEC(MainTec4, "object", false, false, true)
OBJECT_TEC(MainTec5, "object", true, false, true)
OBJECT_TEC(MainTec6, "object", false, true, true)
OBJECT_TEC(MainTec7, "object", true, true, true)

OBJECT_TEC(MainTecBS0, "object_ss", false, false, false)
OBJECT_TEC(MainTecBS1, "object_ss", true, false, false)
OBJECT_TEC(MainTecBS2, "object_ss", false, true, false)
OBJECT_TEC(MainTecBS3, "object_ss", true, true, false)
OBJECT_TEC(MainTecBS4, "object_ss", false, false, true)
OBJECT_TEC(MainTecBS5, "object_ss", true, false, true)
OBJECT_TEC(MainTecBS6, "object_ss", false, true, true)
OBJECT_TEC(MainTecBS7, "object_ss", true, true, true)

///////////////////////////////////////////////////////////////////////////////////////////////
