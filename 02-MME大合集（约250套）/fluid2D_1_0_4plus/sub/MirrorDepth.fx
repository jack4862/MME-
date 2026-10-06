//ミラー深度用シェーダ

#define OBJECT_TEC(name, mmdpass, tex, sphere, toon)\
technique name<\
	string MMDPass = mmdpass; \
	bool UseTexture = tex; \
	bool UseSphereMap = sphere; \
	bool UseToon = toon; \
	string Script = \
		"RenderColorTarget0=;" \
		"RenderDepthStencilTarget0=;" \
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

////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MWF_Object.fx ver0.0.2  モデルを鏡像描画
//  ( MirrorWF.fx から呼び出されます．オフスクリーン描画用)
//  作成: 針金P( 舞力介入P氏のMirror.fx, full.fx,改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// アクセに組み込む場合はここを適宜変更してください．
float3 MirrorPos = float3( 0.0, 0.0, 0.0 );    // ローカル座標系における鏡面上の任意の座標(アクセ頂点座標の一点)
float3 MirrorNormal = float3( 0.0, 1.0, 0.0 ); // ローカル座標系における鏡面の法線ベクトル

///////////////////////////////////////////////////////////////////////////////////////////////

// ローカル座標系における鏡像位置への変換
static float3 n = normalize(MirrorNormal);
static float4x4 MirrorMatrix = { 1.0f-2.0f*n.x*n.x, -2.0f*n.x*n.y,      -2.0f*n.x*n.z,      0.0f,
                                -2.0f*n.x*n.y,       1.0f-2.0f*n.y*n.y, -2.0f*n.y*n.z,      0.0f,
                                -2.0f*n.x*n.z,      -2.0f*n.y*n.z,       1.0f-2.0f*n.z*n.z, 0.0f,
                                 MirrorPos.x,        MirrorPos.y,        MirrorPos.z,       1.0f};
float4 TransMirrorPos( float4 Pos ){
    Pos = float4(Pos.xyz - MirrorPos, 1.0f);
    Pos = mul( Pos, MirrorMatrix ); // 鏡像変換
    return Pos;
}

// ワールド変換行列限定で、逆行列を計算する。
// - 行列が、等倍スケーリング、回転、平行移動しか含まないことを前提条件とする。
float4x4 InverseWorldMatrix(float4x4 mat) {
    float scaling = length(mat._11_12_13);
    float scaling_inv = 1.0 / (scaling * scaling);

    float3x3 mat3x3_inv = transpose((float3x3)mat) * scaling_inv;
    return float4x4( mat3x3_inv[0], 0, 
                     mat3x3_inv[1], 0, 
                     mat3x3_inv[2], 0, 
                     -mul(mat._41_42_43, mat3x3_inv), 1 );
}

// 鏡面座標変換パラメータ
float4x4 MirrorWorldMatrix: CONTROLOBJECT < string Name = "(OffscreenOwner)"; >; // 鏡面アクセのワールド変換行列
static float4x4 InvMirrorWorldMatrix = InverseWorldMatrix(MirrorWorldMatrix);    // 鏡面アクセのワールド変換逆行列

// Obj座標変換行列		//（修正箇所）鏡像の視野を二倍にする為ProjMatrixを修正し、そこからViewProjMatrix、WorldViewProjMatrixを計算。
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 DefaultProjMatrix        : PROJECTION;

static float4x4 ProjMatrix  =  {{DefaultProjMatrix._11 * 0.5, 0, 0, 0},
								{0, DefaultProjMatrix._22 * 0.5, 0, 0},
								{0, 0, DefaultProjMatrix._33, 1.0f},
								{0, 0, DefaultProjMatrix._43, 0}};

static float4x4 ViewProjMatrix = mul(ViewMatrix, ProjMatrix);
static float4x4 WorldViewProjMatrix = mul(WorldMatrix, ViewProjMatrix);

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
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = MaterialAmbient  * LightAmbient + MaterialEmmisive;
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

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

struct VS_OUTPUT0 {
    float4 Pos        : POSITION;    // 射影変換座標
    float4 VPos       : TEXCOORD1;   // 鏡像モデルのワールド座標
    float4 WPos		  : TEXCOORD2;
    float4 VCamera    : TEXCOORD3;   // カメラと鏡面の相対座標
};

// 鏡像エッジ頂点シェーダ
VS_OUTPUT0 MirrorEdge_VS(float4 Pos : POSITION)
{
    VS_OUTPUT0 Out = (VS_OUTPUT0)0;

    // ワールド座標変換
    Pos = mul( Pos, WorldMatrix );
	Out.WPos = Pos;

    // 鏡像位置への座標変換
    Pos = mul( Pos, InvMirrorWorldMatrix );
    Pos = TransMirrorPos( Pos ); // 鏡像変換
    Out.VPos = Pos;
    Pos = mul( Pos, MirrorWorldMatrix );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Pos.x *= -1.0f; // ポリゴンが裏返らないように左右反転にして描画

    // カメラの鏡面に対する相対座標
    Out.VCamera = mul( float4(CameraPosition, 1.0f), InvMirrorWorldMatrix );

    return Out;
}

// ピクセルシェーダ
float4 Edge_PS(VS_OUTPUT0 IN) : COLOR
{
    // 輪郭色で塗りつぶし
    float4 Color = EdgeColor;

    // 鏡面の裏側にある部位は鏡像表示しない
    if(dot((float3)IN.VPos-MirrorPos, MirrorNormal)*dot((float3)IN.VCamera-MirrorPos, MirrorNormal) >= 0.0f) Color.a = 0.0f;

    float3 Eye = CameraPosition - IN.WPos.xyz;
    return float4(length(Eye),0,0,Color.a);
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawMirrorEdge {
        AlphaBlendEnable = TRUE;
        AlphaTestEnable  = TRUE;
        SrcBlend = SRCALPHA;
        DestBlend = INVSRCALPHA;
        VertexShader = compile vs_2_0 MirrorEdge_VS();
        PixelShader  = compile ps_2_0 Edge_PS();
    }
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex      : TEXCOORD4;   // スフィアマップテクスチャ座標
    float4 VPos       : TEXCOORD5;   // 鏡像モデルのワールド座標
    float4 VCamera    : TEXCOORD6;   // カメラと鏡面の相対座標
    float4 WPos		  : TEXCOORD7;
    float4 Color      : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // ワールド座標変換
    Pos = mul( Pos, WorldMatrix );
	Out.WPos = Pos;

    // カメラとの相対位置(光源も鏡像化されていることを考慮)
    Out.Eye = CameraPosition - Pos;
    // 鏡像位置への座標変換
    Pos = mul( Pos, InvMirrorWorldMatrix );
    Pos = TransMirrorPos( Pos ); // 鏡像変換
    Out.VPos = Pos;
    Pos = mul( Pos, MirrorWorldMatrix );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Pos.x *= -1.0f; // ポリゴンが裏返らないように左右反転にして描画

    // カメラの鏡面に対する相対座標
    Out.VCamera = mul( float4(CameraPosition, 1.0f), InvMirrorWorldMatrix );

    // 頂点法線(光源も鏡像化されていることを考慮)
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
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;

    float4 Color = IN.Color;
    if ( useTexture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }

    // 鏡面の裏側にある部位は鏡像表示しない
    if(dot((float3)IN.VPos-MirrorPos, MirrorNormal)*dot((float3)IN.VCamera-MirrorPos, MirrorNormal) >= 0.0f) Color.a = 0.0f;


    float3 Eye = CameraPosition - IN.WPos.xyz;
    return float4(length(Eye),0,0,Color.a);
}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {}

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
