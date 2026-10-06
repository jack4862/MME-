//-----------------------------------------------------------------------------
// ikWorkingWalls 用にオブジェクトを回転させて描画する
//-----------------------------------------------------------------------------
// パラメータ宣言

#include "WW_Settings.fxsub"
#include "_ww_common.fxsub"

// シェーダ内描画反復回数
int RepeatCount = floor(360 / MinMirrorAngle - 1) + 1;
	// 正面は特別扱いなので1つへらす。
int RepeatIndex; // 複製モデルカウンタ

float4x4 WorldMatrix				: WORLD;
float4x4 ViewMatrix					: VIEW;
float4x4 ViewProjMatrix				: VIEWPROJECTION;
float4x4 LightWorldViewProjMatrix	: WORLDVIEWPROJECTION < string Object = "Light"; >;

float3	LightDirection	: DIRECTION < string Object = "Light"; >;
float3	CameraPosition	: POSITION  < string Object = "Camera"; >;
float3	CameraDirection	: DIRECTION < string Object = "Camera"; >;

// マテリアル色
float4	MaterialDiffuse		: DIFFUSE  < string Object = "Geometry"; >;
float3	MaterialAmbient		: AMBIENT  < string Object = "Geometry"; >;
float3	MaterialEmissive	: EMISSIVE < string Object = "Geometry"; >;
float3	MaterialSpecular	: SPECULAR < string Object = "Geometry"; >;
float	SpecularPower		: SPECULARPOWER < string Object = "Geometry"; >;
float3	MaterialToon		: TOONCOLOR;
float4	EdgeColor			: EDGECOLOR;
float4	GroundShadowColor	: GROUNDSHADOWCOLOR;
// ライト色
float3	LightDiffuse		: DIFFUSE	< string Object = "Light"; >;
float3	LightAmbient		: AMBIENT	< string Object = "Light"; >;
float3	LightSpecular		: SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = MaterialAmbient  * LightAmbient + MaterialEmissive;
static float3 SpecularColor = MaterialSpecular * LightSpecular;

// テクスチャ材質モーフ値
float4	TextureAddValue	: ADDINGTEXTURE;
float4	TextureMulValue	: MULTIPLYINGTEXTURE;
float4	SphereAddValue	: ADDINGSPHERETEXTURE;
float4	SphereMulValue	: MULTIPLYINGSPHERETEXTURE;

bool	use_texture;		// テクスチャフラグ
bool	use_spheremap;		// スフィアフラグ
bool	use_toon;			// トゥーンフラグ
bool	use_subtexture;		// サブテクスチャフラグ

bool	parthf;	// パースペクティブフラグ
bool	transp;	// 半透明フラグ
bool	spadd;	// スフィアマップ加算合成フラグ
#define SKII1	1500
#define SKII2	8000
#define Toon	3


texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;	MAGFILTER = LINEAR;	MIPFILTER = LINEAR;
	ADDRESSU  = WRAP;	ADDRESSV  = WRAP;
};

texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
	texture = <ObjectSphereMap>;
	MINFILTER = LINEAR;	MAGFILTER = LINEAR;	MIPFILTER = NONE;
	ADDRESSU  = WRAP;	ADDRESSV  = WRAP;
};
// AL用
sampler ObjSphareSamplerPoint = sampler_state {
	texture = <ObjectSphereMap>;
	MINFILTER = POINT;	MAGFILTER = POINT;	MIPFILTER = NONE;
	ADDRESSU  = WRAP;	ADDRESSV  = WRAP;
};

sampler DefSampler : register(s0);

bool IsOutOfArea(float3 lpos, float2 angleLimit)
{
	float ang = RAD2DEG(atan2(lpos.x, -lpos.z));
	return (angleLimit.x > ang || ang > angleLimit.y);
}


//-----------------------------------------------------------------------------
// AL
#if ENABLE_AL > 0
//テクスチャ高輝度識別フラグ
//#define TEXTURE_SELECTLIGHT

//テクスチャ高輝度識別閾値
float LightThreshold = 0.9;

//フレーム数に同期させるかどうか
#define SYNC false

#define SPECULAR_BASE 100

