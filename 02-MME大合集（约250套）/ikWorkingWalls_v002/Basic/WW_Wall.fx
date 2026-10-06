//-----------------------------------------------------------------------------
// 鏡面描画用
//-----------------------------------------------------------------------------
// パラメータ宣言

#include "WW_Settings.fxsub"

#if defined(FRAME_TEXTURE_NAME)

#include "_ww_common.fxsub"

//-----------------------------------------------------------------------------

// シェーダ内描画反復回数
// 左右同時なので半分にしておく
int RepeatCount = floor(360 / MinMirrorAngle) / 2;
int RepeatIndex; // 複製モデルカウンタ

float4x4 ViewProjMatrix : VIEWPROJECTION;
float4x4 ViewMatrix : VIEW;
float4x4 LightViewProjMatrix : VIEWPROJECTION < string Object = "Light"; >;

float3	LightDirection	: DIRECTION < string Object = "Light"; >;
float3	CameraPosition	: POSITION  < string Object = "Camera"; >;

float3	LightDiffuse		: DIFFUSE	< string Object = "Light"; >;
float3	LightAmbient		: AMBIENT	< string Object = "Light"; >;
float3	LightSpecular		: SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = float4(LightDiffuse, 1.0f);
//static float3 AmbientColor  = 0.3 * LightAmbient + 0;
static float3 AmbientColor  = 0.3;
static float3 SpecularColor = LightSpecular;

bool	parthf;	// パースペクティブフラグ
#define SKII1	1500
#define SKII2	8000

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

texture FrameTexture < string ResourceName = FRAME_TEXTURE_NAME; >;
sampler FrameSampler = sampler_state {
	Texture = <FrameTexture>;
	MINFILTER = LINEAR;	MAGFILTER = LINEAR;	MIPFILTER = LINEAR;
	ADDRESSU = CLAMP; ADDRESSV = CLAMP;
};
float4 GetFrameTexture(float2 uv) { return tex2D(FrameSampler, uv); }

sampler DefSampler : register(s0);


//-----------------------------------------------------------------------------
// 


float CheckBackface(float3 wpos, float side)
{
	#if CHECK_BACKFACE > 0
	float sinw, cosw;
	sincos(DEG2RAD(-0.5 * MirrorAngle), sinw, cosw);
	float3 WallN = float3(cosw * side, 0, sinw);
	WallN = mul(WallN, (float3x3)mWorldMat );
	float3 v = wpos.xyz - CameraPosition;
	return (dot(v, WallN) < 0.0);
	#else
	return 1;
	#endif
}



struct VS_OUTPUT {
	float4 Pos		: POSITION;	// 射影変換座標
	float4 ZCalcTex	: TEXCOORD0;	// Z値
	float2 Tex		: TEXCOORD1;	// テクスチャ
	float3 Normal	: TEXCOORD2;	// 法線
	float3 Eye		: TEXCOORD3;	// カメラとの相対位置
	float4 VPos		: TEXCOORD4;

	float4 Color	: COLOR0;		// ディフューズ色
	float3 Level	: COLOR1;		// 鏡による減衰色
};

struct PS_OUTPUT
{
	float4 Color	: COLOR0;
#if ENABLE_AL > 0
	float4 Emissive	: COLOR1;
#endif
};


VS_OUTPUT MirrorObject_VS(
	float4 Pos : POSITION, float3 Normal : NORMAL, 
	float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1, 
	uniform bool useSelfshadow)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	int planeNo = round(Pos.z * 10);
	float2 offset = float2((planeNo == 0) ? 2 : 0, 0);
	Pos.xyz = float3(Tex.xy * 2 - offset, 0);
	Pos.xy *= AcsSi * FRAME_SCALE * 0.5 * float2(-1,1);

	int level = RepeatCount - RepeatIndex - 1; // 後ろから描画。
	Out.Level = pow(MirrorColor, level);

	float side = ((planeNo == 0) ? 1 : -1); // 左右のどちら側か
	float angle = MirrorAngle * (level + 0.5);
	float rotY = (90 - angle) * side;
	float3x3 mat = RoundMatrixY(DEG2RAD(rotY));
	float4 lpos = Pos;
	bool isValid = (angle <= 180.0); // 一周するので描画しない。

	Pos.xyz = mul(lpos.xyz, mat);
	Pos = mul( Pos, mWorldMat );
	float4 wpos = Pos;

	Out.Pos = mul( Pos, ViewProjMatrix );
	Out.Pos.w *= isValid;
	Out.Pos.w *= CheckBackface(wpos.xyz/wpos.w, -side);
	Out.Eye = CameraPosition - wpos.xyz / wpos.w;
	Out.VPos = mul( wpos, ViewMatrix );

	// 回転で変わらない値：
	rotY = (90 - MirrorAngle * 0.5) * side;
	mat = RoundMatrixY(DEG2RAD(rotY));
	float3 N = mul( float3(0,0,-1), mat);
	Out.Normal = normalize(mul( N, (float3x3)mWorldMat));

	if (useSelfshadow)
	{
		lpos.xyz = mul(lpos.xyz, mat);
		float4 wpos0 = mul(lpos, mWorldMat );
		Out.ZCalcTex = mul( wpos0, LightViewProjMatrix );
	}

	Out.Tex = Tex;

	return Out;
}


