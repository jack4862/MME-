// ホログラム箔っぽくする

// 設定項目

#define NORMALMAP_FILENAME "tex/glint1.png" // メインの法線マップ
float NormalMapLoopNum = 8; // 繰り返し回数。大きいほど模様が細かくなる
float NormalMapHeightScale = 1.0; // 高さ補正。正で高くなる 0で平坦 (-4～4程度)

// 追加テクスチャ
#define ENABLE_SUBNORMAL	1 // 0:追加テクスチャ無効、1:有効
#define SUBNORMALMAP_FILENAME "tex/grad.png" // 追加テクスチャのファイル名
float SubNormalMapLoopNum = 1;
float SubNormalMapHeightScale = 0.2;

// マスクマップ (ホロ対応したくない部分を除外する)
// Rチャンネル(赤)が1でホロ有効。0でホロ無効。
#define ENABLE_HOLOMASK	0 // 0:マスク無効、1:有効
#define MASKMAP_FILENAME "tex/mask.png" // マスクテクスチャのファイル名
float MaskMapLoopNum = 1;

// 色の調整
float3 HoloSkyColor = float3(0.5,0.5,1); // ホロ全体の色(上)
float3 HoloGrandColor = float3(0.5,1,0.5); // ホロ全体の色(下)
float HoloSaturation = 0.75; // ホロの彩度。0.0:無彩色、1.0:虹色。
float HoloHueOffset = 0.0; // 色相のオフセット
float HoloIntensity = 2.0; // ホロ全体の明るさ 0.5～2.0程度
float HoloGradient = 4.0; // 虹色の変化度合い。0.5～6.0程度
float HoloAttenuation = 0.9; // 元の色の明るさ 0.0～1.0

// ライト色の影響を受ける?
float LightColorAware = 0.5; // 0.0:受けない、1.0:受ける

// ミップマップを有効にするか?
#define ENBALE_MIPMAP		1 // 0:無効、1:有効


//-----------------------------------------------------------------------------
// パラメータ宣言

// 座法変換行列
float4x4 WorldViewProjMatrix		: WORLDVIEWPROJECTION;
float4x4 WorldMatrix				: WORLD;
float4x4 ViewMatrix					: VIEW;
float4x4 LightWorldViewProjMatrix	: WORLDVIEWPROJECTION < string Object = "Light"; >;

float3	LightDirection	: DIRECTION < string Object = "Light"; >;
float3	CameraPosition	: POSITION  < string Object = "Camera"; >;

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


// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR; MAGFILTER = LINEAR; MIPFILTER = LINEAR;
	ADDRESSU  = WRAP; ADDRESSV  = WRAP;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
	texture = <ObjectSphereMap>;
	MINFILTER = LINEAR; MAGFILTER = LINEAR; MIPFILTER = LINEAR;
	ADDRESSU  = WRAP; ADDRESSV  = WRAP;
};


// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);


//-----------------------------------------------------------------------------
// ここから

#define HOLO_FILTER_LINEAR	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = LINEAR
#define HOLO_FILTER_POINT	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE

//メイン法線マップ
texture2D NormalMap < string ResourceName = NORMALMAP_FILENAME; >;
sampler NormalMapSampLinear = sampler_state {
	texture = <NormalMap>;
	HOLO_FILTER_LINEAR;
	AddressU = WRAP; AddressV = WRAP;
};
sampler NormalMapSampPoint = sampler_state {
	texture = <NormalMap>;
	HOLO_FILTER_POINT;
	AddressU = WRAP; AddressV = WRAP;
};

#if ENABLE_SUBNORMAL > 0
texture2D SubNormalMap < string ResourceName = SUBNORMALMAP_FILENAME; >;
sampler SubNormalMapSamp = sampler_state {
	texture = <SubNormalMap>;
	HOLO_FILTER_POINT;
	AddressU = WRAP; AddressV = WRAP;
};
#endif

#if ENABLE_HOLOMASK > 0
texture2D MaskMap < string ResourceName = MASKMAP_FILENAME; >;
sampler MaskMapSamp = sampler_state {
	texture = <MaskMap>;
	HOLO_FILTER_LINEAR;
	AddressU = WRAP; AddressV = WRAP;
};
float GetMaskValue(float2 uv) { return tex2D(MaskMapSamp, uv * MaskMapLoopNum).x; }
#else
float GetMaskValue(float2 uv) { return 1; }
#endif