float LightUp : CONTROLOBJECT < string name = "(self)"; string item = "LightUp"; >;
float LightUpE : CONTROLOBJECT < string name = "(self)"; string item = "LightUpE"; >;
float LightOff : CONTROLOBJECT < string name = "(self)"; string item = "LightOff"; >;
float Blink : CONTROLOBJECT < string name = "(self)"; string item = "LightBlink"; >;
float BlinkSq : CONTROLOBJECT < string name = "(self)"; string item = "LightBS"; >;
float BlinkDuty : CONTROLOBJECT < string name = "(self)"; string item = "LightDuty"; >;
float BlinkMin : CONTROLOBJECT < string name = "(self)"; string item = "LightMin"; >;
float LClockUp : CONTROLOBJECT < string name = "(self)"; string item = "LClockUp"; >;
float LClockDown : CONTROLOBJECT < string name = "(self)"; string item = "LClockDown"; >;

float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float4 EgColor; 
static float materialAlpha = EgColor.a;

//時間
float ftime : TIME <bool SyncInEditMode = SYNC;>;

static float duty = (BlinkDuty <= 0) ? 0.5 : BlinkDuty;
static float timerate = ((Blink > 0) ? ((1 - cos(saturate(frac(ftime / (Blink * 10)) / (duty * 2)) * 2 * PI)) * 0.5) : 1.0)
					  * ((BlinkSq > 0) ? (frac(ftime / (BlinkSq * 10)) < duty) : 1.0);
static float timerate1 = timerate * (1 - BlinkMin) + BlinkMin;

static float ClockShift = (1 + LClockDown * 5) / (1 + LClockUp * 5);

static bool IsEmission = (SPECULAR_BASE < SpecularPower)/* && (SpecularPower <= (SPECULAR_BASE + 100))*/ && (length(MaterialSpecular) < 0.01);
static float EmissionPower0 = IsEmission ? ((SpecularPower - SPECULAR_BASE) / 7.0) : 1;
static float EmissionPower1 = EmissionPower0 * (LightUp * 2 + 1.0) * pow(400, LightUpE) * (1.0 - LightOff);

float texlight(float3 rgb){
	float val = saturate((length(rgb) - LightThreshold) * 3);
	
	val *= 0.2;
	
	return val;
}

bool DecisionSystemCode(float4 SystemCode){
	bool val = (0.199 < SystemCode.r) && (SystemCode.r < 0.201)
			&& (0.699 < SystemCode.g) && (SystemCode.g < 0.701);
	return val;
}

float4 getFlags(float flagcode){
	float4 val = frac(flagcode * float4(0.1, 0.01, 0.001, 0.0001));
	val = floor(val * 10 + 0.001);
	return val;
}

float2 DecisionSequenceCode(float4 color){
	bool val = (color.r > 0.99) && (abs(color.g - 0.5) < 0.02)
			&& ((color.b < 0.01) || (color.g > 0.99));
	
	return float2(val, (color.b < 0.01));
}

float4 ComputeALColorVS(
	float4 SystemCode, float4 ColorCode, float4 AppendCode,
	bool IsALCode, float4 flags)
{
	float4 ColorAL = MaterialDiffuse;
	ColorAL.a = materialAlpha;
	ColorAL.rgb += MaterialEmmisive / 2;
	ColorAL.rgb *= 0.5;
	ColorAL.rgb = IsEmission ? ColorAL.rgb : float3(0,0,0);

	float3 UVColor = ColorCode.rgb;
	UVColor = lerp(UVColor, hsv2rgb(UVColor), flags.y);
	UVColor *= ColorCode.a;

	ColorAL.rgb += IsALCode ? UVColor : float3(0,0,0);

	float Tv = SystemCode.z * ClockShift;
	float Ph = AppendCode.y * ClockShift;
	float timerate2 = (Tv > 0) ? ((1 - cos(saturate(frac((ftime + Ph) / Tv) / (duty * 2)) * 2 * PI)) * 0.5)
					 : ((Tv < 0) ? (frac((ftime + Ph) / (-Tv / PI * 180)) < duty) : 1.0);
	ColorAL.rgb *= max(timerate2 * (1 - BlinkMin) + BlinkMin, !IsALCode);
	ColorAL.rgb *= max(timerate1, SystemCode.z != 0);
	return ColorAL;
}