PS_OUTPUT Object_PS(VS_OUTPUT IN, uniform bool useSelfshadow)
{
	float3 L = -LightDirection;
	float3 N = normalize(IN.Normal);
	float3 V = normalize(IN.Eye);
	float3 H = normalize( V + L );
	float diffuse = saturate(dot(N,L));
	float3 specular = pow( saturate(dot(H,N)), 64.0) * SpecularColor;

	float comp = 1;
	if (useSelfshadow)
	{
		// テクスチャ座標に変換
		IN.ZCalcTex /= IN.ZCalcTex.w;
		float2 TransTexCoord = IN.ZCalcTex.xy * float2(0.5, - 0.5) + 0.5;
		if( all( saturate(TransTexCoord) == TransTexCoord ) )
		{
			float shadow = max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f);
			float k = (parthf) ? SKII2 * TransTexCoord.y : SKII1;
			comp = 1 - saturate(shadow * k - 0.3f);
		}
	}

	float4 Color = float4(AmbientColor, 1);
	float4 ShadowColor = Color;
	Color.rgb += saturate(diffuse) * DiffuseColor.rgb;
	float4 TexColor = GetFrameTexture(IN.Tex);
	Color *= TexColor;
	ShadowColor *= TexColor;
	// Color.rgb += specular; // スペキュラが透明度を変更する。
	Color = lerp(ShadowColor, Color, comp);
	Color.rgb *= IN.Level;

	PS_OUTPUT	Out;
	Out.Color = Color;
	#if ENABLE_AL > 0
	Out.Emissive = float4(0,0,0, Color.a);
	#endif
	return Out;
}

#if ENABLE_DOF > 0
float4 ObjectDepth_PS(VS_OUTPUT IN) : COLOR
{
	float4 Color = GetFrameTexture(IN.Tex);
	clip(Color.a - 0.1);
	float distance = length(IN.VPos.xyz);
	return float4(distance / FAR_DEPTH, 0, 0, 1);
}
#endif

#if ENABLE_DOF > 0
shared texture WW_DepthMapRT: RENDERCOLORTARGET;
#endif
#if ENABLE_AL > 0
shared texture WW_EmissiveMapRT: RENDERCOLORTARGET;
#endif

#if ENABLE_DOF > 0
#if ENABLE_AL > 0
// DoF + AL
#define	ObjectScriptBody	\
		"RenderColorTarget0=WW_DepthMapRT; Pass=DrawMirrorDepth; RenderColorTarget0=;" \
		"RenderColorTarget1=WW_EmissiveMapRT; Pass=DrawMirrorObject; RenderColorTarget1=;"
#else
// DoF
#define	ObjectScriptBody	\
		"RenderColorTarget0=WW_DepthMapRT; Pass=DrawMirrorDepth; RenderColorTarget0=;" \
		"Pass=DrawMirrorObject;"
#endif

#define OBJECT_TEC(name, mmdpass, selfshadow) \
	technique name < string MMDPass = mmdpass; \
	string Script = \
		"LoopByCount=RepeatCount; LoopGetIndex=RepeatIndex;" \
			ObjectScriptBody \
		"LoopEnd=;" ; > { \
		pass DrawMirrorDepth { \
			ZENABLE = TRUE;	ZWRITEENABLE = FALSE; CULLMODE = NONE; \
			VertexShader = compile vs_3_0 MirrorObject_VS(false); \
			PixelShader  = compile ps_3_0 ObjectDepth_PS(); \
		} \
		pass DrawMirrorObject { \
			CullMode = NONE;\
			VertexShader = compile vs_3_0 MirrorObject_VS(selfshadow); \
			PixelShader  = compile ps_3_0 Object_PS(selfshadow); \
		} \
	}

#else

#if ENABLE_AL > 0
// AL
#define	ObjectScriptString	\
		"RenderColorTarget1=WW_EmissiveMapRT;" \
		"LoopByCount=RepeatCount; LoopGetIndex=RepeatIndex;" \
			"Pass=DrawMirrorObject;" \
		"LoopEnd=;" \
		"RenderColorTarget1=;"
#else
// No DoF + No AL
#define	ObjectScriptString	\
		"LoopByCount=RepeatCount; LoopGetIndex=RepeatIndex;" \
			"Pass=DrawMirrorObject;" \
		"LoopEnd=;"
#endif

#define OBJECT_TEC(name, mmdpass, selfshadow) \
	technique name < string MMDPass = mmdpass; \
	string Script = ObjectScriptString; > { \
		pass DrawMirrorObject { \
			CullMode = NONE;\
			VertexShader = compile vs_3_0 MirrorObject_VS(selfshadow); \
			PixelShader  = compile ps_3_0 Object_PS(selfshadow); \
		} \
	}

#endif

OBJECT_TEC(MainTec0, "object", false)
OBJECT_TEC(MainTec1, "object_ss", true)

#else // defined(FRAME_TEXTURE_NAME)
technique MainTec0 < string MMDPass = "object"; > {}
technique MainTec1 < string MMDPass = "object_ss"; > {}
#endif

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}

//-----------------------------------------------------------------------------
