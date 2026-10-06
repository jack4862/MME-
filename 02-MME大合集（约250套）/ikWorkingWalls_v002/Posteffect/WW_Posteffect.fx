//-----------------------------------------------------------------------------
// WorkingWallのワーク描画用。できるだけ最後に描画するようにする。
// 少なくとも、ikBokeh, ALよりは後ろに配置する。
//-----------------------------------------------------------------------------

#include "WW_Settings.fxsub"

//-----------------------------------------------------------------------------

// レンダリングターゲットのクリア値
const float4 BackColor = float4(0,0,0,0);
#define BUFF_COLOR  { 0, 0, 0, 1 }
const float4 DofClearColor = float4(1,0,0,0);
const float4 ALClearColor = float4(0,0,0,1);
const float ClearDepth = 1.0;


float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

//テクスチャフォーマット
#if HDR_RENDER==0
	#define AL_TEXFORMAT "A8R8G8B8"
#else
	//#define AL_TEXFORMAT "A32B32G32R32F"
	#define AL_TEXFORMAT "A16B16G16R16F"
#endif

#if HALF_DRAW==0
	#define TEXSIZE1  1
#else
	#define TEXSIZE1  0.5
#endif

// 鏡面
shared texture WorkingWallRT : OFFSCREENRENDERTARGET <
	string Description = "OffScreen RenderTarget for ikWorkingWalls.fx";
	float2 ViewPortRatio = {TEXSIZE1, TEXSIZE1};
	float4 ClearColor = BUFF_COLOR;
	float ClearDepth = 1.0;
	bool AntiAlias = false;
	string Format = AL_TEXFORMAT;
	string DefaultEffect = 
		"ikWorkingWalls.x = WW_Wall.fx;"
		CONTROLLER_NAME " = hide;"
		"*.x = WW_Object_noCheck.fx;"
		"* = WW_Object.fx;"
	;
>;

#if ENABLE_DOF > 0
shared texture WW_DepthMapRT: RENDERCOLORTARGET <
	float2 ViewPortRatio = {TEXSIZE1, TEXSIZE1};
	string Format = "R16F"; // 深度だけでなく速度なども出力する?
	int Miplevels = 1;
>;
#endif

#if ENABLE_AL > 0
shared texture WW_EmissiveMapRT: RENDERCOLORTARGET <
	float2 ViewPortRatio = {TEXSIZE1, TEXSIZE1};
	string Format = "A16B16G16R16F";
	int Miplevels = 1;
>;
#endif

technique WorkingWallPosteffect <
	string Script =
		"ClearSetColor=BackColor;"
		"ClearSetDepth=ClearDepth;"

		"RenderDepthStencilTarget=;"
		"Clear=Color; Clear=Depth;"
		"ScriptExternal=Color;"

		// バッファの初期化
		#if ENABLE_DOF > 0
		"RenderColorTarget0=WW_DepthMapRT;"
		"ClearSetColor=DofClearColor; Clear=Color;"
		#endif
		#if ENABLE_AL > 0
		"RenderColorTarget0=WW_EmissiveMapRT;"
		"ClearSetColor=ALClearColor; Clear=Color;"
		#endif
		#if ENABLE_DOF > 0 || ENABLE_AL > 0
		"RenderColorTarget0=;"
		#endif
	;> {}

//-----------------------------------------------------------------------------