float4 ComputeALColor(float4 InColorAL, float4 InTex)
{
	float4 ColorAL = InColorAL;

	if(use_spheremap){
		//float4 spcolor1 = tex2Dlod(ObjSphareSamplerPoint, float4(1,0,0,0));
		float4 spcolor2 = tex2Dlod(ObjSphareSamplerPoint, float4(1,1,0,0));
		float4 spcolor3 = tex2Dlod(ObjSphareSamplerPoint, float4(0,1,0,0));
		float Ts = spcolor3.r * (255 * 60) + spcolor3.g * 255 + spcolor3.b * (255 / 100.0);
		Ts *= ClockShift;
		float t1 = frac((ftime/* + Ph * IsALCode*/) / Ts);
		float4 spcolor4 = tex2Dlod(ObjSphareSamplerPoint, float4(t1 * 0.25,0,0,0));
		float4 spcolor5 = tex2Dlod(ObjSphareSampler, float4(t1 * 0.25,0,0,0));
		float2 sel = DecisionSequenceCode(spcolor2);
		ColorAL.rgb *= lerp(float3(1,1,1), lerp(spcolor5.rgb, spcolor4.rgb, sel.y), sel.x);
	}

	if(use_texture){
		float4 texcolor;
		texcolor = tex2D(ObjTexSampler,InTex.xy);
		texcolor.rgb = saturate(texcolor.rgb - InTex.z);
		
		#ifdef TEXTURE_SELECTLIGHT
			ColorAL = texcolor;
			ColorAL.rgb *= texlight(ColorAL.rgb);
		#else
			float4 Color2, Color3;
			Color2 = ColorAL * texcolor;
			Color3 = ColorAL * texcolor;
			Color3.rgb *= texlight(texcolor.rgb);
			ColorAL = (InTex.w < 0.1) ? Color2 : ((InTex.w < 1.1) ? ColorAL : Color3);
		#endif
	}

	ColorAL.rgb *= lerp(EmissionPower0, EmissionPower1, (float)use_toon);
	return ColorAL;
}

#endif


//-----------------------------------------------------------------------------
// 

struct VS_Work {
	float4 WPos;
	float4 LPos;
	float2 AngleLimit;
	float3 Level;
	bool IsValid;
	float Side;
	float Reverse;
	float Angle;
};

VS_Work ComputeVSWork(float4 Pos)
{
	VS_Work Out;

	int index = RepeatCount - RepeatIndex - 1; // 後ろから描画。
	int halfIndex = floor(index / 2);
	float side = (index % 2) * 2 - 1; // 左右のどちら側か
	float reverse = (halfIndex % 2) * 2 - 1; // モデルを左右反転する?
	int level = halfIndex + 1;

	float angle = level * MirrorAngle;
	float angleOffset = (side * angle);
	float2 angleLimit = MirrorAngle * 0.5 * float2(-1, 1) - angleOffset;
	angleLimit = clamp(angleLimit, -180, 180) + angleOffset;
	bool isValid = (angleLimit.x != angleLimit.y); // 一周するので描画しない。

	float4 wpos = mul( Pos, WorldMatrix );
	Out.WPos = wpos;
	Out.LPos = mul(wpos, MirrorInvMatrix);
	Out.Level = pow(MirrorColor, level);

	Out.AngleLimit = angleLimit;
	Out.IsValid = isValid;
	Out.Side = side;
	Out.Reverse = reverse;
	Out.Angle = DEG2RAD(side * angle);

	return Out;
}

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


#if ENABLE_EDGE > 0

struct VS_EdgeOUTPUT {
	float4 Pos : POSITION;				// 射影変換座標
	float4 LPos : TEXCOORD0;
	float2 AngleLimit	: TEXCOORD1;
	float3 Level	: COLOR0;		// 色
};

VS_EdgeOUTPUT MirrorColorRender_VS(float4 Pos : POSITION, uniform int isCCW)
{
	VS_EdgeOUTPUT Out = (VS_EdgeOUTPUT)0;
	VS_Work work = ComputeVSWork(Pos);
	bool IsValid = work.IsValid && ((work.Reverse < 0) == isCCW);

	float4 wpos = work.WPos;
	float4x4 matRot = RoundMatrixY(work.Angle, work.Reverse);
	wpos = mul(wpos, matRot);

	Out.Pos = mul( wpos, ViewProjMatrix );
	Out.Pos.w *= IsValid;
	Out.Pos.w *= CheckBackface(wpos.xyz / wpos.w, work.Side);

	Out.LPos = work.LPos;
	Out.AngleLimit = work.AngleLimit;
	Out.Level = work.Level;

	return Out;
}

float4 ColorRender_PS(VS_EdgeOUTPUT IN) : COLOR
{
	clip(0.1 - IsOutOfArea(IN.LPos.xyz, IN.AngleLimit.xy));
	return 	float4(EdgeColor.rgb * IN.Level, EdgeColor.a);
}

technique EdgeTec < string MMDPass = "edge";
	string Script = 
		"LoopByCount=RepeatCount;"
		"LoopGetIndex=RepeatIndex;"
			"Pass=DrawMirrorObject;"
			"Pass=DrawMirrorObjectCCW;"
		"LoopEnd=;" ;
