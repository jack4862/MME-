//=============================================================================

// 自動的にサイズ変更　1で有効、0で無効
#define AUTO_RESIZE  1

// 解像度向上　1で有効、0で無効
#define HIGH_RESOLUTION  1

// アンチエイリアス　1で有効、0で無効
#define ANTIALIAS	1


// 色収差。画面の端で色がズレる
#define COLOR_DISTORTION	1

// 色収差のズレ幅。-4.0～4.0
// 画面がゆがむほど色収差のズレも大きくなる。
float ColorDistortionRate = 3.0;

// 色収差のサンプリング数。1～8。大きいほど重い。
#define COLOR_DISTORTION_STEP	3


// 周辺減光。画面の隅が暗くなる。
#define VIGNETTING		1

// 周辺減光で暗くする率。0.0～1.0
float VignettingRate = 0.25;


// 画面外の色
#define OffScreenColor	float3(0, 0, 0)



//-----------------------------------------------------------------------------

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,0};
float ClearDepth  = 1.0;

#if HIGH_RESOLUTION > 0
#define ScreenScale		2 // 解像度向上の倍率。大きいほど遅い + 上限がある。
#else
#define ScreenScale		1
#endif

// テクスチャフォーマット
//#define TEXFORMAT "A32B32G32R32F"
//#define TEXFORMAT "A16B16G16R16F"
#define TEXFORMAT "A8R8G8B8"


// 縦横の歪む割合。1でxyが等しくゆがむ。
// 1未満でyは直線を維持する。1以上でxは直線を維持する
float LensAspect = 1.0;	// 0.5～1.5程度?
	// 現在は機能していない。
	// xのみ、yのみ歪ませるのに使いたい。



#define PAI 3.14159265f	// π
float epsilon = 1e-4;


//=============================================================================

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5) /(ScreenScale * ViewportSize.xy));
static float2 SampleStep = (float2(1.0,1.0) / (ScreenScale * ViewportSize.xy));

// 0～90度を0～1.0にマップしたあと、カメラデフォルトの35度で歪みが0になるように補正。
float4x4 matP : PROJECTION;
static float fovY2 = atan(1.0 / matP._22) * 4.0 / PAI - 0.3888;

float4x4 AcsMatrix : CONTROLOBJECT < string name = "(self)"; >;
static const float3 AcsPos = AcsMatrix._41_42_43;
static float Distortion = AcsPos.x * 0.1;
static float Zoom = AcsPos.z / 10.0 + 1.0;

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewportRatio = {ScreenScale, ScreenScale};
	int MipLevels = 1;
	string Format = TEXFORMAT;
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU  = CLAMP;	AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewportRatio = {ScreenScale, ScreenScale};
	string Format = "D24S8";
>;


//-----------------------------------------------------------------------------
//

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float4 TexCoord		: TEXCOORD0;
	float4 Warp			: TEXCOORD1;
	float4 Info			: TEXCOORD2;
};

float3 ComputePosition(float2 ipos, float4 warp, float distortion)
{
	float2 p = ipos - 0.5;
	p *= warp.xy;

	float t = distortion;
	float l2 = dot(p,p);
	float invl = sqrt(max(1.0 - l2, 0));
	float z = (1 - invl) * -t + 1;
	p = p.xy / max(z, epsilon);
	if (z <= 0.0) return float3(-1,-1,1); // out of range

	// 疑似的な曲率
	float curvature = max(1.0 - invl, 0) * abs(t);
	curvature *= (distortion >= 0) ? 3 : 0.5;

	p *= warp.zw;
	p = p + 0.5;
	return float3(p, curvature);
}

float2 ResolvePosition(float2 ipos, float4 warp, float distortion)
{
	float2 p = ipos - 0.5;
	p *= warp.xy;
	float t = distortion;
	float l2 = dot(p,p);

	float a0 = 1 / t;
	float b0 = 1 - 1 / t;

	float a = a0 * a0 + l2;
	float b = 2.0 * a0 * b0;
	float c = b0 * b0 - 1.0;
	float d = sqrt(max(b*b - 4*a*c, 0));
	float x1 = (-b + d) / (2*a);
	float x2 = (-b - d) / (2*a);

	// p *= (distortion >= 0.0) ? x1 : x2;
	p *= x1;
	p *= warp.zw;
	p = p + 0.5;
	return p;
}

VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy;

	float lensAspect = LensAspect; // + clamp(AcsPos.y * 0.1, -1.0, 1.0) * 0.5;
	float aspect = (ViewportSize.x * lensAspect) / ViewportSize.y;
	float invAspect = ViewportSize.y / (ViewportSize.x * lensAspect);
	float4 warp = float4(aspect, 1, invAspect, 1);

	float distortion = pow(Distortion, 3);
	distortion += fovY2;

	#if AUTO_RESIZE > 0
	float2 invUvRD = ResolvePosition(float2(1,1), warp, distortion);
	invUvRD.x = max(invUvRD.x, invUvRD.y);
	invUvRD.x = (invUvRD.x * 2.0 - 1);
	invUvRD.x = distortion <= 0.0 ? 1.0 : invUvRD.x;
	float resize = invUvRD.x;
	#else
	float resize = 1;
	#endif
	float zoom = Zoom;

	Out.TexCoord = float4(TexCoord, 0,0);
	Out.Warp = warp * float2(zoom * resize, 1).xxyy;
	Out.Info.x = distortion;

	return Out;
}

float3 CheckBorder(float2 uv, float3 col)
{
	#if 1 // AUTO_RESIZE == 0
	return all(saturate(uv) == uv) ? col.rgb : OffScreenColor;
	#else
	return col;
	#endif
}

float2 RescaleUV(float2 uv, float rate)
{
	float2 uv1 = uv * 2 - 1;
	return uv1 * ((1.0 + rate) * 0.5) + 0.5;
}


float4 GetPixel(float2 texCoord, float4 warp, float distination)
{
	float3 uv = ComputePosition(texCoord, warp, distination);

#if COLOR_DISTORTION > 0 && COLOR_DISTORTION_STEP > 1
	// 色収差
	float k = uv.z * ColorDistortionRate * (1.0 / 128.0);
	float2 uvb = RescaleUV(uv.xy,  k);
	float2 uve = RescaleUV(uv.xy, -k);
	float3 col = 0;
	float3 colw = 0;

	for(int i = 0; i < COLOR_DISTORTION_STEP; i++)
	{
		float t = i * 1.0 / (COLOR_DISTORTION_STEP - 1.0);
		float3 col0 = tex2D(ScnSamp, lerp(uvb, uve, t)).rgb;
		float3 colw0 = float3(1-t, 1 - abs(t*2-1), t);
		col += col0 * colw0;
		colw += colw0;
	}

	col /= colw;
#else
	float3 col = tex2D(ScnSamp, uv).rgb;
#endif

	return float4(CheckBorder(uv, col), uv.z);
}


float4 PS_Final( VS_OUTPUT IN) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float4 warp = IN.Warp;
	float distortion = IN.Info.x;

#if ANTIALIAS == 0
	float4 col = GetPixel(texCoord, warp, distortion);

#else
	float2 s = SampleStep * 2.0 / 3.0; // ???
	#define GetPixelOffset(_x,_y)	\
		GetPixel(texCoord + float2(_x, _y) * s, warp, distortion)
#if 0 // 3x3
	float4 col = 0;
	col += GetPixelOffset(-1,-1);
	col += GetPixelOffset( 0,-1) * 2;
	col += GetPixelOffset( 1,-1);
	col += GetPixelOffset(-1, 0) * 2;
	col += GetPixelOffset( 0, 0) * 4;
	col += GetPixelOffset( 1, 0) * 2;
	col += GetPixelOffset(-1, 1);
	col += GetPixelOffset( 0, 1) * 2;
	col += GetPixelOffset( 1, 1);
	col /= 16.0;
#else // 4+1
	float4 col = 0;
	col += GetPixelOffset(-1,-1);
	col += GetPixelOffset( 1,-1);
	col += GetPixelOffset( 0, 0) * 4;
	col += GetPixelOffset(-1, 1);
	col += GetPixelOffset( 1, 1);
	col /= 8.0;
#endif
#endif

	#if VIGNETTING > 0
	// 周辺減光
	float v = saturate(col.w * VignettingRate);
	col.rgb = lerp(col.rgb, float3(0,0,0), v);
	#endif

	return float4(col.rgb, 1);
}

//=============================================================================

technique FishEyeTech <
	string Script = 
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color; Clear=Depth;"
		"ScriptExternal=Color;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Clear=Color; Clear=Depth;"
		"Pass=FinalPass;"
	;
> {
	pass FinalPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Final();
	}
}

//=============================================================================