float3x3 compute_tangent_frame(float3 Normal, float3 View, float2 UV)
{
	float3 vRx = ddx(View);
	float3 vRy = ddy(View);
	float2 duvdx = ddx(UV);
	float2 duvdy = ddy(UV);
	float3 Tangent = 0;//duvdx.x * vRx + duvdy.x * vRy;
	float3 Binormal = duvdx.y * vRx + duvdy.y * vRy;
	Tangent = normalize(cross(normalize(Binormal), Normal));
	Binormal = normalize(cross(Normal, Tangent));
	return float3x3(Tangent, Binormal, Normal);
}

float3 hsv2rgb(float3 c)
{
	float3 hcol = saturate((abs(frac(c.x + float3(3,2,1)/3)*6 - 3) - 1));
	return float3(lerp(1, hcol, c.y) * c.z);
}
float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), max(rgb,0));
}
float3 GetHoloColor(float u)
{
	float3 holoColor = hsv2rgb(float3(u * HoloGradient + HoloHueOffset, 1, 1));
	return lerp(rgb2gray(holoColor), holoColor, HoloSaturation);
		// hsvのsにHoloSaturationを入れても微妙
}

float4 ComputeHoloColor(float3 N, float3 V, float2 uv0)
{
	float3x3 tangentFrame = compute_tangent_frame(N, V, uv0);

	float2 uv = uv0 * NormalMapLoopNum;

	float4 NormalColor = tex2D( NormalMapSampPoint, uv);
	#if ENBALE_MIPMAP > 0
	// 補間された高さを使う
	NormalColor.w = max(NormalColor.z, tex2D( NormalMapSampLinear, uv).z);
	#else
	NormalColor.w = NormalColor.z;
	#endif
	NormalColor = NormalColor * 2 - 1;
	NormalColor.xy *= NormalMapHeightScale;

	#if ENABLE_SUBNORMAL > 0
	float2 uv2 = uv0 * SubNormalMapLoopNum;
	float4 SubNormalColor = tex2D( SubNormalMapSamp, uv2);
	SubNormalColor.xyz = SubNormalColor.xyz * 2 - 1;
	SubNormalColor.xyz *= SubNormalMapHeightScale;
	NormalColor.xyz += SubNormalColor.xyz; // NormalColor.w は減衰用の高さ情報
	#endif

	NormalColor.xyz = normalize(NormalColor.xyz);
	float3 T = mul(NormalColor.xyz, tangentFrame);

	float u = abs(dot(T, V));
	float3 baseColor = lerp(HoloGrandColor, HoloSkyColor, saturate(N.y * 0.5 + 0.5));
	float3 holoColor = GetHoloColor(u) * baseColor;
	holoColor *= lerp(1.0, LightSpecular, LightColorAware);	// ライト色の影響

	float mask = saturate(1 - NormalColor.w * NormalColor.w);
	mask *= GetMaskValue(uv0);
	float intensity = mask * HoloIntensity;
	intensity *= saturate(frac(u * 1.4) * 5); // for flickering
	holoColor *= intensity;
	return float4(holoColor, lerp(1, HoloAttenuation, mask));
}

// ここまで
//-----------------------------------------------------------------------------

float GetShadow(float4 ZCalcTex)
{
	float comp = 1;
	ZCalcTex /= ZCalcTex.w;
	float2 TransTexCoord = ZCalcTex.xy * float2(0.5, - 0.5) + 0.5;
	if( all( saturate(TransTexCoord) == TransTexCoord ) )
	{
		float shadow = max(ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f);
		float k = (parthf) ? SKII2 * TransTexCoord.y : SKII1;
		comp = 1 - saturate(shadow * k - 0.3f);
	}
	return comp;
}


//-----------------------------------------------------------------------------
// 輪郭描画

float4 ColorRender_VS(float4 Pos : POSITION) : POSITION
{
	return mul( Pos, WorldViewProjMatrix );
}

float4 ColorRender_PS() : COLOR
{
	return EdgeColor;
}

technique EdgeTec < string MMDPass = "edge"; > {
	pass DrawEdge {
		VertexShader = compile vs_2_0 ColorRender_VS();
		PixelShader  = compile ps_2_0 ColorRender_PS();
	}
}


//-----------------------------------------------------------------------------
// 影（非セルフシャドウ）描画

float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
	return mul( Pos, WorldViewProjMatrix );
}

float4 Shadow_PS() : COLOR
{
	return GroundShadowColor;
}

technique ShadowTec < string MMDPass = "shadow"; > {
	pass DrawShadow {
		VertexShader = compile vs_2_0 Shadow_VS();
		PixelShader  = compile ps_2_0 Shadow_PS();
	}
}