> {
	pass DrawMirrorObject {
		CullMode = CW;
		VertexShader = compile vs_3_0 MirrorColorRender_VS(0);
		PixelShader  = compile ps_3_0 ColorRender_PS();
	}
	pass DrawMirrorObjectCCW {
		// 左右反転したやつの Cullmodeを CW (CCW?)にする必要がある。
		CullMode = CCW;
		VertexShader = compile vs_3_0 MirrorColorRender_VS(1);
		PixelShader  = compile ps_3_0 ColorRender_PS();
	}
}
#else

technique EdgeTec < string MMDPass = "edge"; > { }
#endif


//-----------------------------------------------------------------------------
// オブジェクト描画

struct VS_OUTPUT {
	float4 Pos		: POSITION;
	float4 ZCalcTex	: TEXCOORD0;	// シャドウマップ
	float4 Tex		: TEXCOORD1;	// テクスチャ
	float3 Normal	: TEXCOORD2;	// 法線
	float3 Eye		: TEXCOORD3;	// カメラとの相対位置
	float4 SpTex	: TEXCOORD4;	// スフィアマップ + 角度制限
	float4 LPos		: TEXCOORD5;	// ローカル座標(範囲チェック用)
	float4 VPos		: TEXCOORD6;	// DoFの深度計算用

	float4 Color	: COLOR0;		// ディフューズ色
	float3 Level	: COLOR1;		// 鏡による減衰色
	#if ENABLE_AL > 0
	float4 ColorAL	: COLOR2;		// 発光色
	#endif
};

struct PS_OUTPUT
{
	float4 Color	: COLOR0;

#if ENABLE_DOF > 0 && ENABLE_AL > 0
	float4 Depth	: COLOR1;
	float4 Emissive	: COLOR2;

#elif ENABLE_DOF > 0
	float4 Depth	: COLOR1;

#elif ENABLE_AL > 0
	float4 Emissive	: COLOR1;

#else
#endif
};


VS_OUTPUT MirrorObject_VS(
	float4 Pos : POSITION, float3 Normal : NORMAL, 
	float2 Tex : TEXCOORD0, float4 Tex1 : TEXCOORD1, 
	#if ENABLE_AL > 0
	float4 Tex2 : TEXCOORD2, float4 Tex3 : TEXCOORD3, 
	#endif
	uniform bool useTexture, uniform bool useSphereMap, 
	uniform bool useToon, uniform bool useSelfshadow)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	VS_Work work = ComputeVSWork(Pos);

	float4 wpos = work.WPos;
	float4x4 matRot = RoundMatrixY(work.Angle, work.Reverse);
	wpos = mul(wpos, matRot);

	Out.Pos = mul( wpos, ViewProjMatrix );
	Out.Pos.w *= work.IsValid;
	Out.Pos.w *= CheckBackface(wpos.xyz / wpos.w, work.Side);
	Out.Eye = CameraPosition - wpos.xyz / wpos.w;
	Out.VPos = mul( wpos, ViewMatrix );

	Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

	Out.LPos = work.LPos;
	Out.Level = work.Level;
	Out.SpTex.zw = work.AngleLimit;

	if (useSelfshadow)
	{
		Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
	}

	// ディフューズ色＋アンビエント色 計算
	Out.Color.rgb = AmbientColor;
	Out.Color.a = DiffuseColor.a;
//	Out.Color = saturate( Out.Color );

	Out.Tex.xy = Tex;

	//-------------------------------------------------------------------------
	#if ENABLE_AL > 0
	float4 SystemCode = Tex1;
	float4 ColorCode = Tex2;
	float4 AppendCode = Tex3;
	bool IsALCode = DecisionSystemCode(SystemCode);
	float4 flags = getFlags(SystemCode.w);
	Out.ColorAL = ComputeALColorVS(SystemCode, ColorCode, AppendCode, IsALCode, flags);
	Out.Tex.z = IsALCode * AppendCode.x;
	Out.Tex.w = IsALCode * flags.x;
	#endif
	//-------------------------------------------------------------------------

	if ( useSphereMap ) {
		if ( use_subtexture ) {
			Out.SpTex.xy = Tex1.xy;
		} else {
			float3 localN = Out.Normal;
			localN = mul(localN, (float3x3)matRot); // mirror
			float2 NormalWV = normalize(mul( localN, (float3x3)ViewMatrix )).xy;
			Out.SpTex.xy = NormalWV.xy * float2(0.5,-0.5) + 0.5;
		}
	}
	
	return Out;
}


