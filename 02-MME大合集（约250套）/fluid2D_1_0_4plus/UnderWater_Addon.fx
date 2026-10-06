#define F2DC "fluid2DController.pmx"
#include "sub/LightMatrix.fxsub"

float mOuterScale : CONTROLOBJECT < string name = F2DC; string item = "外周広さ"; >;
float mWaveScale : CONTROLOBJECT < string name = F2DC; string item = "生成波強さ"; >;
float mWaveSpd : CONTROLOBJECT < string name = F2DC; string item = "生成波速度"; >;
float mSeaPower : CONTROLOBJECT < string name = F2DC; string item = "さざ波強さ"; >;
float mSeaScale : CONTROLOBJECT < string name = F2DC; string item = "さざ波細かさ"; >;
float mWaveHeight : CONTROLOBJECT < string name = F2DC; string item = "波高さ"; >;
float mWaterMoveXp : CONTROLOBJECT < string name = F2DC; string item = "流れX+"; >;
float mWaterMoveXm : CONTROLOBJECT < string name = F2DC; string item = "流れX-"; >;
float mWaterMoveYp : CONTROLOBJECT < string name = F2DC; string item = "流れY+"; >;
float mWaterMoveYm : CONTROLOBJECT < string name = F2DC; string item = "流れY-"; >;
float mFogScale : CONTROLOBJECT < string name = F2DC; string item = "フォグ距離"; >;
float mFogR : CONTROLOBJECT < string name = F2DC; string item = "フォグR"; >;
float mFogG : CONTROLOBJECT < string name = F2DC; string item = "フォグG"; >;
float mFogB : CONTROLOBJECT < string name = F2DC; string item = "フォグB"; >;
float mCausScale : CONTROLOBJECT < string name = F2DC; string item = "CAd_火線強さ"; >;
float mCausVScale : CONTROLOBJECT < string name = F2DC; string item = "CAd_火線Vol"; >;
float mMirrorScale : CONTROLOBJECT < string name = F2DC; string item = "鏡面強さ"; >;

float time : TIME;
static float2 WaterMove = float2(mWaterMoveXp - mWaterMoveXm,mWaterMoveYp - mWaterMoveYm);
static float OUTERSCALE = 500 * mOuterScale;

static float4 FogCol = float4(mFogR,mFogG,mFogB,1);
float FogStart = 0;
static float FogEnd = 0.1+500*mFogScale;
static float WaterHightScale = mWaveHeight*1;
static float WaveScale = mWaveScale*5;

//計算によるさざ波作成
#define ITER_GEOMETRY 5
#define ITER_FRAGMENT 6
static float SeaScale = mSeaScale*10;
static float SEA_HEIGHT = mSeaPower;
#define SEA_GEOMETRYSCALE 0.1
#define SEA_CHOPPY 4.0
#define SEA_SPEED 0.25
#define SEA_FREQ 0.16 * 1
#define SEA_TIME (1.0 + time * SEA_SPEED)
static const float2x2 octave_m = float2x2(1.6, 1.2, -1.2, 1.6);

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

//水面から提供されるテクスチャ

