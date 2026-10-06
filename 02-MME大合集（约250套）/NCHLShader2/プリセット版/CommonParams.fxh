// このファイルは自動更新の対象にならないので変更後は「全て更新」か、個別にシェーダfxファイルの上書き保存を。
// 基本的にはあまり弄らなくてOK

// 空の色
#define SKYCOLOR float3(0.55,0.59,0.68)
//　地面の色
#define GROUNDCOLOR float3(0.63,0.52,0.35)
// 空の向き
#define SKYDIR float3(0.0,1.0,0.0)

//////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "standard";
> = 0.8;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 WorldMatrixInverse       : WORLDINVERSE;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

// ライトとカメラの方向
float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraDirection   : DIRECTION  < string Object = "Camera"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
uniform float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
uniform float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
uniform float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
uniform float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
uniform float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
uniform float4   MaterialToon      : TOONCOLOR;

// ライト色
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
static float4 DiffuseColor  = float4(MaterialDiffuse.rgb*LightAmbient, saturate(MaterialDiffuse.a+0.01));

// 環境光関連
float  AmbLightPower       : CONTROLOBJECT < string name = "AmbientController.x"; string item="Si"; >;
float3 AmbColorXYZ         : CONTROLOBJECT < string name = "AmbientController.x"; string item="XYZ"; >;
float3 AmbColorRxyz        : CONTROLOBJECT < string name = "AmbientController.x"; string item="Rxyz"; >;
static float3 AmbientColor  = MaterialToon*MaterialEmmisive;
static float3 AmbLightColor0 = saturate(AmbColorXYZ*0.01); 
static float3 AmbLightColor1 = saturate(AmbColorRxyz*1.8/3.141592); 

// バックライト関連
float3 BackLightPower   : CONTROLOBJECT < string name = "BackLightController.x"; string item="Si"; >;
float3 BackLightXYZ     : CONTROLOBJECT < string name = "BackLightController.x"; string item="XYZ"; >;
static float3 BackLightColor = saturate(BackLightXYZ*0.01); 

// ExcellentShadow関連
//bool Exist_ExcellentShadow : CONTROLOBJECT < string name = "ExcellentShadow.x"; >;
float3   ES_CameraPos1      : POSITION  < string Object = "Camera"; >;
float4x4 es_mat1 : CONTROLOBJECT < string name = "ExcellentShadow.x"; >;
static float3 es_move1 = float3(es_mat1._41, es_mat1._42, es_mat1._43 );
static float CameraDistance1 = length(ES_CameraPos1 - es_move1); //カメラとシャドウ中心の距離
float ShadowStrength : CONTROLOBJECT < string name = "ExcellentShadow.x"; string item="Tr"; >;

bool    parthf;        // パースペクティブフラグ
bool    transp;        // 半透明フラグ

#define SKII1    1500
#define SKII2    8000
#define Toon     3