//-----------------------------------------------------------------------------
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
	float4 Pos : POSITION;				// 射影変換座標
	float4 ShadowMapTex : TEXCOORD0;	// Zバッファテクスチャ
};

VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION )
{
	VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;
	Out.Pos = mul( Pos, LightWorldViewProjMatrix );
	Out.ShadowMapTex = Out.Pos;

	return Out;
}

float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0 ) : COLOR
{
	return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

technique ZplotTec < string MMDPass = "zplot"; > {
	pass ZValuePlot {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 ZValuePlot_VS();
		PixelShader  = compile ps_2_0 ZValuePlot_PS();
	}
}


//-----------------------------------------------------------------------------
// オブジェクト描画

struct VS_OUTPUT {
	float4 Pos		: POSITION;	// 射影変換座標
	float4 ZCalcTex	: TEXCOORD0;	// Z値
	float2 Tex		: TEXCOORD1;	// テクスチャ
	float3 Normal	: TEXCOORD2;	// 法線
	float3 Eye		: TEXCOORD3;	// カメラとの相対位置
	float2 SpTex	: TEXCOORD4;		// スフィアマップテクスチャ座標
	float4 Color	: COLOR0;		// ディフューズ色
};


VS_OUTPUT Object_VS(
	float4 Pos : POSITION, float3 Normal : NORMAL,
	float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1,
	uniform bool useTexture, uniform bool useSphereMap,
	uniform bool useToon, uniform bool useSelfshadow)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Out.Pos = mul( Pos, WorldViewProjMatrix );
	Out.Eye = CameraPosition - mul( Pos, WorldMatrix ).xyz;
	Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

	if (useSelfshadow)
	{
		Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
	}

	// ディフューズ色＋アンビエント色 計算
	Out.Color.rgb = AmbientColor;
	Out.Color.a = DiffuseColor.a;
	Out.Color = saturate( Out.Color );

	Out.Tex = Tex;

	if ( useSphereMap ) {
		if ( use_subtexture ) {
			Out.SpTex = Tex2;
		} else {
			float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix ).xy;
			Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
			Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
		}
	}

	return Out;
}


float4 Object_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon, uniform bool useSelfshadow) : COLOR
{
	float3 N = normalize(IN.Normal);
	float3 V = normalize(IN.Eye);
	float3 H = normalize( V + -LightDirection );

	float diffuse = dot(N,-LightDirection);
	float3 specular = pow( saturate(dot( H, N )), SpecularPower ) * SpecularColor;
	float4 holoColor = ComputeHoloColor(N, V, IN.Tex);

	float4 Color = IN.Color;

	if ( !useToon )
	{
		Color.rgb += saturate(diffuse) * DiffuseColor.rgb;
	}
	Color = saturate( Color );

	float4 ShadowColor = float4(saturate(AmbientColor), Color.a);  // 影の色
	if ( useTexture )
	{
		float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
		TexColor.rgb = lerp(1, TexColor * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a);
		Color *= TexColor;
		ShadowColor *= TexColor;
	}

	if ( useSphereMap )
	{
		float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
		TexColor.rgb = lerp(spadd?0:1, TexColor * SphereMulValue + SphereAddValue, SphereMulValue.a + SphereAddValue.a);
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

	float comp = (useSelfshadow) ? GetShadow(IN.ZCalcTex) : 1;

	if ( useToon )
	{
		comp = min(saturate(diffuse * Toon), comp);
		ShadowColor.rgb *= MaterialToon;
	}

	// NOTE:
	// ハイライトにholoColor.aの影響を与えないためにここで処理している。
	// 気にしないなら、合成後に、ans.rgb = ans.rgb * ans.a + ans.rgb でよい。
	Color.rgb = Color.rgb * holoColor.a + holoColor.rgb;
	ShadowColor.rgb = ShadowColor.rgb * holoColor.a + holoColor.rgb;
	Color.rgb += specular;

	float4 ans = lerp(ShadowColor, Color, comp);

	return ans;
}


#define OBJECT_TEC(name, mmdpass, tex, sphere, toon, selfshadow) \
	technique name < string MMDPass = mmdpass; > { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 Object_VS(tex, sphere, toon, selfshadow); \
			PixelShader  = compile ps_3_0 Object_PS(tex, sphere, toon, selfshadow); \
		} \
	}

OBJECT_TEC(MainTec0, "object", use_texture, use_spheremap, use_toon, false)
OBJECT_TEC(MainTecBS0, "object_ss", use_texture, use_spheremap, use_toon, true)


//-----------------------------------------------------------------------------