shared texture SurfaceDepTex : RenderColorTarget;
sampler SurfaceDepSamp = sampler_state
{
	Texture = <SurfaceDepTex>;
    Filter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
};
//水面下、座標用RT
shared texture UnderPos: RENDERCOLORTARGET;
sampler UnderPosView = sampler_state {
    texture = <UnderPos>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//水面下判定保存用
shared texture2D UnderSaveTex : RENDERCOLORTARGET;
sampler2D UnderSaveSamp = sampler_state {
    texture = <UnderSaveTex>;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//水面のデータ保持用テクスチャ
shared texture BufTexBlur : RenderColorTarget;
sampler BufSampBlur = sampler_state
{
	Texture = <BufTexBlur>;
    Filter = LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};
shared texture2D LvUnderPosRT: OFFSCREENRENDERTARGET;
sampler LvUnderPosView = sampler_state {
    texture = <LvUnderPosRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

float Tr : CONTROLOBJECT < string name = "(self)";string item = "Tr";>;
float Si : CONTROLOBJECT < string name = "(self)";string item = "Si";>;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);


// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//レイマーチ結果を保存するテクスチャ
texture2D RayTex : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A16B16G16R16F" ;
>;
sampler2D RaySamp = sampler_state {
    texture = <RayTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture2D RayTexWork : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A16B16G16R16F" ;
>;
sampler2D RaySampWork = sampler_state {
    texture = <RayTexWork>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

//火線をカメラから記録したテクスチャ
shared texture2D CameraCausTex : RENDERCOLORTARGET;
sampler2D CameraCausSamp = sampler_state {
    texture = <CameraCausTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//火線をライトから記録したテクスチャ
shared texture2D LightCausTex : RENDERCOLORTARGET;
sampler2D LightCausSamp = sampler_state {
    texture = <LightCausTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_Main( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

float4x4 ViewProjMatrix      : VIEWPROJECTION;
float3   LightDirection    : DIRECTION < string Object = "Light"; >;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
float4x4	ViewMatrix		: VIEW;
float4x4	InvViewMatrix		: VIEWINVERSE;
float4x4	InvProjMatrix		: PROJECTIONINVERSE;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;
float4x4 WorldMatrix : CONTROLOBJECT < string name = "fluid2D.x"; >;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3 GetPixelPos(float2 tex)
{
	tex = tex * 2 - 1;
	tex.y *= -1;
    float2 sp = tex;

    float4 ndcray = float4(tex.xy,1,1);
    float3 ray = mul(mul(ndcray,InvProjMatrix).xyz,InvViewMatrix);
    return ray;
}

#define STEPCOUNT 200

float3 raymap(float4 pos)
{
	//float dep =  WorldMatrix[3].y - pos.y;
	
	float4 ZCalcTex = mul(pos,InternalLightViewProjMatrix);
	// テクスチャ座標に変換
    ZCalcTex /= ZCalcTex.w;
    float2 TransTexCoord = 0.5 + ZCalcTex.xy * float2(0.5, -0.5);

	float3 d = tex2Dlod(LightCausSamp,float4(TransTexCoord,0,0)).rgb;

	float4 LvTruePos =  mul(tex2Dlod(LvUnderPosView,float4(TransTexCoord,0,0)),InternalLightViewProjMatrix);
	float LightDepth = LvTruePos.z/LvTruePos.w;
	
	// セルフシャドウ
	float comp = 0;
	if(!any( saturate(TransTexCoord) != TransTexCoord ) ) { 
		float mixrate = saturate((length(ZCalcTex.xy) - 0.8) / (1 - 0.8));
		float dist = (ZCalcTex.z-LightDepth);
		    
	    float sdrate = 3000 * size1 - 0.05 * sqrt(size1);
	    comp = 1 - saturate(max(dist, 0.0f) * sdrate);
		//comp = lerp(1, comp, farfade);
		//comp = dist;
	}
	d *= comp;

	
	return d;
	
}
// Get random value.
float hash(float2 p)
{
	float h = dot(p, float2(127.1, 311.7));	
    return frac(sin(h) * 43758.5453123);
}

// Get Noise.
float noise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    
    // u = -2.0f^3 + 3.0f^2
	float2 u = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i + float2(0.0,0.0));
    float b = hash(i + float2(1.0,0.0));
    float c = hash(i + float2(0.0,1.0));
    float d = hash(i + float2(1.0,1.0));
    
    // Interpolate grid parameters with x and y.
    float result = lerp(lerp(a, b, u.x),
                        lerp(c, d, u.x), u.y);
    
    // Normalized to '-1 - 1'.
    return (2.0 * result) - 1.0;
}
float3 RayCaus(float2 Tex,float eyedepth)
{
	float3 c = 0;
	//始点
	float3 ray = CameraPosition;
	float3 dir = normalize(GetPixelPos(Tex));
	ray += dir*noise(Tex*12.345)*0.1;
	int i;
	[loop]
	for(i=0;i<STEPCOUNT;i++)
	{
		ray += dir * (FogEnd/STEPCOUNT);
		c += raymap(float4(ray,1))*10;
		[branch]
		if(ray.y > WorldMatrix[3].y || eyedepth < i*(FogEnd/STEPCOUNT))
		{
			break;
		}
	}
	
	
	
	return c;
}
float4 PS_Ray(float2 Tex: TEXCOORD0) : COLOR
{
	float eyedep = length(tex2D(UnderPosView,Tex).rgb - CameraPosition);

	//レイマーチ火線
	float3 ray_caus = RayCaus(Tex,eyedep)*0.01*(mCausVScale*4);
	return float4(ray_caus,1);
}
shared texture UnderDataRT: OFFSCREENRENDERTARGET;
sampler UnderNormalView = sampler_state {
    texture = <UnderDataRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
float4 PS_Main(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color = tex2D( ScnSamp,Tex);
	float4 BaseColor = Color;
	
	float eyedep = length(tex2D(UnderPosView,Tex).rgb - CameraPosition);
	float surfdep = tex2D(SurfaceDepSamp,Tex).r;
	surfdep += (surfdep == 0)*0xFFFF;
	float dep = min(eyedep,surfdep);
	
	//return float4(tex2D(UnderPosView,Tex).rgb,1);
	
	Color.rgb = lerp(Color.rgb,FogCol,smoothstep(FogStart,FogEnd,dep));
	float3 caus = tex2D(CameraCausSamp,Tex).rgb * 4 * LightSpecular;
	Color.rgb += caus*smoothstep(FogEnd,FogStart,dep)*(eyedep<surfdep);
	
	//レイマーチ火線
	//float3 ray_caus = RayCaus(Tex,eyedep)*0.01*(mCausVScale*4);
	float3 ray_caus = tex2D(RaySamp,Tex).rgb*LightSpecular*2;


	Color.rgb += max(-0.1,min(1,ray_caus*1))*1;//*smoothstep(FogEnd,FogStart,dep)*(eyedep<surfdep);
	
	//水面下判定
	float Under = tex2D(UnderSaveSamp,Tex).r;
	Color = lerp(BaseColor ,Color,Under);
	
	//水面下判定差分
	float2 step = ViewportOffset;
	float UL = abs(Under - tex2D(UnderSaveSamp,Tex+float2(step.x,0)).r);
	float UR = abs(Under - tex2D(UnderSaveSamp,Tex+float2(-step.x,0)).r);
	float UU = abs(Under - tex2D(UnderSaveSamp,Tex+float2(0,step.y)).r);
	float UD = abs(Under - tex2D(UnderSaveSamp,Tex+float2(0,-step.y)).r);
	
	float sabun = UL+UR+UU+UD;	
	Color = lerp(BaseColor ,Color,Under);
	Color = lerp(Color,float4(saturate(LightSpecular*2),1),sabun);
	
    return Color;
}
#include "sub/Gaussian.fx"
////////////////////////////////////////////////////////////////////////////////////////////////

technique UnderWater_Addon <
    string Script = 
        "RenderColorTarget0=ScnMap;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "ScriptExternal=Color;"
	    
	    
        "RenderColorTarget0=RayTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=raypass;"
	    
	    "RenderColorTarget0=RayTexWork;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;"	"Clear=Depth;"
	    "Pass=Gaussian_X;"
	    
        "RenderColorTarget0=RayTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;"	"Clear=Depth;"
	    "Pass=Gaussian_Y;"
	    
	    
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=main;"
    ;
> {
    pass raypass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_Ray();
    }
    pass main < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_Main();
    }
    //ガウスブラー
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX(RaySamp,0);
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passY();
        PixelShader  = compile ps_2_0 PS_passY(RaySampWork,0);
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