PS_OUTPUT Object_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon, uniform bool useSelfshadow)
{
	float2 AngleLimit = IN.SpTex.zw;
	clip(0.1 - IsOutOfArea(IN.LPos.xyz, AngleLimit));

	float3 L = -LightDirection;
	float3 N = normalize(IN.Normal);
	float3 V = normalize(IN.Eye);
	float3 H = normalize( V + L );
	float diffuse = dot(N,L);
	float3 specular = pow( saturate(dot(H,N)), SpecularPower) * SpecularColor;

	float4 Color = IN.Color;

	if ( !useToon )
	{
		Color.rgb += saturate(diffuse) * DiffuseColor.rgb;
	}
	Color = saturate( Color );

	float4 ShadowColor = float4(saturate(AmbientColor), Color.a);  // 影の色
	if ( useTexture ) {
		float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
		TexColor.rgb = lerp(1, TexColor * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a).rgb;
		Color *= TexColor;
		ShadowColor *= TexColor;
	}

	if ( useSphereMap ) {
		float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
		TexColor.rgb = lerp(spadd?0:1, TexColor * SphereMulValue + SphereAddValue, SphereMulValue.a + SphereAddValue.a).rgb;
		if(spadd) {
			Color.rgb += TexColor.rgb;
			ShadowColor.rgb += TexColor.rgb;
		} else {
			Color.rgb *= TexColor.rgb;
			ShadowColor.rgb *= TexColor.rgb;
		}
		Color.a *= TexColor.a;
		ShadowColor.a *= TexColor.a;
	}

	#if ENABLE_DOF > 0
	clip(Color.a - 1e-4); // 透明なら破棄。
	#endif

	Color.rgb += specular;

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

	if ( useToon )
	{
		comp = min(saturate(diffuse * Toon), comp);
		ShadowColor.rgb *= MaterialToon;
	}

	float4 ans = lerp(ShadowColor, Color, comp);
	ans.rgb *= IN.Level;

	PS_OUTPUT	Out;
	Out.Color = ans;

	#if ENABLE_DOF > 0
	float distance = length(IN.VPos.xyz);
	Out.Depth = float4(distance / FAR_DEPTH, 0, 0, 1);
	#endif

	#if ENABLE_AL > 0
	float4 ColorAL = ComputeALColor(IN.ColorAL, IN.Tex);
	ColorAL.rgb *= IN.Level;
	Out.Emissive = ColorAL;
	#endif

	return Out;
}


#if ENABLE_DOF > 0
shared texture WW_DepthMapRT: RENDERCOLORTARGET;
#endif
#if ENABLE_AL > 0
shared texture WW_EmissiveMapRT: RENDERCOLORTARGET;
#endif

#if ENABLE_DOF > 0 && ENABLE_AL > 0
	#define ObjectScriptHeaderString \
		"RenderColorTarget1=WW_DepthMapRT;" \
		"RenderColorTarget2=WW_EmissiveMapRT;"
	#define ObjectScriptFooterString \
		"RenderColorTarget1=;" \
		"RenderColorTarget2=;"
#elif ENABLE_DOF > 0
	#define ObjectScriptHeaderString \
		"RenderColorTarget1=WW_DepthMapRT;"
	#define ObjectScriptFooterString \
		"RenderColorTarget1=;"
#elif ENABLE_AL > 0
	#define ObjectScriptHeaderString \
		"RenderColorTarget1=WW_EmissiveMapRT;"
	#define ObjectScriptFooterString \
		"RenderColorTarget1=;"
#else
	#define ObjectScriptHeaderString
	#define ObjectScriptFooterString
#endif

#define OBJECT_TEC(name, mmdpass, tex, sphere, toon, selfshadow) \
	technique name < string MMDPass = mmdpass; \
	string Script = \
		ObjectScriptHeaderString \
		"LoopByCount=RepeatCount;" \
		"LoopGetIndex=RepeatIndex;" \
			"Pass=DrawMirrorObject;" \
		"LoopEnd=;" \
		ObjectScriptFooterString \
	; > { \
		pass DrawMirrorObject { \
			CullMode = NONE;\
			VertexShader = compile vs_3_0 MirrorObject_VS(tex, sphere, toon, selfshadow); \
			PixelShader  = compile ps_3_0 Object_PS(tex, sphere, toon, selfshadow); \
		} \
	}

OBJECT_TEC(MainTec0, "object", use_texture, use_spheremap, use_toon, false)
OBJECT_TEC(MainTecBS0, "object_ss", use_texture, use_spheremap, use_toon, true)

technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

//-----------------------------------------------------------------------------
