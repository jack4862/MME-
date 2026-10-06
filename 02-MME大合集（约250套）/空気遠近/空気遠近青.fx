
// パラメータ操作用オブジェクト
float3 XYZ : CONTROLOBJECT < string name = "(self)"; string item = "XYZ";>;	// 座標
float3 Rxyz : CONTROLOBJECT < string name = "(self)"; string item="Rxyz";>;	// 角度
float Rx : CONTROLOBJECT < string name = "(self)"; string item="Rx";>;
float Ry : CONTROLOBJECT < string name = "(self)"; string item="Ry";>;
float Rz : CONTROLOBJECT < string name = "(self)"; string item="Rz";>;
float Scale : CONTROLOBJECT < string name = "(self)"; string item = "Si";>;	// スケール
//float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr";>;	// 透過度
float3 CameraPosition: POSITION < string Object = "Camera"; >;	// カメラ座標
float3 LightDiffuse		: DIFFUSE	< string Object = "Light"; >;	// 拡散
float3 LightAmbient		: AMBIENT	< string Object = "Light"; >;	// 環境
float3 LightSpecular	: SPECULAR	< string Object = "Light"; >;	// 反射
////////////////////////////////////////////////////////////////////////////////////////////////
// フォグの色
static float4 FogColor=float4(0.9+Rx,1+Ry,1.3+Rz, 1);

// 単色化する(コメントアウトで無効化)
//#define SINGLE_COLOR

////////////////////////////////////////////////////////////////////////////////////////////////
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// 射影行列
float4x4 View	: VIEW;
float4x4 InvView	: VIEWINVERSE;
float4x4 InvProj	: PROJECTIONINVERSE;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

////////////////////////////////////////////////////////////////////////////////////////////////
// レンダリングターゲットのクリア値
float4 ClearColorBlack = {0,0,0,1}, ClearColorWhite = {1,1,1,1};
float ClearDepth  = 1.0;

// レンダーターゲット
// オリジナル
texture2D texOut : RENDERCOLORTARGET
	< float2 ViewportRatio = {1.0, 1.0};	int MipLevels = 1; string Format = "A8R8G8B8"; >;
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET
	< float2 ViewportRatio = {1.0, 1.0};	string Format = "D24S8"; >;
// サンプラー
sampler2D smpOut = sampler_state {
	texture = <texOut>;
	MinFilter = LINEAR; MagFilter=LINEAR; MipFilter = LINEAR;
	AddressU = CLAMP; AddressV = CLAMP;
};
// フォグ濃度
texture texFog: OFFSCREENRENDERTARGET <
	string Description = "FogDensity For Fog.fx";
	float2 ViewportRatio = {1.0, 1.0};
	float4 ClearColor = { 0, 0, 0, 1 };
	float ClearDepth = 1.0;
	string Format = "A8R8G8B8" ;
	bool AntiAlias = true;
	string DefaultEffect = 
		"self = hide;"
		"* = FogOffScreen.fx";
>;
// サンプラー
sampler2D smpFog = sampler_state {
    texture = <texFog>;
    MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR;
    AddressU  = CLAMP; AddressV = CLAMP;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// フォグ
// 頂点出力
struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};
VS_OUTPUT VS_Fog( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    return Out;
}
float4  PS_Fog( VS_OUTPUT In ) : COLOR{   
	float4 Color = tex2D(smpOut,In.Tex);
#ifdef SINGLE_COLOR
	Color.rgb = FogColor.rgb*tex2D(smpFog, In.Tex).r*Scale*0.1;
#else
	Color.rgb = lerp(Color.rgb, FogColor.rgb, tex2D(smpFog, In.Tex).r*Scale*0.1);
#endif
	//return float4((float3)tex2D(smpFog, In.Tex).r, 1);
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique FOG<
    string Script = 
		// オリジナル画像出力
		"RenderColorTarget0=texOut; RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColorWhite; ClearSetDepth=ClearDepth; Clear=Color; Clear=Depth;"
			"ScriptExternal=Color;"
		// 画面に出力
		"RenderColorTarget0=; RenderDepthStencilTarget=;"
		"Clear=Color; Clear=Depth;"
			"Pass=Fog;"
    ;
> {
	pass Fog < string Script= "Draw=Buffer;"; >
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_Fog();
		PixelShader  = compile ps_2_0 PS_Fog();
	}
}