#define F2DC "fluid2DController.pmx"

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
#define ITER_GEOMETRY 6
static float SeaScale = mSeaScale*10;
#define SEA_GEOMETRYSCALE 0.1
#define SEA_CHOPPY 4.0
#define SEA_SPEED 0.25
static float SEA_HEIGHT = mSeaPower*4;
#define SEA_FREQ 0.16 * 1
#define SEA_TIME (1.0 + time * SEA_SPEED)
static const float2x2 octave_m = float2x2(1.6, 1.2, -1.2, 1.6);

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

//水面から提供されるテクスチャ

//水面下、法線用RT
shared texture2D UnderNormal: RENDERCOLORTARGET;
sampler UnderNormalView = sampler_state {
    texture = <UnderNormal>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
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
//水面のデータ保持用テクスチャ
shared texture BufTexBlur : RenderColorTarget;
sampler BufSampBlur = sampler_state
{
	Texture = <BufTexBlur>;
    Filter = LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

#define LIGHTCAUSDATATEXSIZE 1024
#define LIGHTCAUSTEXSIZE 1024

//水面下、座標用RT
texture2D LvUnderPosRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Caustics_Addon";
    
   int Width=LIGHTCAUSDATATEXSIZE;
   int Height=LIGHTCAUSDATATEXSIZE;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    string Format = "A16B16G16R16F" ;
    bool AntiAlias = true;
    
    string DefaultEffect = 
        "self = hide;"
        "fluid2D.x = hide;"
        "*=sub/LvPos.fx;";
>;
sampler LvUnderPosView = sampler_state {
    texture = <LvUnderPosRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//水面本来の座標描画用
texture LvUnderPosOriginRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for Caustics_Addon";
    
   int Width=256;
   int Height=256;
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    string Format = "A16B16G16R16F" ;
    bool AntiAlias = true;
    
    string DefaultEffect = 
        "self = hide;"
        "fluid2D.x = sub/LvPosOrigin.fx;"
        "*=hide;";
>;
sampler LvUnderPosOriginView = sampler_state {
    texture = <LvUnderPosOriginRT>;
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

//火線をカメラから記録したテクスチャ
shared texture2D CameraCausTex : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "A16B16G16R16F" ;
    float4 ClearColor = { 0, 0, 0, 0 };
    bool AntiAlias = true;
>;
sampler2D CameraCausSamp = sampler_state {
    texture = <CameraCausTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;
//法線をライトから記録したテクスチャ
texture2D LightNormalTex : RENDERCOLORTARGET <
   int Width=LIGHTCAUSTEXSIZE;
   int Height=LIGHTCAUSTEXSIZE;
    bool AntiAlias = true;
    string Format = "A16B16G16R16F" ;
>;
sampler2D LightNormalSamp = sampler_state {
    texture = <LightNormalTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//火線をライトから記録したテクスチャ
texture2D LightCausTexWork : RENDERCOLORTARGET <
   int Width=LIGHTCAUSTEXSIZE;
   int Height=LIGHTCAUSTEXSIZE;
    bool AntiAlias = true;
    float4 ClearColor = { 0, 0, 0, 0 };
    string Format = "A16B16G16R16F" ;
>;
sampler2D LightCausWorkSamp = sampler_state {
    texture = <LightCausTexWork>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
shared texture2D LightCausTex : RENDERCOLORTARGET <
   int Width=LIGHTCAUSTEXSIZE;
   int Height=LIGHTCAUSTEXSIZE;
    bool AntiAlias = true;
    float4 ClearColor = { 0, 0, 0, 0 };
    string Format = "A16B16G16R16F" ;
>;
sampler2D LightCausSamp = sampler_state {
    texture = <LightCausTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D LightCausDepth : RENDERDEPTHSTENCILTARGET <
	int Width=LIGHTCAUSTEXSIZE;
	int Height=LIGHTCAUSTEXSIZE;
    bool AntiAlias = true;
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

//float4x4 LighViewProjMatrix : VIEWPROJECTION < string Object = "Light"; >;
#include "sub/LightMatrix.fxsub"

float3 GetPixelPos(float2 tex)
{
	tex = tex * 2 - 1;
	tex.y *= -1;
    float2 sp = tex;

    float4 ndcray = float4(tex.xy,1,1);
    float3 ray = mul(mul(ndcray,InvProjMatrix).xyz,InvViewMatrix);
    return ray;
}

#define TEX_SIZE 1024

// Get random value.
float hash(float2 p)
{
	float h = dot(p, float2(127.1, 311.7));	
    return frac(sin(h) * 43758.5453123);
}

// Get Noise.
float noise2D(float2 p)
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
float4x4 inverseDir(float4x4 mat){
    return float4x4(
        mat._11, mat._21, mat._31, 0,
        mat._12, mat._22, mat._32, 0,
        mat._13, mat._23, mat._33, 0,
        0,0,0,1
    );
}

float4x4 inverse(float4x4 mat){
    float4x4 mv={
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        -mat._41, -mat._42, -mat._43, 1
    };

    return mul(mv,inverseDir(mat));
}

#include "sub/WaterNormal.fxsub"

float3 CalcNorm(float3 pos)
{
	float2 watertex = mul(float4(pos.xyz,1),inverse(WorldMatrix)).xz/length(WorldMatrix[1])/length(WorldMatrix[1]);
	watertex += float2(0.5,-0.5);
	watertex.y *= -1;
	
	
	float2 BGTex = watertex - 0.5;
	
	float3 	Normal = GetWaveNormal(BGTex*0.075+WaterMove*time*0.01, mul(float3(0,1,0),WorldMatrix), normalize(pos - CameraPosition), pos,9);
	Normal.g = 1;
	Normal.rb *= 100;

	[branch]
	if(watertex.x > 0 && watertex.x < 1 && watertex.y > 0 && watertex.y < 1)
	{
		float3 WaveNormal = normalize(tex2Dlod(BufSampBlur,float4(watertex,0,0)).xyz);
		Normal.rb += WaveNormal.rb*0.1;
	}
	Normal = normalize(Normal);
	
	return Normal;
	/*
	float2 watertex = mul(float4(pos.xyz,1),inverse(WorldMatrix)).xz/length(WorldMatrix[1])/length(WorldMatrix[1]);
	watertex += float2(0.5,-0.5);
	watertex.y *= -1;
	
	
	float2 BGTex = watertex - 0.5;
	
	//----法線計算
	float HeightHx = (CALCMAP(1, 0) - CALCMAP( -1 ,0)) * 3.0;
	float HeightHy = (CALCMAP( 0,1) - CALCMAP( 0 ,-1)) * 3.0;

	float3 AxisU = { 1.0, HeightHx, 0.0 };
	float3 AxisV = { 0.0, HeightHy, 1.0 };

	float3 Normal = (normalize( cross( AxisU, AxisV ) ) ) + 0.5;
	Normal.rb = (Normal.rb * 2.0 - 1.0)*100;
	
	[branch]
	if(watertex.x > 0 && watertex.x < 1 && watertex.y > 0 && watertex.y < 1)
	{
		float3 WaveNormal = normalize(tex2Dlod(BufSampBlur,float4(watertex,0,0)).xyz);
		Normal.rb += WaveNormal.rb*0.05;
	}
	Normal.g = 1;
	
	return Normal;
	*/
}

float CausCalc(float2 tex,float3 pos,float dep,float crom)
{
	//本来の法線
	float3 Normal = tex2Dlod(LightNormalSamp,float4(tex,0,0));//CalcNorm(pos);

	//法線分ずらす
	//pos.xz += Normal.xz*min(20,dep)*1*crom*(mCausScale*2);

	float3 NextNormal = tex2Dlod(LightNormalSamp,float4(tex+Normal.xz*min(20,dep)*0.005*crom*(mCausScale*1),0,0));//CalcNorm(pos);

	float d = dot(NextNormal,-LightDirection);

	float up_d = dot(Normal,-LightDirection);

	float len = max(-0.025,pow((up_d - d)*5,3))*(mCausScale*2);

	return len;
}

#define SKII1    1500
#define SKII2    8000

float4 PS_CameraCaus(float2 Tex: TEXCOORD0) : COLOR
{
	float4 LastColor = 0;
	float4 pos = tex2D(UnderPosView,Tex);
	float4 ZCalcTex = mul(pos,InternalLightViewProjMatrix);
	// テクスチャ座標に変換
    ZCalcTex /= ZCalcTex.w;
    float2 TransTexCoord = 0.5 + ZCalcTex.xy * float2(0.5, -0.5);

	float3 d = tex2D(LightCausSamp,TransTexCoord).rgb;

	float4 LvTruePos =  mul(tex2D(LvUnderPosView,TransTexCoord),InternalLightViewProjMatrix);
	float LightDepth = LvTruePos.z/LvTruePos.w;
	
	// セルフシャドウ
	float comp = 0;
	if(!any( saturate(TransTexCoord) != TransTexCoord ) ) { 
		float mixrate = saturate((length(ZCalcTex.xy) - 0.8) / (1 - 0.8));
		float dist = (ZCalcTex.z-LightDepth);
		    
	    float sdrate = 30000 * size1 - 0.05 * sqrt(size1);
	    comp = 1 - saturate(max(dist, 0.0f) * sdrate);
		//comp = lerp(1, comp, farfade);
		//comp = dist;
	}
	d *= comp;
	LastColor.rgb = d;
	LastColor.a = 1;
	return LastColor;
}
float4 PS_LightNormal(float2 Tex: TEXCOORD0) : COLOR
{
	float4 pos = tex2D(LvUnderPosView,Tex);
	float dep =  WorldMatrix[3].y - pos.y;
	pos = tex2D(LvUnderPosOriginView,Tex);
	
	return float4(CalcNorm(pos),1);
}
float4 PS_LightCaus(float2 Tex: TEXCOORD0,uniform int mode,uniform float crom) : COLOR
{
	float4 LastColor = 0;	
	float4 pos = tex2D(LvUnderPosView,Tex);
	float dep =  WorldMatrix[3].y - pos.y;
	pos = tex2D(LvUnderPosOriginView,Tex);
	
	
	float d = CausCalc(Tex,pos,dep,crom);
	//d *= 2;
	if(mode == 0)
	{
		LastColor.r = d;
	}else if(mode == 1)
	{
		LastColor.g = d;
	}else{
		LastColor.b = d;
	}
	LastColor.a = 1;
	return LastColor;
}

float4 PS_LightCausTest(float2 Tex: TEXCOORD0) : COLOR
{	
	float4 c = tex2D(LightCausSamp,Tex);
	return c;
}
#include "sub/Gaussian.fx"
////////////////////////////////////////////////////////////////////////////////////////////////
// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1;

technique Caustics <
    string Script = 
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		
        "RenderColorTarget0=LightNormalTex;"
	    "RenderDepthStencilTarget=LightCausDepth;"
		"Clear=Color;"	"Clear=Depth;"
	    "Pass=LightNormalPass;"
	    
        "RenderColorTarget0=LightCausTex;"
	    "RenderDepthStencilTarget=LightCausDepth;"
		"Clear=Color;"	"Clear=Depth;"
	    "Pass=LightCausPassR;"
	    "Pass=LightCausPassG;"
	    "Pass=LightCausPassB;"
	    
        "RenderColorTarget0=LightCausTexWork;"
	    "RenderDepthStencilTarget=LightCausDepth;"
		"Clear=Color;"	"Clear=Depth;"
	    "Pass=Gaussian_X;"
	    
        "RenderColorTarget0=LightCausTex;"
	    "RenderDepthStencilTarget=LightCausDepth;"
		"Clear=Color;"	"Clear=Depth;"
	    "Pass=Gaussian_Y;"
	    
        "RenderColorTarget0=CameraCausTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;"	"Clear=Depth;"
	    "Pass=CameraCausPass;"
	    
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "ScriptExternal=Color;"
	    //"Pass=LightNormalPass;"
	    //"Pass=LightCausTestPass;"
	    
    ;
> {
    pass LightNormalPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_LightNormal();
    }
    pass CameraCausPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_CameraCaus();
    }
    pass LightCausPassR < string Script= "Draw=Buffer;"; > {
	    ALPHABLENDENABLE = TRUE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
		SRCBLEND = ONE;
		DESTBLEND = ONE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_LightCaus(0,0.9);
    }
    pass LightCausPassG < string Script= "Draw=Buffer;"; > {
	    ALPHABLENDENABLE = TRUE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
		SRCBLEND = ONE;
		DESTBLEND = ONE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_LightCaus(1,1);
    }
    pass LightCausPassB < string Script= "Draw=Buffer;"; > {
	    ALPHABLENDENABLE = TRUE;
	    ALPHATESTENABLE=FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
		SRCBLEND = ONE;
		DESTBLEND = ONE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_LightCaus(2,1.1);
    }
    pass LightCausTestPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_LightCausTest();
    }
    //ガウスブラー
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX(LightCausSamp,0.2);
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passY();
        PixelShader  = compile ps_2_0 PS_passY(LightCausWorkSamp,0.2);
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
