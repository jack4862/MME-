//static const float transparent_factor = 0;	////透明度の係数　0～1
//static const float transparent_level = 0.0;  //透明度をかさ上げ　0～1（通常0）
//static const float transparent_reverse = 0.0; //法線に従って色が濃くなる範囲の指定　-1～1(通常0)　メッシュ形状に合わせて都合が良い値にする

//static const float specular_boost_factor = 0.0; //スペキュラをかさ上げする係数　0～1　見た目の透明度は下がる
//static const float reflection_boost_factor = 0.0; //反射をかさ上げする係数　0～1 見た目の透明度は下がる
//static const float revese_surface_factor =  0.0;

//独自パラメータ設定　ここから
 const float transparent_factor = 0.4;	//透明度の係数　0～1
 const float transparent_level = 0.0;  //透明度をかさ上げする係数　0～1（通常0）
 const float transparent_reverse = 0.0; //法線に従って色が濃くなる範囲の指定
 const float specular_boost_factor = 0.0; //スペキュラをかさ上げする係数　0～1　見た目の透明度は下がる
 const float reflection_boost_factor = 1.0; //反射をかさ上げする係数　0～1 見た目の透明度は下がる
 const float revese_surface_factor = 0.0; //裏面の影響度　0～1　横も色が濃くなります。　チラつく時は0にして切る
//ここまで

#define ALBEDO_MAP_FROM 0
#define ALBEDO_MAP_UV_FLIP 0
#define ALBEDO_MAP_APPLY_SCALE 1
#define ALBEDO_MAP_APPLY_DIFFUSE 0
#define ALBEDO_MAP_APPLY_MORPH_COLOR 0
#define ALBEDO_MAP_FILE "albedo.png"


#define CONTROLLER_NAME "color_controller_3.pmx"

float mR : CONTROLOBJECT<string name=CONTROLLER_NAME; string item = "crystal05R+";>;
float mG : CONTROLOBJECT<string name=CONTROLLER_NAME; string item = "crystal05G+";>;
float mB : CONTROLOBJECT<string name=CONTROLLER_NAME; string item = "crystal05B+";>;
float mV : CONTROLOBJECT<string name=CONTROLLER_NAME; string item = "crystal05V-";>;

static const float3 albedo = float3(0.5*mR, 0.5*mG, 0.5*mB) * (0.5-mV);
static const float2 albedoMapLoopNum = 1.0;

#define ALBEDO_SUB_ENABLE 0
#define ALBEDO_SUB_MAP_FROM 0
#define ALBEDO_SUB_MAP_UV_FLIP 0
#define ALBEDO_SUB_MAP_APPLY_SCALE 0
#define ALBEDO_SUB_MAP_FILE "albedo.png"

static const float3 albedoSub = 1.0;
static const float2 albedoSubMapLoopNum = 1.0;

#define ALPHA_MAP_FROM 0
#define ALPHA_MAP_UV_FLIP 0
#define ALPHA_MAP_SWIZZLE 3
#define ALPHA_MAP_FILE "alpha.png"

static const float alpha = 0.1;
const float alphaMapLoopNum = 1.0;

#define NORMAL_MAP_FROM 0
#define NORMAL_MAP_TYPE 0
#define NORMAL_MAP_UV_FLIP 0
#define NORMAL_MAP_FILE "normal.png"

static const float normalMapScale = 1.0;
static const float normalMapLoopNum = 1.0;

#define NORMAL_SUB_MAP_FROM 0
#define NORMAL_SUB_MAP_TYPE 0
#define NORMAL_SUB_MAP_UV_FLIP 0
#define NORMAL_SUB_MAP_FILE "normal.png"

static const float normalSubMapScale = 1.0;
static const float normalSubMapLoopNum = 1.0;

#define SMOOTHNESS_MAP_FROM 0
#define SMOOTHNESS_MAP_TYPE 0
#define SMOOTHNESS_MAP_UV_FLIP 0
#define SMOOTHNESS_MAP_SWIZZLE 0
#define SMOOTHNESS_MAP_APPLY_SCALE 0
#define SMOOTHNESS_MAP_FILE "smoothness.png"

static const float smoothness = 0.8; 
static const float smoothnessMapLoopNum = 1.0;

#define METALNESS_MAP_FROM 0
#define METALNESS_MAP_UV_FLIP 0
#define METALNESS_MAP_SWIZZLE 0
#define METALNESS_MAP_APPLY_SCALE 0
#define METALNESS_MAP_FILE "metalness.png"

static const float metalness = 0.0;
static const float metalnessMapLoopNum = 1.0;

#define SPECULAR_MAP_FROM 0
#define SPECULAR_MAP_TYPE 0
#define SPECULAR_MAP_UV_FLIP 0
#define SPECULAR_MAP_SWIZZLE 0
#define SPECULAR_MAP_APPLY_SCALE 0
#define SPECULAR_MAP_FILE "specular.png"

static const float3 specular = 0.5;
static const float2 specularMapLoopNum = 1.0;

#define OCCLUSION_MAP_FROM 0
#define OCCLUSION_MAP_TYPE 0
#define OCCLUSION_MAP_UV_FLIP 0
#define OCCLUSION_MAP_SWIZZLE 0
#define OCCLUSION_MAP_APPLY_SCALE 0 
#define OCCLUSION_MAP_FILE "occlusion.png"

const float occlusion = 1.0;
const float occlusionMapLoopNum = 1.0;

#define PARALLAX_MAP_FROM 0
#define PARALLAX_MAP_TYPE 0
#define PARALLAX_MAP_UV_FLIP 0
#define PARALLAX_MAP_SWIZZLE 0
#define PARALLAX_MAP_FILE "height.png"

const float parallaxMapScale = 1.0;
const float parallaxMapLoopNum = 1.0;

#define EMISSIVE_ENABLE 0
#define EMISSIVE_MAP_FROM 0
#define EMISSIVE_MAP_UV_FLIP 0
#define EMISSIVE_MAP_APPLY_SCALE 0
#define EMISSIVE_MAP_APPLY_MORPH_COLOR 0
#define EMISSIVE_MAP_APPLY_MORPH_INTENSITY 0
#define EMISSIVE_MAP_APPLY_BLINK 0
#define EMISSIVE_MAP_FILE "emissive.png"

static const float3 emissive = 1.0;
static const float emissiveBlink = 1.0; 
static const float emissiveIntensity = 1.0;
static const float emissiveMapLoopNum = 1.0;

#define CUSTOM_ENABLE 4

#define CUSTOM_A_MAP_FROM 0
#define CUSTOM_A_MAP_UV_FLIP 0
#define CUSTOM_A_MAP_COLOR_FLIP 0
#define CUSTOM_A_MAP_SWIZZLE 0
#define CUSTOM_A_MAP_APPLY_SCALE 0
#define CUSTOM_A_MAP_FILE "custom.png"

static const float customA = 0.0;
static const float customAMapLoopNum = 1.0;

#define CUSTOM_B_MAP_FROM 0
#define CUSTOM_B_MAP_UV_FLIP 0
#define CUSTOM_B_MAP_COLOR_FLIP 0
#define CUSTOM_B_MAP_APPLY_SCALE 0
#define CUSTOM_B_MAP_FILE "custom.png"

static const float3 customB = 0.0;
static const float2 customBMapLoopNum = 1.0;

#include "../material_crystal_mono.fxsub"