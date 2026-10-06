
//頂点変換システムの読み込み
#include "MatrixMaker.h"

// 映り込み距離の最大・最小
#define Z_MAX 65535.0
#define Z_MIN 0.1

// パラメータ宣言

//環境マップの中心座標
float3 CameraPosition : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "センター"; >;

//ループ変数
int LoopCount = 4;
int LoopIndex = 0;

// 座法変換行列

float4x4 WorldMatrix : WORLD;
float4x4 ProjMatrix = float4x4(float4(0.40824829,0,0,0),
	                           float4(0,0.353553391,0,0),
	                           float4(0,0,Z_MAX/(Z_MAX-Z_MIN),1),
	                           float4(0,0,-Z_MIN*Z_MAX/(Z_MAX-Z_MIN),0));

static float4x4 ViewMatrix = ViewMatrixMaker( CameraPosition, LoopIndex );
static float4x4 WorldViewProjMatrix = WVPMatrixMaker( WorldMatrix,ProjMatrix,CameraPosition, LoopIndex);

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
bool	use_texture;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画

technique EdgeTec < string MMDPass = "edge"; > {}

///////////////////////////////////////////////////////////////////////////////////////////////

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float4 WPos		  : TEXCOORD4;   // ワールド座標
    float4 Color	  : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	
	//カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    // カメラとの相対位置
    Out.Eye = CameraPosition - (float3)mul( Pos, WorldMatrix );
    
    Out.WPos = mul( Pos, WorldMatrix );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = MaterialAmbient;
    Out.Color.a = MaterialDiffuse.a;
    Out.Color = saturate( Out.Color );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN) : COLOR0
{
	//四面体環境マッピング用に切り取る
	clip(ClipByDir(IN.Eye,LoopIndex));

	//Z値だけで良いけど、今度色付き光やりたい。。。！
    float4 Color = IN.Color;
    if ( use_texture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }
    
    Color.rgb = length(IN.WPos - CameraPosition);
    Color.a = Color.a > 0.5;
	
    return Color;
}

// オブジェクト描画用テクニック
technique MainTec0  <
	string MMDPass = "object";
	string Script =
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        //4回繰り返す
        	"LoopByCount=LoopCount;"
	        "LoopGetIndex=LoopIndex;"
	        "Pass=DrawObject;"
	        "LoopEnd=;"
	;
> {
    pass DrawObject {
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Basic_VS();
        PixelShader  = compile ps_3_0 Basic_PS();
    }
}
technique MainTec0_ss  <
	string MMDPass = "object_ss";
	string Script =
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        //4回繰り返す
        	"LoopByCount=LoopCount;"
	        "LoopGetIndex=LoopIndex;"
	        "Pass=DrawObject;"
	        "LoopEnd=;"
	;
> {
    pass DrawObject {
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Basic_VS();
        PixelShader  = compile ps_3_0 Basic_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット
technique ZplotTec < string MMDPass = "zplot"; > {}
