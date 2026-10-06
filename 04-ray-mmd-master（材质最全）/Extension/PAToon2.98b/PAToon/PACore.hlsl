///////////////////////////////////////////////////////////////////
//PACore.hlsl (PAToon 無印+Key+Lite統合 RTは別）
//
//HACore.hlsl(v13), HAHead.hlsl, HgShadowObjHeader.fxh, DirectionalSphere, 法線回転処理, EdgeControlを含む。
//切り貼りは明示してあるが全体に長く汚いので要注意
//
//by P.I.P
//
///////////////////////////////////////////////////////////////////



float3 ExLightDirectionRoot: CONTROLOBJECT < string name = "ExShadowｺﾝﾄﾛｰﾗｰ.pmx"; string item = "照明方向 XYZ"; >;
float3 HgLightDirectionRoot: CONTROLOBJECT < string name = "HgShadowｺﾝﾄﾛｰﾗｰ.pmx"; string item = "照明方向 XYZ"; >;

float3 ExLightDirectionShader: CONTROLOBJECT < string name = "ExShadowｺﾝﾄﾛｰﾗｰ.pmx"; string item = "シェーダー"; >;
float3 HgLightDirectionShader: CONTROLOBJECT < string name = "HgShadowｺﾝﾄﾛｰﾗｰ.pmx"; string item = "シェーダー"; >;


static float3 ExLightDirection = ExLightDirectionRoot + ExLightDirectionShader;
static float3 HgLightDirection = HgLightDirectionRoot + HgLightDirectionShader;


//パラメータ宣言
float4x4	WorldViewProjMatrix	: WORLDVIEWPROJECTION;
float4x4	WorldMatrix			: WORLD;
float4x4	ViewMatrix			: VIEW;
float4x4	ProjMatrix			: PROJECTION;
float3		CameraPosition		: POSITION		< string Object = "Camera"; >;

float4		MaterialDiffuse		: DIFFUSE		< string Object = "Geometry"; >;
float3		MaterialAmbient		: AMBIENT		< string Object = "Geometry"; >;
float3		MaterialEmmisive	: EMISSIVE		< string Object = "Geometry"; >;
float3		MaterialSpecular	: SPECULAR		< string Object = "Geometry"; >;
float		SpecularPower		: SPECULARPOWER	< string Object = "Geometry"; >;
float3		MaterialToon		: TOONCOLOR;
float4		EdgeColorModel		: EDGECOLOR;

float4		AddingTexture		: ADDINGTEXTURE;
float4		MultiplyTexture		: MULTIPLYINGTEXTURE;

#ifdef MIKUMIKUMOVING

float4		AddingSphere		: ADDINGSPHERE;
float4		MultiplySphere		: MULTIPLYINGSPHERE;

#else

float4		AddingSphere		: ADDINGSPHERETEXTURE;
float4		MultiplySphere		: MULTIPLYINGSPHERETEXTURE;


#endif


//ハンドルエッジ用フラグの取得と処理
static float EdgeFlag1a = (frac(SpecularPower * 1000) >= 0.09f);
static float EdgeFlag2 = frac(SpecularPower * 1000) >= 0.19f;
static float EdgeFlag1 = EdgeFlag1a - EdgeFlag2;

static float3 EdgeColorSpecular = (frac(MaterialSpecular * 1000) * EdgeFlag2) * HandleEdgeSettingON.r;
static float EdgeAlphaEmmisive = (1- EdgeFlag1) * ((frac(MaterialEmmisive.r * 100)*10 * EdgeFlag2 *  HandleEdgeSettingON.g) + (1 - (EdgeFlag1 * EdgeFlag2)) * HandleEdgeSettingON.g + (1 - HandleEdgeSettingON.g));
static float EdgeWidthEmmisive =  (1 - EdgeFlag1) * ((((EdgeFlag2 * frac(MaterialEmmisive.g * 100)*10) + (1 - EdgeFlag2)) * HandleEdgeSettingON.b) + (1- HandleEdgeSettingON.b)) * PAEdgeWidth;

static float3 MaterialEmmisive1 = ( MaterialEmmisive - AddingTexture )* (1 / MultiplyTexture) ;

#ifdef FLAGCOLOROFFF
//色調オフのフラグ設定
static bool ColorOff = 1 - ( abs(frac(MaterialEmmisive1.b*100) - 0.39) < 0.001f );
#else
bool ColorOff = 1;
#endif


////////////////////////////////////////////////////////
////////////////////////////////////////////////////////


// 色調のためのコントローラー設定

float3 BlendDiffuseTextureRgbAddC0 : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "影 RGB"; >;
float3 BlendDiffuseTextureHsvAddC0 : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "影 HSV"; >;

#ifdef ADDMATERIALCOLOR
static float3 BlendDiffuseTextureRgbAddC1 = BlendDiffuseTextureRgbAddC0 + AddMaterialRgb*10;
static float3 BlendDiffuseTextureHsvAddC1 = BlendDiffuseTextureHsvAddC0 + AddMaterialHsv*10;
#else
static float3 BlendDiffuseTextureRgbAddC1 = BlendDiffuseTextureRgbAddC0;
static float3 BlendDiffuseTextureHsvAddC1 = BlendDiffuseTextureHsvAddC0;
#endif

#ifdef ADDTOONCOLOR
static float3 BlendDiffuseTextureRgbAddC = BlendDiffuseTextureRgbAddC1 + AddToonRgb*10;
static float3 BlendDiffuseTextureHsvAddC = BlendDiffuseTextureHsvAddC1 + AddToonHsv*10;
#else
static float3 BlendDiffuseTextureRgbAddC = BlendDiffuseTextureRgbAddC1;
static float3 BlendDiffuseTextureHsvAddC = BlendDiffuseTextureHsvAddC1;
#endif

float3 EdgeColorM : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "エッジ RGB"; >;
float3 EdgeColorHsvM : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "エッジ HSV"; >;


float3 BlendDiffuseTextureRgbAddM : CONTROLOBJECT < string name = "(self)"; string item = "影 RGB"; >;
float3 BlendDiffuseTextureHsvAddM : CONTROLOBJECT < string name = "(self)"; string item = "影 HSV"; >;

float3 EdgeColorC : CONTROLOBJECT < string name = "(self)"; string item = "エッジ RGB"; >;
float3 EdgeColorHsvC : CONTROLOBJECT < string name = "(self)"; string item = "エッジ HSV"; >;


static float3 BlendDiffuseTextureRgbAdd = (BlendDiffuseTextureRgbAddM + BlendDiffuseTextureRgbAddC) * ColorOff;
static float3 BlendDiffuseTextureHsvAdd = (BlendDiffuseTextureHsvAddM + BlendDiffuseTextureHsvAddC) * ColorOff;

static float3 EdgeColorController = (EdgeColorM + EdgeColorC)/10;


float3 BlendDiffuseMaterialTextureRgbAddC0 : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "光 RGB"; >;
float3 BlendDiffuseMaterialTextureHsvAddC0 : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "光 HSV"; >;

#ifdef ADDMATERIALCOLOR
static float3 BlendDiffuseMaterialTextureRgbAddC = BlendDiffuseMaterialTextureRgbAddC0 + AddMaterialRgb*10;
static float3 BlendDiffuseMaterialTextureHsvAddC = BlendDiffuseMaterialTextureHsvAddC0 + AddMaterialHsv*10;
#else
static float3 BlendDiffuseMaterialTextureRgbAddC = BlendDiffuseMaterialTextureRgbAddC0;
static float3 BlendDiffuseMaterialTextureHsvAddC = BlendDiffuseMaterialTextureHsvAddC0;
#endif


float3 BlendDiffuseMaterialTextureRgbAddM : CONTROLOBJECT < string name = "(self)"; string item = "光 RGB"; >;
float3 BlendDiffuseMaterialTextureHsvAddM : CONTROLOBJECT < string name = "(self)"; string item = "光 HSV"; >;

#ifdef ADDMATERIAL
static float3 BlendDiffuseMaterialTextureRgbAdd = BlendDiffuseMaterialTextureRgbAddM + BlendDiffuseMaterialTextureRgbAddC + AddMaterialRgb*10;
static float3 BlendDiffuseMaterialTextureHsvAdd = BlendDiffuseMaterialTextureHsvAddM + BlendDiffuseMaterialTextureHsvAddC;
#else
static float3 BlendDiffuseMaterialTextureRgbAdd = (BlendDiffuseMaterialTextureRgbAddM + BlendDiffuseMaterialTextureRgbAddC) * ColorOff;
static float3 BlendDiffuseMaterialTextureHsvAdd = (BlendDiffuseMaterialTextureHsvAddM + BlendDiffuseMaterialTextureHsvAddC) * ColorOff;
#endif

float EdgeThick1C : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "エッジ細"; >;
float EdgeThick2C : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "エッジ太"; >;
float EdgeAlphaC : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "エッジ透明"; >;

float EdgeThick1M : CONTROLOBJECT < string name = "(self)"; string item = "エッジ細"; >;
float EdgeThick2M : CONTROLOBJECT < string name = "(self)"; string item = "エッジ太"; >;
float EdgeAlphaM : CONTROLOBJECT < string name = "(self)"; string item = "エッジ透明"; >;

static float EdgeThickness = (1 + EdgeThick2C +EdgeThick2M) * (1 - EdgeThick1C) * (1 - EdgeThick1M);
static float EdgeAlpha = (1-EdgeAlphaC) * (1-EdgeAlphaM);

//static float4 EdgeColor = float4(EdgeColorModel.rgb + EdgeColorController, EdgeColorModel.a * EdgeAlpha);


float ShadingBiasPowerModelPlus   : CONTROLOBJECT < string name = "(self)";  string item = "影傾向＋"; >;
float ShadingBiasPowerModelMinus  : CONTROLOBJECT < string name = "(self)";  string item = "影傾向－"; >;

float ShadingBiasPowerCtrlPlus    : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "影傾向＋"; >;
float ShadingBiasPowerCtrlMinus   : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "影傾向－"; >;

static float ShadingBiasPowerMorph = ShadingBiasPowerModelPlus + ShadingBiasPowerCtrlPlus - ShadingBiasPowerModelMinus - ShadingBiasPowerCtrlMinus;

static float ShadingBiasPower = (1 + ShadingBiasPowerMorph) * SetShadingBiasPower;


//法線回転のためのコントローラー設定

float4x4 BoneMatrixAA : CONTROLOBJECT < string name = "(self)"; string item = "シェーダー"; >;
float4x4 BoneMatrixBA : CONTROLOBJECT < string name = "(self)"; string item = "スフィア"; >;

float4x4 BoneMatrixAB : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "シェーダー"; >;
float4x4 BoneMatrixBB : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "スフィア"; >;

static float4x4 BoneMatrixA = mul(BoneMatrixAA, BoneMatrixAB);
static float4x4 BoneMatrixB = mul(BoneMatrixBA, BoneMatrixBB);

//地面影色のためのコントローラー設定
float4 GroundShadowColorA : CONTROLOBJECT < string name = "(self)"; string item = "地面影 RGB"; >;
float4 GroundShadowColorB : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "地面影 RGB"; >;

float GroundShadowAlphaM : CONTROLOBJECT < string name = "(self)"; string item = "地面影透明"; >;
float GroundShadowAlphaC : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "地面影透明"; >;
static float GroundShadowAlpha = (1-GroundShadowAlphaM) * (1-GroundShadowAlphaC);

float4 GroundShadowColorHsvA : CONTROLOBJECT < string name = "(self)"; string item = "地面影 HSV"; >;
float4 GroundShadowColorHsvB : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "地面影 HSV"; >;





////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// HAHead.hlsl
// ここから ↓
////////////////////////////////////////////////////////////////////////////////


//テクスチャを読み込むためのコード
#define DEFINE_TEXTURE_SAMPLER(textureName, samplerName, resourceName, uMode, vMode) \
	texture2D textureName < string ResourceName = resourceName; >; \
	sampler samplerName = sampler_state \
	{ \
		Texture = <textureName>; \
		Filter = Anisotropic; \
		AddressU = uMode; \
		AddressV = vMode; \
		MaxAnisotropy = 16; \
	};

static float NanAsZero(float value)
{
	return isnan(value) ? 0 : value;
}

static float3 GetHsvFromRgb(float3 rgb)
{
	float maxValue = max(max(rgb.r, rgb.g), rgb.b);
	float minValue = min(min(rgb.r, rgb.g), rgb.b);
	float delta = maxValue - minValue;
	float3 hsv = float3(0, 0, maxValue);

	if (delta != 0)
	{
		hsv.y = delta / maxValue;

		if (maxValue <= rgb.r)
			hsv.x = (rgb.g - rgb.b) / delta;
		else if (maxValue <= rgb.g)
			hsv.x = 2 + (rgb.b - rgb.r) / delta;
		else if (maxValue <= rgb.b)
			hsv.x = 4 + (rgb.r - rgb.g) / delta;

		hsv.x /= 6;
	}
	
	return hsv;
}

static float3 GetRgbFromHsv(float3 hsv)
{
	if (hsv.y == 0)
		return float3(hsv.z, hsv.z, hsv.z);
	else
	{
		if (hsv.x < 0)
			hsv.x += 1;
	
		hsv.yz = saturate(hsv.yz);

		float c = hsv.z * hsv.y;
		float x = c * (1 - abs(hsv.x * 6 % 2 - 1));
		float i = floor(hsv.x * 6) % 6;
		float m = hsv.z - c;

		c += m;
		x += m;

		if (i < 1)
			return float3(c, x, m);
		else if (i < 2)
			return float3(x, c, m);
		else if (i < 3)
			return float3(m, c, x);
		else if (i < 4)
			return float3(m, x, c);
		else if (i < 5)
			return float3(x, m, c);
		else
			return float3(c, m, x);
	}
}

struct BlendParameters
{
	float LightNormal;
	float ExtendedLightNormal;
	float ViewNormal;
	float HalfVectorNormal;
	float SpecularValue;
	float2 TextureCoordinate;
	float2 ScreenCoordinate;
	float3 ToonValue;
};


static float3 EdgeColorRgbS = EdgeColorModel + EdgeColorController;
static float3 EdgeColorHsvS = GetHsvFromRgb(EdgeColorRgbS) + EdgeColorHsvM/10 +EdgeColorHsvC/10;
static float4 EdgeColor = float4( GetRgbFromHsv(EdgeColorHsvS), EdgeColorModel.a * EdgeAlpha);



static float3 HandleEdgeColorRgbS = EdgeColorSpecular + EdgeColorController;
static float3 HandleEdgeColorHsvS = GetHsvFromRgb(HandleEdgeColorRgbS) + EdgeColorHsvM/10 +EdgeColorHsvC/10;
static float3 HandleEdgeColor = GetRgbFromHsv(HandleEdgeColorHsvS);

static float HandleEdgeAlpha = EdgeAlphaEmmisive * EdgeAlpha;




////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// HAHead.hlsl
// ここまで ↑
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
//HAToon2の～.fx計算部分（テクスチャブレンド）
////////////////////////////////////////////////////////////////////////////////


#ifdef BLENDDIFFUSE0TEXTURE
DEFINE_TEXTURE_SAMPLER(BlendDiffuse0Texture, BlendDiffuse0TextureSampler, BLENDDIFFUSE0TEXTURE, Clamp, Clamp)
#endif
#ifdef BLENDDIFFUSE1TEXTURE
DEFINE_TEXTURE_SAMPLER(BlendDiffuse1Texture, BlendDiffuse1TextureSampler, BLENDDIFFUSE1TEXTURE, Clamp, Clamp)
#endif
#ifdef BLENDDIFFUSE2TEXTURE
DEFINE_TEXTURE_SAMPLER(BlendDiffuse2Texture, BlendDiffuse2TextureSampler, BLENDDIFFUSE2TEXTURE, Clamp, Clamp)
#endif
#ifdef BLENDDIFFUSE3TEXTURE
DEFINE_TEXTURE_SAMPLER(BlendDiffuse3Texture, BlendDiffuse3TextureSampler, BLENDDIFFUSE3TEXTURE, Clamp, Clamp)
#endif
#ifdef BLENDSPECULAR0TEXTURE
DEFINE_TEXTURE_SAMPLER(BlendSpecular0Texture, BlendSpecular0TextureSampler, BLENDSPECULAR0TEXTURE, Clamp, Clamp)
#endif
#ifdef BLENDADDSPHERE1TEXTURE
DEFINE_TEXTURE_SAMPLER(BlendAddSphere1Texture, BlendAddSphere1TextureSampler, BLENDADDSPHERE1TEXTURE, Clamp, Clamp)
#endif

#ifdef BLENDDIFFUSESHADOWTEXTURE
DEFINE_TEXTURE_SAMPLER(BlendDiffuseShadowTexture, BlendDiffuseShadowTextureSampler, BLENDDIFFUSESHADOWTEXTURE, Clamp, Clamp)
#endif
#ifdef BLENDDIFFUSEMATERIALTEXTURE
DEFINE_TEXTURE_SAMPLER(BlendDiffuseMaterialTexture, BlendDiffuseMaterialTextureSampler, BLENDDIFFUSEMATERIALTEXTURE, Clamp, Clamp)
#endif



#ifdef MODEL_TOON
float3 ObjToonTexture : ToonColor;
static float4 ObjToonColor = float4(ObjToonTexture, 1);
static float4 ObjPAToonColor = tex2D(BlendDiffuse2TextureSampler, float2(0,1));
static float4 ToonColorSa = (ObjToonColor - ObjPAToonColor) ;
#endif


float EdgeWidthRate
<
	string UIName = "エッジ幅";
	string UIWidget = "Numeric";
	float UIMin = 0;
	float UIMax = 2;
> = 1;


float3 BlendDiffuse0(float3 target, BlendParameters parameters)
{
	#ifdef BLENDDIFFUSE0TEXTURE
	float3 targetHsv = GetHsvFromRgb(target);
	float4 value = tex2D(BlendDiffuse0TextureSampler, float2(parameters.LightNormal, targetHsv.x));
	
	value.rgb = GetHsvFromRgb(value.rgb);
	targetHsv.x = lerp(targetHsv.x, value.r, value.a);
	target = GetRgbFromHsv(targetHsv);
	#endif
	
	return target;
}

float3 BlendDiffuse1(float3 target, BlendParameters parameters)
{
	#ifdef BLENDDIFFUSE1TEXTURE
	float3 targetHsv = GetHsvFromRgb(target);
	float4 value = tex2D(BlendDiffuse1TextureSampler, float2(parameters.LightNormal, targetHsv.y));
	
	target.r = lerp(target.r, target.r * value.r, value.a);
	target.g = lerp(target.g, target.g * value.g, value.a);
	target.b = lerp(target.b, target.b * value.b, value.a);
	#endif
	
	return target;
}

float3 BlendDiffuse2(float3 target, BlendParameters parameters)
{
	#ifdef BLENDDIFFUSE2TEXTURE
	float4 value = tex2D(BlendDiffuse2TextureSampler, float2(parameters.LightNormal, parameters.ViewNormal));
	
	target.r = lerp(target.r, target.r * value.r, value.a);
	target.g = lerp(target.g, target.g * value.g, value.a);
	target.b = lerp(target.b, target.b * value.b, value.a);
	#endif
	
	return target;
}

float3 BlendDiffuse3(float3 target, BlendParameters parameters)
{
	#ifdef BLENDDIFFUSE3TEXTURE
	float4 value = tex2D(BlendDiffuse3TextureSampler, float2(parameters.LightNormal, parameters.ViewNormal));
	
	target.r += value.r * value.a;
	target.g += value.g * value.a;
	target.b += value.b * value.a;
	#endif
	
	return target;
}

float3 BlendDiffuseShadow(float3 target, BlendParameters parameters)
{
	#ifdef BLENDDIFFUSESHADOWTEXTURE	
	float4 value = tex2D(BlendDiffuseShadowTextureSampler, float2(parameters.LightNormal, parameters.ViewNormal));
    #else
	float toon = parameters.LightNormal<0.25;
	float4 value = float4(toon, toon, toon, 1);
    #endif

          #ifdef MODEL_TOON
	      static float3 BlendDiffuseTextureRgbAdd1 = BlendDiffuseTextureRgbAdd + ToonColorSa * 10 ;
          #else
          static float3 BlendDiffuseTextureRgbAdd1 = BlendDiffuseTextureRgbAdd;
          #endif	
	
		
	if (BlendDiffuseTextureRgbAdd1.r != 0 ||
		BlendDiffuseTextureRgbAdd1.g != 0 ||
		BlendDiffuseTextureRgbAdd1.b != 0)
		target += BlendDiffuseTextureRgbAdd1 / 10 * value.rgb * value.a;
	
	if (BlendDiffuseTextureHsvAdd.r != 0 ||
		BlendDiffuseTextureHsvAdd.g != 0 ||
		BlendDiffuseTextureHsvAdd.b != 0)
		target = lerp(target, GetRgbFromHsv(GetHsvFromRgb(target) + BlendDiffuseTextureHsvAdd / 10), value.r * value.a);
	


	
	return target;
}

float3 BlendDiffuseMaterial(float3 target, BlendParameters parameters)
{


	
	#ifdef BLENDDIFFUSEMATERIALTEXTURE
	float4 value = tex2D(BlendDiffuseMaterialTextureSampler, float2(parameters.LightNormal, parameters.ViewNormal));
	
	//float4 value = tex2D(BlendDiffuseShadowTextureSampler, float2(parameters.LightNormal, parameters.ViewNormal));
	//value.rgb =  float3(1,1,1) - value.rgb;  //マスクテクスチャを1枚で済ませる場合の反転（使わない）
	
	#else
	float toon = parameters.LightNormal>0.25;
	float4 value = float4(toon, toon, toon, 1);
	#endif
	
		
	if (BlendDiffuseMaterialTextureRgbAdd.r != 0 ||
		BlendDiffuseMaterialTextureRgbAdd.g != 0 ||
		BlendDiffuseMaterialTextureRgbAdd.b != 0)
		target += BlendDiffuseMaterialTextureRgbAdd / 10 * value.rgb * value.a;
		
	if (BlendDiffuseMaterialTextureHsvAdd.r != 0 ||
		BlendDiffuseMaterialTextureHsvAdd.g != 0 ||
		BlendDiffuseMaterialTextureHsvAdd.b != 0)
		target = lerp(target, GetRgbFromHsv(GetHsvFromRgb(target) + BlendDiffuseMaterialTextureHsvAdd / 10), value.r * value.a);
	
	return target;
}



float3 BlendDiffuse(float3 color, BlendParameters parameters)
{
	color = BlendDiffuse0(color, parameters);
	color = BlendDiffuse1(color, parameters);
	color = BlendDiffuse2(color, parameters);
	color = BlendDiffuse3(color, parameters);
	color = BlendDiffuseShadow(color, parameters);
    color = BlendDiffuseMaterial(color, parameters);

	return color;
}


float3 BlendSpecular0(float3 target, BlendParameters parameters)
{
	#ifdef BLENDSPECULAR0TEXTURE
	float4 value = tex2D(BlendSpecular0TextureSampler, float2(parameters.SpecularValue, parameters.ViewNormal));
	
	target.r = lerp(target.r, target.r * value.r, value.a);
	target.g = lerp(target.g, target.g * value.g, value.a);
	target.b = lerp(target.b, target.b * value.b, value.a);
	#endif
	
	return target;
}

float3 BlendSpecular1(float3 target, BlendParameters parameters)
{
	#ifdef BLENDSPECULAR1TEXTURE
	float4 value = float4(0, 0, 0, 1);
	
	target.r = lerp(target.r, target.r * value.r, value.a);
	target.g = lerp(target.g, target.g * value.g, value.a);
	target.b = lerp(target.b, target.b * value.b, value.a);
	#endif
	
	return target;
}

float3 BlendSpecular(float3 color, BlendParameters parameters)
{
	color = BlendSpecular0(color, parameters);
	color = BlendSpecular1(color, parameters);

	return color;
}

float3 BlendAddSphere0(float3 target, BlendParameters parameters)
{
	#ifdef BLENDADDSPHERE0TEXTURE
	float4 value = float4(parameters.ViewNormal, parameters.ViewNormal, parameters.ViewNormal, 1);
	
	target.r = lerp(target.r, target.r * value.r, value.a);
	target.g = lerp(target.g, target.g * value.g, value.a);
	target.b = lerp(target.b, target.b * value.b, value.a);
	#endif
	
	return target;
}

float3 BlendAddSphere1(float3 target, BlendParameters parameters)
{
	#ifdef BLENDADDSPHERE1TEXTURE
	float3 targetHsv = GetHsvFromRgb(target);
	float4 value = tex2D(BlendAddSphere1TextureSampler, float2(targetHsv.z, 0));
	
	target.r = lerp(target.r, value.r, value.a);
	target.g = lerp(target.g, value.g, value.a);
	target.b = lerp(target.b, value.b, value.a);
	#endif
	
	return target;
}

float3 BlendAddSphere2(float3 target, BlendParameters parameters)
{
	#ifdef BLENDADDSPHERE2TEXTURE
	float4 value = float4(0, 0, 0, 1);
	
	target.r = lerp(target.r, target.r * value.r, value.a);
	target.g = lerp(target.g, target.g * value.g, value.a);
	target.b = lerp(target.b, target.b * value.b, value.a);
	#endif
	
	return target;
}

float3 BlendAddSphere(float3 color, BlendParameters parameters)
{
	color = BlendAddSphere0(color, parameters);
	color = BlendAddSphere1(color, parameters);
	color = BlendAddSphere2(color, parameters);

	return color;
}
////////////////////////////////////////////////////////////
//エッジ色用の書き換え

float3 BlendEdge0(float3 target, BlendParameters parameters)
{
	#ifdef BLENDEDGE0TEXTURE
	float4 value = float4(0, 0, 0, 1);
	
	target.r = lerp(target.r, target.r * value.r, value.a) + EdgeColorController.x;
	target.g = lerp(target.g, target.g * value.g, value.a) + EdgeColorController.y;
	target.b = lerp(target.b, target.b * value.b, value.a) + EdgeColorController.z;
	#endif
	
	return target;
}

float3 BlendEdge(float3 color, BlendParameters parameters)
{
	color = BlendEdge0(color, parameters);

	return color;
}
///////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
//
//  HgShadow_ObjHeader.fxh : HgShadow オブジェクト影描画に必要な基本パラメータ定義ヘッダファイル
//  ここのパラメータをシェーダエフェクトファイルで #include して使用します。
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////

//HgShadowフラグの判定

#ifdef USE_HGSHADOW

// パラメータ宣言

// 制御パラメータ
#define HgShadow_CTRLFILENAME  "HgShadow.x"
bool HgShadow_Valid  : CONTROLOBJECT < string name = HgShadow_CTRLFILENAME; >;

float HgShadow_DensityUp   : CONTROLOBJECT < string name = "(self)"; string item = "ShadowDen+"; >;
float HgShadow_DensityDown : CONTROLOBJECT < string name = "(self)"; string item = "ShadowDen-"; >;

#ifndef MIKUMIKUMOVING

float HgShadow_AcsRx : CONTROLOBJECT < string name = HgShadow_CTRLFILENAME; string item = "Rx"; >;
float HgShadow_ObjTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
static float HgShadow_Density = max((degrees(HgShadow_AcsRx) + 5.0f*HgShadow_DensityUp + 1.0f)*(1.0f - HgShadow_DensityDown), 0.0f);

#else

shared float HgShadow_MMM_Density;
static float HgShadow_Density = max((HgShadow_MMM_Density + 5.0f*HgShadow_DensityUp)*(1.0f - HgShadow_DensityDown), 0.0f);

#endif


// 影生成描画結果を記録するためのレンダーターゲット
shared texture2D HgShadow_ViewportMap2 : RENDERCOLORTARGET;
sampler2D HgShadow_ViewportMapSamp = sampler_state {
    texture = <HgShadow_ViewportMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


// スクリーンサイズ
float2 HgShadow_ViewportSize : VIEWPORTPIXELSIZE;
static float2 HgShadow_ViewportOffset = (float2(0.5,0.5)/HgShadow_ViewportSize);


// セルフシャドウの遮蔽率を求める
float HgShadow_GetSelfShadowRate(float4 PPos)
{
    // スクリーンの座標
    float2 texCoord = float2( ( PPos.x/PPos.w + 1.0f ) * 0.5f,
                              1.0f - ( PPos.y/PPos.w + 1.0f ) * 0.5f ) + HgShadow_ViewportOffset;

    // 遮蔽率
    float comp = 1.0f - tex2Dlod( HgShadow_ViewportMapSamp, float4(texCoord, 0, 0) ).r;

    return (1.0f-(1.0f-comp) * min(HgShadow_Density, 1.0f));
}


struct HgShadow_COLOR {
    float4 Color;        // オブジェクト色
    float4 ShadowColor;  // 影色
};


// 影色に濃度を加味する
HgShadow_COLOR HgShadow_GetShadowDensity(float4 Color, float4 ShadowColor, bool useToon, float LightNormal)
{
    HgShadow_COLOR Out;
    Out.Color = Color;
    Out.ShadowColor = ShadowColor;

    if( !useToon || length(Color.rgb-ShadowColor.rgb) > 0.01f ){
        float e = max(HgShadow_Density, 1.0f);
        float a = 1.0f / e;
        float b = 1.0f - smoothstep(3.0f, 6.0f, e);
        float3 color = lerp(ShadowColor.rgb*a, ShadowColor.rgb*b, pow(ShadowColor.rgb, e));
        Out.ShadowColor = float4(saturate(color), ShadowColor.a);
    }
    if( !useToon ){
        float e = lerp( max(HgShadow_Density, 1.0f), 1.0f, smoothstep(0.0f, 0.4f, LightNormal) );
        float a = 1.0f / e;
        float b = 1.0f - smoothstep(3.0f, 6.0f, e);
        float3 color = lerp(Color.rgb*a, Color.rgb*b, pow(Color.rgb, e));
        Out.Color = float4(saturate(color), Color.a);
        #ifndef MIKUMIKUMOVING
        Out.Color.a *= HgShadow_ObjTr;
        Out.ShadowColor.a *= HgShadow_ObjTr;
        #endif
    }

    return Out;
}

#endif

/////////////////////////////////////////////////////////////////////////////////////////////////
//HgShadow_ObjHeader.fxh  ↑ここまで
/////////////////////////////////////////////////////////////////////////////////////////////////


#ifdef USE_LOCALSHADOW  // LocalShadow_Header


////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
//
//  LocalShadow_Header1.fxh : LocalShadow(モデル組み込み版) 作成: 針金P
//
//  ※パラメーター設定はこのファイルの冒頭に移動しています。 by P.I.P
//
////////////////////////////////////////////////////////////////////////////////////////////////



// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ定義

//コントローラー用

float3   LocalShadow_BonePosC     : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "セルフ影"; >;
float4x4 LocalShadow_BoneMatrixC  : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "セルフ影"; >;

float    LocalShadow_MorphLtSyncC : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "Lt陰影連動"; >;

float LocalShadow_MorphSize1C    : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "範囲縮小"; >;
float LocalShadow_MorphSize2C    : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "範囲拡大"; >;
float LocalShadow_MorphSize2XC   : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "X範囲拡大"; >;
float LocalShadow_MorphSize2YC   : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "Y範囲拡大"; >;


float LocalShadow_MorphDist1C    : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "距離近"; >;
float LocalShadow_MorphDist2C    : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "距離遠"; >;

float LocalShadow_MorphLtCtrlC   : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "Lt影濃調整"; >;


// モデル埋め込みパラメータ
float3   LocalShadow_BonePosM     : CONTROLOBJECT < string name = "(self)"; string item = "セルフ影"; >;
float4x4 LocalShadow_BoneMatrixM  : CONTROLOBJECT < string name = "(self)"; string item = "セルフ影"; >;
float    LocalShadow_MorphLtSyncM : CONTROLOBJECT < string name = "(self)"; string item = "Lt陰影連動"; >;

float LocalShadow_MorphSize1M    : CONTROLOBJECT < string name = "(self)"; string item = "範囲縮小"; >;
float LocalShadow_MorphSize2M    : CONTROLOBJECT < string name = "(self)"; string item = "範囲拡大"; >;
float LocalShadow_MorphSize2XM   : CONTROLOBJECT < string name = "(self)"; string item = "X範囲拡大"; >;
float LocalShadow_MorphSize2YM   : CONTROLOBJECT < string name = "(self)"; string item = "Y範囲拡大"; >;


float LocalShadow_MorphDist1M    : CONTROLOBJECT < string name = "(self)"; string item = "距離近"; >;
float LocalShadow_MorphDist2M    : CONTROLOBJECT < string name = "(self)"; string item = "距離遠"; >;

float LocalShadow_MorphLtCtrlM   : CONTROLOBJECT < string name = "(self)"; string item = "Lt影濃調整"; >;



//パラメータの合算

static float3   LocalShadow_BonePos    = LocalShadow_BonePosC + LocalShadow_BonePosM;
static float4x4 LocalShadow_BoneMatrix = mul(LocalShadow_BoneMatrixC, LocalShadow_BoneMatrixM);

static float    LocalShadow_MorphLtSync = LocalShadow_MorphLtSyncC + LocalShadow_MorphLtSyncM;

static float LocalShadow_MorphSize1  = LocalShadow_MorphSize1C + LocalShadow_MorphSize1M;
static float LocalShadow_MorphSize2  = LocalShadow_MorphSize2C + LocalShadow_MorphSize2M;
static float LocalShadow_MorphSize2X = LocalShadow_MorphSize2XC + LocalShadow_MorphSize2XM;
static float LocalShadow_MorphSize2Y = LocalShadow_MorphSize2YC + LocalShadow_MorphSize2YM;


static float LocalShadow_MorphDist1  = LocalShadow_MorphDist1C + LocalShadow_MorphDist1M;
static float LocalShadow_MorphDist2  = LocalShadow_MorphDist2C +  LocalShadow_MorphDist2M;

static float LocalShadow_MorphLtCtrl = LocalShadow_MorphLtCtrlC + LocalShadow_MorphLtCtrlM;
static float LocalShadow_ObjTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

// クォータニオンの積算
float4 LocalShadow_MulQuat(float4 q1, float4 q2)
{
   return float4(cross(q1.xyz, q2.xyz)+q1.xyz*q2.w+q2.xyz*q1.w, q1.w*q2.w-dot(q1.xyz, q2.xyz));
}

// クォータニオンの回転
float3 LocalShadow_RotQuat(float3 v1, float3 v2, float3 pos)
{
   float3 s = cross(v2, v1);
   if( !any(s) ) s = float3(1,0,0);
   float3 v = normalize( s );
   float rot = acos( dot(v1, v2) );
   float sinHD = sin(0.5f * rot);
   float cosHD = cos(0.5f * rot);
   float4 q1 = float4(v*sinHD, cosHD);
   float4 q2 = float4(-v*sinHD, cosHD);
   float4 q = LocalShadow_MulQuat( LocalShadow_MulQuat(q2, float4(pos, 0.0f)), q1);

   return q.xyz;
}

// ライト方向(エフェクト設定方向)
float3 LocalShadow_LtDirection : DIRECTION < string Object = "Light"; >;
static float3 LocalShadow_LtCtrlDir = LocalShadow_RotQuat(float3(0,0.0001,1), normalize(LocalShadow_BoneMatrix._31_32_33), normalize(LS_InitDirection));
static float  LocalShadow_MorphLtSync1 = lerp(LS_LightSyncShade, 1.0f, LocalShadow_MorphLtSync);
static float  LocalShadow_MorphLtSync2 = lerp(LS_LightSyncShadow, 1.0f, LocalShadow_MorphLtSync);
static float3 LocalShadow_LightDirection = normalize(lerp(LocalShadow_LtCtrlDir, LocalShadow_LtDirection, LocalShadow_MorphLtSync2));

// ライト距離
static float LocalShadow_Distance = 15.0f - 14.0f*LocalShadow_MorphDist1 + 85.0f*LocalShadow_MorphDist2;


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 座標変換行列

// ライト方向のビュー変換行列
float4x4 LocalShadow_LightViewMatrix()
{
   // z軸方向ベクトル
   float3 viewZ = LocalShadow_LightDirection;

   // x軸方向ベクトル
   float3 viewX = cross( LocalShadow_BoneMatrix._21_22_23, LocalShadow_LightDirection ); 

   // x軸方向ベクトルの正規化(LookDirとLookUpDirの方向が一致する場合は特異値となる)
   if( !any(viewX) ) viewX = LocalShadow_BoneMatrix._11_21_31;
   viewX = normalize(viewX);

   // y軸方向ベクトル
   float3 viewY = cross( viewZ, viewX );  // 共に垂直なのでこれで正規化

   // ビュー座標変換の回転行列
   float3x3 ltViewRot = float3x3( viewX.x, viewY.x, viewZ.x,
                                  viewX.y, viewY.y, viewZ.y,
                                  viewX.z, viewY.z, viewZ.z );

   // 仮の光源位置
   float3 ltViewPos = LocalShadow_BonePos - LocalShadow_LightDirection * LS_ShadowMapDepthLength;

   // ビュー変換行列
   return float4x4( ltViewRot[0],  0,
                    ltViewRot[1],  0,
                    ltViewRot[2],  0,
                   -mul( ltViewPos, ltViewRot ), 1 );
}


// ライト方向の射影変換行列
float4x4 LocalShadow_LightProjMatrix()
{

   float sx = 1.0f / (5.0f - 4.0f*LocalShadow_MorphSize1 + 20.0f*LocalShadow_MorphSize2 + 95.0f*LocalShadow_MorphSize2X);
   float sy = 1.0f / (5.0f - 4.0f*LocalShadow_MorphSize1 + 20.0f*LocalShadow_MorphSize2 + 95.0f*LocalShadow_MorphSize2Y);
   float d = 0.5f / LocalShadow_Distance;

   return float4x4( sx, 0,  0, 0,
                    0,  sy, 0, 0,
                    0,  0,  d, 0,
                    0,  0,  0, 1 );

}


float4x4 LocalShadow_WorldMatrix : WORLD;

static float4x4 LocalShadow_LightViewProjMatrix = mul( LocalShadow_LightViewMatrix(), LocalShadow_LightProjMatrix() );
static float4x4 LocalShadow_LightWorldViewProjMatrix = mul( LocalShadow_WorldMatrix, LocalShadow_LightViewProjMatrix );


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#ifndef LOCALSHADOWMAPDRAW

#ifdef LS_ExecKey 

// フェイス材質判定
float LocalShadow_SpecularPower : SPECULARPOWER < string Object = "Geometry"; >;
static bool LocalShadow_Valid = (abs(frac(floor(LocalShadow_SpecularPower*1000)/100) - LS_ExecKey) < 0.001f);

#else

float LocalShadow_Valid = 1;

#endif


// ライト方向の修正
float3 LocalShadow_GetLightDirection(float3 ltDir)
{

    
    if( LocalShadow_Valid ){
        ltDir = normalize( lerp(LocalShadow_LtCtrlDir, ltDir, LocalShadow_MorphLtSync1) );
    }
    
    return ltDir;
}


////////////////////////////////////////////////////////////////////////////////////////////////

// シャドウマップ関連の処理

// シャドウマップバッファサイズ
#define SMAPSIZE_WIDTH   LS_ShadowMapBuffSize
#define SMAPSIZE_HEIGHT  LS_ShadowMapBuffSize

#if LS_UseSoftShadow==1
    #define TEX_FORMAT  "D3DFMT_G32R32F"
    #define TEX_MIPLEVELS  0
#else
    #define TEX_FORMAT  "D3DFMT_R32F"
    #define TEX_MIPLEVELS  1
#endif

// オフスクリーンシャドウマップバッファ
texture LS_ShadowMap : OFFSCREENRENDERTARGET <
    string Description = "PAToon+のシャドウマップ（Local_ShadowMap.fxsubを割り当てるか、チェックを外す）";
    int Width  = SMAPSIZE_WIDTH;
    int Height = SMAPSIZE_HEIGHT;
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
    string Format = TEX_FORMAT;
    bool AntiAlias = false;
    int Miplevels = TEX_MIPLEVELS;
    string DefaultEffect = 
        "self = LocalShadow_ShadowMap.fxsub;"
        "* = hide;";
>;
sampler LocalShadow_ShadowMapSamp = sampler_state {
    texture = <LS_ShadowMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};



// 影濃度
float LocalShadow_MorphSdDens1M : CONTROLOBJECT < string name = "(self)"; string item = "影薄く"; >;
float LocalShadow_MorphSdDens2M : CONTROLOBJECT < string name = "(self)"; string item = "影濃く"; >;

float LocalShadow_MorphSdDens1C : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "影薄く"; >;
float LocalShadow_MorphSdDens2C : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "影濃く"; >;

static float LocalShadow_MorphSdDens1 = LocalShadow_MorphSdDens1C + LocalShadow_MorphSdDens1M;
static float LocalShadow_MorphSdDens2 = LocalShadow_MorphSdDens2C + LocalShadow_MorphSdDens2M;

static float LocalShadow_MorphLtSync3 = lerp(LS_LightSyncDensity, 1.0f, LocalShadow_MorphLtSync);
static float LocalShadow_LtCtrlDens = smoothstep(-1.5f+1.5f*LocalShadow_MorphLtSync3, LocalShadow_MorphLtSync3, dot(LocalShadow_LightDirection, LocalShadow_LtDirection));
static float LocalShadow_Density1 = (1.0f - LocalShadow_MorphSdDens1) * LocalShadow_LtCtrlDens;
static float LocalShadow_Density2 = 1.0f + 5.0f * LocalShadow_MorphSdDens2;


#if LS_UseSoftShadow==1
// VSMシャドウマップ関連の処理

    // ぼかし強度
    float LocalShadow_MorphSdBulrM : CONTROLOBJECT < string name = "(self)"; string item = "影ぼかし"; >;
    float LocalShadow_MorphSdBulrC : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "影ぼかし"; >;
    static float LocalShadow_MorphSdBulr = LocalShadow_MorphSdBulrC + LocalShadow_MorphSdBulrM;

    static float LocalShadow_ShadowBulrPower = lerp(LS_InitBlurPower, 1.0f, LocalShadow_MorphSdBulr) * 5.0f;

    // シャドウマップの周辺サンプリング回数
    #define BASESMAP_COUNT  4

    // シャドウマップバッファサイズ
    #define SMAPSIZE_WIDTH   LS_ShadowMapBuffSize
    #define SMAPSIZE_HEIGHT  LS_ShadowMapBuffSize

    // シャドウマップのサンプリング間隔
    static float2 LocalShadow_SMapSampStep = float2(LocalShadow_ShadowBulrPower/SMAPSIZE_WIDTH, LocalShadow_ShadowBulrPower/SMAPSIZE_HEIGHT);

    // シャドウマップの周辺サンプリング1
    float2 LocalShadow_GetZPlotSampleBase1(float2 Tex, float smpScale)
    {
        float2 smpStep = LocalShadow_SMapSampStep * smpScale;
        float mipLv = log2( max(SMAPSIZE_WIDTH*smpStep.x, 1.0f) );
        float2 zplot = tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex, 0, mipLv)).xy * 2.0f;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2(-1,-1), 0, mipLv)).xy;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 1,-1), 0, mipLv)).xy;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2(-1, 1), 0, mipLv)).xy;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 1, 1), 0, mipLv)).xy;
        return (zplot / 6.0f);
    }

    // シャドウマップの周辺サンプリング2
    float2 LocalShadow_GetZPlotSampleBase2(float2 Tex, float smpScale)
    {
        float2 smpStep = LocalShadow_SMapSampStep * smpScale;
        float mipLv = log2( max(SMAPSIZE_WIDTH*smpStep.x, 1.0f) );
        float2 zplot = tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex, 0, mipLv)).xy * 2.0f;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2(-1, 0), 0, mipLv)).xy;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 1, 0), 0, mipLv)).xy;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 0,-1), 0, mipLv)).xy;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 0, 1), 0, mipLv)).xy;
        return (zplot / 6.0f);
    }

    // セルフシャドウの遮蔽確率を求める
    float LocalShadow_GetSelfShadowRate(float2 SMapTex, float z)
    {
        // シャドウマップよりZプロットの統計処理(zplot.x:平均, zplot.y:2乗平均)
        float2 zplot = float2(0,0);
        float rate = 1.0f;
        float sumRate = 0.0f;
        [unroll]
        for(int i=0; i<BASESMAP_COUNT; i+=2) {
            rate *= 0.5f; sumRate += rate;
            zplot += LocalShadow_GetZPlotSampleBase1(SMapTex, float(i+1)) * rate;
            rate *= 0.5f; sumRate += rate;
            zplot += LocalShadow_GetZPlotSampleBase2(SMapTex, float(i+2)) * rate;
        }
        zplot /= sumRate;

        // 影部判定(VSM:Variance Shadow Maps法)
        float variance = max( zplot.y - zplot.x * zplot.x, 0.05f/LS_ShadowMapDepthLength );
        float comp = variance / (variance + max(z - zplot.x, 0.0f));

        comp = smoothstep(0.1f/max(LocalShadow_ShadowBulrPower, 1.0f), 1.0f, comp);
        return (1.0f-(1.0f-comp)*LocalShadow_Density1);
    }

#else
// ソフトシャドウを使わない場合

    #define LocalShadow_SKII1  (200.0f*LS_ShadowMapDepthLength)

    // セルフシャドウの遮蔽確率を求める
    float LocalShadow_GetSelfShadowRate(float2 SMapTex, float z)
    {
        float comp;
        float dist = max( z - tex2D(LocalShadow_ShadowMapSamp, SMapTex).r, 0.0f );
        comp = 1.0f - saturate( dist * LocalShadow_SKII1 - 7.0f);

        return (1.0f-(1.0f-comp)*LocalShadow_Density1);
    }
    
    
#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// 濃度設定関連の処理

struct  LocalShadow_COLOR {
    float4 Color;        // オブジェクト色
    float4 ShadowColor;  // 影色
};

// 影色に濃度を加味する
LocalShadow_COLOR LocalShadow_GetShadowDensity(float4 Color, float4 ShadowColor, bool useToon, float LightNormal)
{
    LocalShadow_COLOR Out;
    Out.Color = Color;

    float e = max(LocalShadow_Density2, 1.0f);
    float a = 1.0f / e;
    float b = 1.0f - smoothstep(3.0f, 6.0f, e);
    float3 color = lerp(ShadowColor.rgb*a, ShadowColor.rgb*b, pow(ShadowColor.rgb, e));
    Out.ShadowColor = float4(saturate(color), ShadowColor.a);

    return Out;
}


#endif


///////////////////////////////////////////////////////
//  "LocalShadow_Header.fxh"  ここまで ↑
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

#else

bool LocalShadow_Valid = 0;


#endif //USE_LOCALSHADOWのフラグ終わり


/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////
// "DirectionalSphere.h"  ここから ↓
/////////////////////////////////////////////////////////////////////////////////////

#ifndef	DEC_LOCAL2DIRSPHERE
#define	DEC_LOCAL2DIRSPHERE( parts, dir )\
float4x4		s_mtxDirectionalSphNode		: CONTROLOBJECT < string name = "(self)"; string item = parts; >;\
float4x4		s_mtxDirectionalSphView		: VIEW;\
float3			s_vSphereDirection			= dir;\
static float3	s_vDirectionalSphU			= normalize( cross( mul( s_vSphereDirection, (float3x3)s_mtxDirectionalSphNode ), s_mtxDirectionalSphView._13_23_33 ) );\
static float3	s_vDirectionalSphV			= normalize( cross( s_mtxDirectionalSphView._13_23_33, s_vDirectionalSphU ) );\
float2			LocalNormalToDirSph( float3 vNormal ) { \
	float2	uv;\
	uv.x	= +dot( s_vDirectionalSphU, vNormal );\
	uv.y	= -dot( s_vDirectionalSphV, vNormal );\
	return	uv * 0.5 - 0.5;\
}
#endif

// LocalNormalToDirSph関数を使えるようにします
DEC_LOCAL2DIRSPHERE( "頭", float3( 0, 1, 0 ) );
// スフィアのUV計算のところでLocalNormalToDirSphを呼んでます

float SphereZCTR    : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "ｽﾌｨｱ追従ｵﾌ"; >;
float SphereZModel  : CONTROLOBJECT < string name = "(self)" ; string item = "ｽﾌｨｱ追従ｵﾌ"; >;

static float SphereZ = 1 - ((1 -SphereZCTR) * (1-SphereZModel));


////////////////////////////////////////////////////////
// "DirectionalSphere.h"  ここまで ↑
/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////




//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  #include "HACore.hlsl" を統合
//ここから ↓
//////////////////////////////////////////////////////////////////////////////////////////////////////////////


// HACore rel. 13


/////////////////////////////////////////
//PAToon用の改変

float4		GroundShadowColorC	: GROUNDSHADOWCOLOR;
static float3 GroundShadowColorS0 = GroundShadowColorA + GroundShadowColorB + GroundShadowColorC;

static float3 GroundShadowColorHsvC = GetHsvFromRgb(GroundShadowColorS0) + GroundShadowColorHsvA/10 + GroundShadowColorHsvB/10;

static float3 GroundShadowColorS = GetRgbFromHsv(GroundShadowColorHsvC);

static float4 GroundShadowColor = float4(GroundShadowColorS.r, GroundShadowColorS.g, GroundShadowColorS.b, GroundShadowColorC.a * GroundShadowAlpha);

float      AddingSphereCTR   : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "加算ｽﾌｨｱｵﾌ"; >;
float      AddingSphereModel : CONTROLOBJECT < string name = "(self)"; string item = "加算ｽﾌｨｱｵﾌ"; >;

float      MultiplySphereCTR   : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "乗算ｽﾌｨｱｵﾌ"; >;
float      MultiplySphereModel : CONTROLOBJECT < string name = "(self)"; string item = "乗算ｽﾌｨｱｵﾌ"; >;

static float AddingSphereP =  (1 - AddingSphereCTR) * (1 - AddingSphereModel) ;
static float MultiplySphereP = 1 - (1 - MultiplySphereCTR) * (1 - MultiplySphereModel) ;


/////////////////////////////////////////


float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5, 0.5) / ViewportSize;

#ifdef USE_EXCELLENTSHADOW

float X_SHADOWPOWER = 1.0;
float PMD_SHADOWPOWER = 0.2;

shared texture2D ScreenShadowMapProcessed : RENDERCOLORTARGET
<
	float2 ViewPortRatio = { 1.0, 1.0 };
int MipLevels = 1;
string Format = "D3DFMT_R16F";
> ;
sampler2D ScreenShadowMapProcessedSamp = sampler_state
{
	texture = <ScreenShadowMapProcessed>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

shared texture2D ExShadowSSAOMapOut : RENDERCOLORTARGET
<
	float2 ViewPortRatio = { 1.0, 1.0 };
int MipLevels = 1;
string Format = "R16F";
> ;

sampler2D ExShadowSSAOMapSamp = sampler_state
{
	texture = <ExShadowSSAOMapOut>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

bool Exist_ExcellentShadow : CONTROLOBJECT < string name = "ExcellentShadow.x"; > ;
bool Exist_ExShadowSSAO : CONTROLOBJECT < string name = "ExShadowSSAO.x"; > ;
float ShadowRate : CONTROLOBJECT < string name = "ExcellentShadow.x"; string item = "Tr"; > ;
float3 ES_CameraPos1 : POSITION < string Object = "Camera"; > ;
float es_size0 : CONTROLOBJECT < string name = "ExcellentShadow.x"; string item = "Si"; > ;
float4x4 es_mat1 : CONTROLOBJECT < string name = "ExcellentShadow.x"; > ;

static float3 es_move1 = float3(es_mat1._41, es_mat1._42, es_mat1._43);
static float CameraDistance1 = length(ES_CameraPos1 - es_move1);

#endif

#ifdef MIKUMIKUMOVING

float		EdgeWidth : EDGEWIDTH;

bool		LightEnables[MMM_LightCount]		: LIGHTENABLES;
float4x4	LightWVPMatrices[MMM_LightCount]	: LIGHTWVPMATRICES;
float3		LightDirection[MMM_LightCount]		: LIGHTDIRECTIONS;

float3		LightDiffuses[MMM_LightCount]		: LIGHTDIFFUSECOLORS;
float3		LightAmbients[MMM_LightCount]		: LIGHTAMBIENTCOLORS;
float3		LightSpeculars[MMM_LightCount]		: LIGHTSPECULARCOLORS;

float3		LightPositions[MMM_LightCount]		: LIGHTPOSITIONS;
float		LightZFars[MMM_LightCount]			: LIGHTZFARS;

static float4 DiffuseColor[MMM_LightCount] =
{
	MaterialDiffuse * float4(LightDiffuses[0], 1.0f),
	MaterialDiffuse * float4(LightDiffuses[1], 1.0f),
	MaterialDiffuse * float4(LightDiffuses[2], 1.0f)
};
static float3 AmbientColor[MMM_LightCount] =
{
	saturate(MaterialAmbient * LightAmbients[0] + MaterialEmmisive),
	saturate(MaterialAmbient * LightAmbients[1] + MaterialEmmisive),
	saturate(MaterialAmbient * LightAmbients[2] + MaterialEmmisive)
};
static float3 SpecularColor[MMM_LightCount] =
{
	MaterialSpecular * LightSpeculars[0],
	MaterialSpecular * LightSpeculars[1],
	MaterialSpecular * LightSpeculars[2]
};

#else

#define MMM_LightCount 1

float		EdgeWidth = 1;

float4x4	LightWorldViewProjMatrix			: WORLDVIEWPROJECTION < string Object = "Light"; > ;
float3		LightDirection0						: DIRECTION < string Object = "Light"; > ;
float3		LightDiffuse						: DIFFUSE < string Object = "Light"; > ;
float3		LightAmbient						: AMBIENT < string Object = "Light"; > ;
float3		LightSpecular						: SPECULAR < string Object = "Light"; > ;

static bool		LightEnables[MMM_LightCount] = { true };
static float4x4	LightWVPMatrices[MMM_LightCount] = { LightWorldViewProjMatrix };
static float3	LightDirection[MMM_LightCount] = { LightDirection0 };

static float3	LightDiffuses[MMM_LightCount] = { LightDiffuse };
static float3	LightAmbients[MMM_LightCount] = { LightAmbient };
static float3	LightSpeculars[MMM_LightCount] = { LightSpecular };

static float4 DiffuseColor[MMM_LightCount] =
{
	MaterialDiffuse * float4(LightDiffuses[0], 1.0f)
};
static float3 AmbientColor[MMM_LightCount] =
{
	saturate(MaterialAmbient * LightAmbients[0] + MaterialEmmisive)
};
static float3 SpecularColor[MMM_LightCount] =
{
	MaterialSpecular * LightSpeculars[0]
};

#endif

bool	use_texture;		// テクスチャ使用
bool	use_spheremap;		// スフィアマップ使用
bool	use_toon;			// トゥーン描画かどうか (アクセサリ: false, モデル: true)
bool	transp;				// 半透明フラグ
bool	spadd;				// スフィアマップ加算合成フラグ
bool    use_subtexture;  //サブテクスチャの使用（影傾向テクスチャとして使う）

#ifdef MIKUMIKUMOVING

bool    usetoontexturemap;	// Toon テクスチャを使用するかどいうか (MMM)

#else

bool	parthf;				// セルフシャドウフラグ (mode1: false, mode2: true)
#define SKII1	1500
#define SKII2	8000
#define Toon	3
sampler DefSampler : register(s0);

#endif

texture ObjectTexture : MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state
{
	Texture = <ObjectTexture>;
	MinFilter = Anisotropic;
	MagFilter = Anisotropic;
	MipFilter = Linear;
	MaxAnisotropy = 16;
};
texture ObjectSphereMap : MATERIALSPHEREMAP;
sampler ObjSphereSampler = sampler_state
{
	Texture = <ObjectSphereMap>;
	MinFilter = Anisotropic;
	MagFilter = Anisotropic;
	MipFilter = Linear;
	MaxAnisotropy = 16;
	AddressU = Wrap;
	AddressV = Wrap;
};

texture ObjectToonTexture : MATERIALTOONTEXTURE;
sampler ObjToonSampler = sampler_state
{
	texture = <ObjectToonTexture>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = None;
	
	
	AddressU = Clamp;
	AddressV = Clamp;
};


///////////////////////////////////////////////////////////////////////////////////////////////

//処理的にノーマルマップの重複は避けたいが実際に重複させて使うことはないと思う
//外部指定と重複してる場合にSubSphereが読み込まれないのでエラーが出る

#ifdef USE_NORMALMAP
texture2D NormalMap
<
string ResourceName = USE_NORMALMAP;
int MipLevels = 0;
> ;
sampler2D NormalMapSampler = sampler_state
{
    texture = <NormalMap>;
	MINFILTER = Anisotropic;
	MAGFILTER = Anisotropic;
	MIPFILTER = Linear;
	MAXANISOTROPY = 16;
	AddressU = Wrap;
	AddressV = Wrap;
};

#endif




#ifdef USE_SHADOWBIASMAP
texture2D ShadowBiasMap
<
string ResourceName = USE_SHADOWBIASMAP;
int MipLevels = 0;
> ;
sampler2D ShadowBiasSampler = sampler_state
{
    texture = <ShadowBiasMap>;
	MINFILTER = Anisotropic;
	MAGFILTER = Anisotropic;
	MIPFILTER = Linear;
	MAXANISOTROPY = 16;
	AddressU = Wrap;
	AddressV = Wrap;
};
#else


    #ifdef USE_SHADOWBIAS_TOONTEX
    sampler SubToonSampler = sampler_state
    {
    	texture = <ObjectToonTexture>;
    	MinFilter = Anisotropic;
    	MagFilter = Anisotropic;
    	MipFilter = Linear;
    	MaxAnisotropy = 16;
    	AddressU = Wrap;
    	AddressV = Wrap;
    };
    #else

        #ifdef USE_NORMALMAP_TOONTEX
        sampler SubToonSampler = sampler_state
        {
        	texture = <ObjectToonTexture>;
        	MinFilter = Anisotropic;
        	MagFilter = Anisotropic;
        	MipFilter = Linear;
        	MaxAnisotropy = 16;
        	AddressU = Wrap;
        	AddressV = Wrap;
        };
        #endif

    #endif

#endif


float3x3 ComputeTangentFrame(float3 Normal, float3 View, float2 UV)
{
	float3 dp1 = ddx(View);
	float3 dp2 = ddy(View);
	float2 duv1 = ddx(UV);
	float2 duv2 = ddy(UV);
	float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
	float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
	float3 Tangent = mul(float2(duv1.x, duv2.x), inverseM);
	float3 Binormal = mul(float2(duv1.y, duv2.y), inverseM);

	return float3x3(normalize(Tangent), normalize(Binormal), Normal);
}





///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
	float4 Pos				: POSITION;		// 射影変換座標
	float4 ZCalcTex			: TEXCOORD0;	// Z 値
	float2 Tex				: TEXCOORD1;	// テクスチャ
	float3 Normal			: TEXCOORD2;	// 法線
	float3 Eye				: TEXCOORD3;	// カメラとの相対位置
	float2 SpTex			: TEXCOORD4;	// スフィアマップテクスチャ座標
#ifdef MIKUMIKUMOVING
	float4 SS_UV1			: TEXCOORD5;	// セルフシャドウテクスチャ座標
	float4 SS_UV2			: TEXCOORD6;	// セルフシャドウテクスチャ座標
	float4 SS_UV3			: TEXCOORD7;	// セルフシャドウテクスチャ座標
#endif
	float4 ScreenTex		: TEXCOORD8;
#ifdef USE_HGSHADOW
	float4 PPos				: TEXCOORD9;
#endif
	float4 Color			: COLOR0;		// ディフューズ色
	
	#ifdef USE_ROUNDNORMAL
	float3 VPos     : TEXCOORD10;     // 球法線化用の法線
	#endif
	
};

//////////////////////////////////////////////////////////////////////////////////////////////
//法線球面化用のコントローラー定義

#ifdef USE_ROUNDNORMAL

float3 SPosC : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "球法線中心";  >;
float SmorphC : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "球法線化";  >;
float NormalYZeroC : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "Y法線ゼロ";  >;

float3 SPosM : CONTROLOBJECT < string name = "(self)"; string item = "球法線中心";  >;
float SmorphM : CONTROLOBJECT < string name = "(self)"; string item = "球法線化";  >;
float NormalYZeroM : CONTROLOBJECT < string name = "(self)"; string item = "Y法線ゼロ";  >;

static float3 SPos = SPosC + SPosM;
static float Smorph = (1 - SmorphC) * (1 - SmorphM);
static float NormalYZero = (1 - NormalYZeroC) * (1 - NormalYZeroM);

#endif

////////////////////////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////////////////////
//ノーマルマップ・影傾向マップの材質フラグ


//////////////////////////////////////////////////////////

//サブテクスチャの環境色フラグ設定（小数点5位が1で影傾向テクスチャ、2でノーマルマップ）
static float AmbientSubtex = floor( frac(MaterialEmmisive1.b*10000)*10 );
static bool SubShadowBiasFlag = abs(AmbientSubtex - 1) < 0.1f;
static bool SubNormalMapFlag = abs(AmbientSubtex - 2) < 0.1f;

//ノーマルマップの環境色フラグ設定（小数点6位が1で影傾向テクスチャ、2でノーマルマップ）
static float AmbientToon = floor( frac(MaterialEmmisive1.b*100000)*10 );
static bool ToonShadowBiasFlag = abs(AmbientToon - 1) < 0.1f;
static bool ToonNormalMapFlag = abs(AmbientToon - 2) < 0.1f;

//////////////////////////////////////////////////////////

//フラグ同士であらかじめ整理してしまえるならそうした方がいいのでは？


    //右上1ドットのフラグ確認（トゥーンテクスチャ） ※シェーダー内でやる計算ではないのでは
    static float3 ObjToonFlagTex = tex2D(ObjToonSampler, float2(1,0));  //ToonTexがWrapだと正しく取得できない
                                                                        //ToonTexをマップとして使う場合はWrapとして別に取得が必要か
    
    
    //右上1ドットが白か白ではないかを判別する
    static bool ObjToonFlagWhite = (ObjToonFlagTex.r + ObjToonFlagTex.g + ObjToonFlagTex.b) > 2.99 ;
    static bool ObjToonFlagNonWhite = 1 - ObjToonFlagWhite;
    

    static bool ObjShadingBiasToonFlag = ObjToonFlagNonWhite;//
    static bool ObjToonFlag = ObjToonFlagWhite;//

    //フラグの整理
    //use_subtextureとObjToonFlagNonWhiteを使う

    static bool UseToonForNormalMap    = ObjToonFlagNonWhite * ToonShadowBiasFlag;
    static bool UseToonForShadowBias   = ObjToonFlagNonWhite * ToonShadowBiasFlag;
    static bool UseSubtexForNormalMap  = use_subtexture * SubShadowBiasFlag;
    static bool UseSubtexForShadowBias = use_subtexture * SubNormalMapFlag;

////////////////////////////////////////////////////////////////////////////////////////////////



#ifdef MIKUMIKUMOVING
VS_OUTPUT Basic_VS(MMM_SKINNING_INPUT IN, uniform bool useSelfShadow, uniform bool isEdge)
{
	MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);
	float4 Pos = SkinOut.Position;
	float3 Normal = SkinOut.Normal;
	float2 Tex = IN.Tex;
#else
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useSelfShadow, uniform bool isEdge)
{
#endif
	VS_OUTPUT Out = (VS_OUTPUT)0;

       #ifdef USE_ROUNDNORMAL
       // 球法線化用の法線
       Out.VPos =normalize(  mul( Pos,WorldMatrix )- SPos  );
       
       
       #endif


	Out.Eye.xyz = CameraPosition - mul(Pos, WorldMatrix);

	float dist = length(Out.Eye.xyz);

	if (isEdge)
	{
		float EdgeWeight = 0.001;

		if (!use_toon)
		{
			EdgeWeight *= 0.1;
			
			EdgeWidth = 1;
		}

#ifdef MIKUMIKUMOVING
		if (use_toon)
			EdgeWeight = IN.EdgeWeight;
#endif

#ifdef MIKUMIKUMOVING
		if (MMM_IsDinamicProjection)
			EdgeWeight *= MMM_GetDynamicFovEdgeRate(dist);
#endif

      
    	// EdgeControlの計算式を流用(パースによるエッジ太さ対策）

        if(ProjMatrix._44 < 0.5f){


         // カメラとの距離
         float len = max( length( CameraPosition - Pos.xyz ), 5.0f ) ;

         Pos.xyz += Normal * ( EdgeThickness * pow( len, 0.9f ) * 0.0015f * pow(2.4142f / ProjMatrix._22, 0.7f) ) * EdgeWidth * EdgeWidthEmmisive;
        
        }else{
        // パースペクティブoff
        Pos.xyz += Normal * ( EdgeThickness * 0.0025f / ProjMatrix._11 )* EdgeWidth * EdgeWidthEmmisive;
        }


		
	}

#ifdef MIKUMIKUMOVING
	Out.Pos = mul(Pos, MMM_IsDinamicProjection ? mul(mul(WorldMatrix, ViewMatrix), MMM_DynamicFov(ProjMatrix, dist)) : WorldViewProjMatrix);
#else
	Out.Pos = mul(Pos, WorldViewProjMatrix);
#endif

#ifdef USE_HGSHADOW
	Out.PPos = Out.Pos;
#endif

	Out.Normal = normalize(mul(Normal, (float3x3)WorldMatrix));

#ifdef USE_LOCALSHADOW
	LightDirection[0] = LocalShadow_GetLightDirection(LightDirection[0]);
#endif

	float3 color = 0;
	float3 ambient = 0;
	int count = 0;

	[unroll]
	for (int i = 0; i < MMM_LightCount; i++)
		if (LightEnables[i])
		{
			color += (float3(1, 1, 1) - color) * max(0, DiffuseColor[i] * dot(Out.Normal, -LightDirection[i]));
			ambient += AmbientColor[i];
			count++;
		}

	Out.Color.rgb = saturate(ambient / count + color);
	Out.Color.a = DiffuseColor[0].a;
	Out.Tex = Tex;

#ifdef MIKUMIKUMOVING
	if (!use_spheremap)
		Out.SpTex.xy = IN.AddUV1.xy;

	if (useSelfShadow)
	{
		float4 dpos = mul(Pos, WorldMatrix);

		Out.SS_UV1 = mul(dpos, LightWVPMatrices[0]);
		Out.SS_UV2 = mul(dpos, LightWVPMatrices[1]);
		Out.SS_UV3 = mul(dpos, LightWVPMatrices[2]);
		Out.SS_UV1.y = -Out.SS_UV1.y;
		Out.SS_UV2.y = -Out.SS_UV2.y;
		Out.SS_UV3.y = -Out.SS_UV3.y;
		Out.SS_UV1.z = length(LightPositions[0] - Pos) / LightZFars[0];
		Out.SS_UV2.z = length(LightPositions[1] - Pos) / LightZFars[1];
		Out.SS_UV3.z = length(LightPositions[2] - Pos) / LightZFars[2];
	}
#else
	Out.ZCalcTex = mul(Pos, LightWorldViewProjMatrix);
#endif

#ifdef USE_LOCALSHADOW
	if (LocalShadow_Valid)
		Out.ZCalcTex = mul(Pos, LocalShadow_LightWorldViewProjMatrix);
#endif

	Out.ScreenTex = Out.Pos;

#ifdef USE_EXCELLENTSHADOW
	Out.Pos.z -= max(0, (int)((CameraDistance1 - 6000) * 0.04));
#endif

	return Out;
}

float CalculateSelfShadowValue(VS_OUTPUT IN)
{
#ifdef USE_LOCALSHADOW
	if (LocalShadow_Valid && LightEnables[0])
	{
		float4 uv = IN.ZCalcTex / IN.ZCalcTex.w;
		float2 TransTexCoord = 0.5 + uv * float2(0.5, -0.5);

		if (any(saturate(TransTexCoord) - TransTexCoord))
			return 1;
		else
		{
			float comp = LocalShadow_GetSelfShadowRate(TransTexCoord, uv.z);
			LocalShadow_COLOR Out = LocalShadow_GetShadowDensity(float4(1, 1, 1, 1), float4(0, 0, 0, 0), use_toon, dot(IN.Normal, -LightDirection[0]));

			return lerp(Out.ShadowColor, Out.Color, comp).r;
		}
	}
	else
#endif
	{
#ifdef USE_HGSHADOW
		if (HgShadow_Valid && LightEnables[0])
		{
			float comp = HgShadow_GetSelfShadowRate(IN.PPos);
			HgShadow_COLOR Out = HgShadow_GetShadowDensity(float4(1, 1, 1, 1), float4(0, 0, 0, 0), use_toon, dot(IN.Normal, -LightDirection[0]));

			return lerp(Out.ShadowColor, Out.Color, comp).r;
		}
		else
#endif
		{
#ifdef USE_EXCELLENTSHADOW
			if (Exist_ExcellentShadow)
			{
				IN.ScreenTex.xyz /= IN.ScreenTex.w;

				float2 TransScreenTex = 0.5 + IN.ScreenTex * float2(0.5, -0.5) + ViewportOffset;
				float ShadowMapVal = tex2D(ScreenShadowMapProcessedSamp, TransScreenTex).r;
				float ShadowColor = 0;
				float SSAOMapVal = 0;
				float3 lightdir = LightDirection[0];

				if (Exist_ExShadowSSAO)
					SSAOMapVal = tex2D(ExShadowSSAOMapSamp, TransScreenTex).r;

				if (use_toon)
				{
					ShadowMapVal = min(saturate(dot(IN.Normal, -lightdir) * 3), ShadowMapVal);
					ShadowColor *= 1 - (1 - ShadowRate) * PMD_SHADOWPOWER;
				}
				else
					ShadowColor *= 1 - (1 - ShadowRate) * X_SHADOWPOWER;

				float Color = 1;
				float ShadowColor2 = max(0, ShadowColor - (Color - ShadowColor + 0.3) * SSAOMapVal * 0.2);

				Color = lerp(Color, ShadowColor, saturate(SSAOMapVal * 0.4));
				Color = lerp(ShadowColor2, Color, ShadowMapVal);

				return Color;
			}
			else
#endif
			{
#ifdef MIKUMIKUMOVING
				return MMM_GetSelfShadowToonColor(float4(0, 0, 0, 1), IN.Normal, IN.SS_UV1, IN.SS_UV2, IN.SS_UV3, false, use_toon).r;
#else
				float4 uv = IN.ZCalcTex / IN.ZCalcTex.w;
				float2 TransTexCoord = 0.5 + uv * float2(0.5, -0.5);
				float comp = saturate(dot(IN.Normal, -LightDirection[0]) * 16 + 0.5);

				if (any(saturate(TransTexCoord) - TransTexCoord))
					return 1;
				else
				{
					comp = max(uv.z - tex2D(DefSampler, TransTexCoord).r, 0.0f);

					if (parthf)
						comp *= SKII2 * TransTexCoord.y - 0.3f;
					else
						comp *= SKII1 - 0.3f;

					comp = 1 - saturate(comp);

					return comp;
				}
#endif
			}
		}
	}
}




float4 Basic_PS(VS_OUTPUT IN, uniform bool useSelfShadow, uniform bool isEdge) : COLOR0
{
	float4 Color = IN.Color;
	float4 texColor = 1;
	float4 multiplySphereColor = 1;
	float3 addSphereColor = 0;
	BlendParameters ps = (BlendParameters)0;

	Color.a = clamp(Color.a, 0, 1);


// normalmap     //３つ並列はバカバカしいがエラーを出しにくくするために最善
                 //サンプラーの対象部分だけ変えればいいのでは？



#ifdef USE_NORMALMAP //外部テクスチャ指定 //モデルフラグより外部テクスチャ指定を優先する

	float4 NormalColor = tex2D(NormalMapSampler, IN.Tex * NormalMapResolution) * 2;

	NormalColor = NormalColor.rgba;
	NormalColor.a = 1;

	float3x3 tangentFrame = ComputeTangentFrame(normalize(IN.Normal), normalize(IN.Eye), IN.Tex);

	IN.Normal = normalize(mul(NormalColor - 1.0, tangentFrame));

#else  //外部テクスチャがある場合は以下スキップ

    #ifdef USE_NORMALMAP_TOONTEX //トゥーンを法線マップに使う

	float4 NormalColor = tex2D(SubToonSampler, IN.Tex * NormalMapResolution) * 2;

	NormalColor = NormalColor.rgba;
	NormalColor.a = 1;

	float3x3 tangentFrame = ComputeTangentFrame(normalize(IN.Normal), normalize(IN.Eye), IN.Tex);
	
    IN.Normal =  IN.Normal * ( 1 - UseToonForNormalMap );
    IN.Normal += normalize(mul(NormalColor - 1.0, tangentFrame)) * UseToonForNormalMap;

	
    #endif //環境色フラグが排他構造なので並列記述でよし //並列フラグを立てたら当然重くなる

    #ifdef USE_NORMALMAP_SUBTEX//サブテクスチャを法線マップとして使う。トゥーンONサブONの場合は上書きされる
	float4 SubNormalColor = tex2D(ObjSphereSampler, IN.Tex * NormalMapResolution) * 2;

	SubNormalColor = SubNormalColor.rgba;
	SubNormalColor.a = 1;

	float3x3 SubtangentFrame = ComputeTangentFrame(normalize(IN.Normal), normalize(IN.Eye), IN.Tex);

    IN.Normal =   IN.Normal * ( 1 - UseSubtexForNormalMap );
    IN.Normal +=  normalize(mul(SubNormalColor - 1.0, SubtangentFrame)) * UseSubtexForNormalMap;

    #endif
        
    
#endif

	ps.ViewNormal = NanAsZero(saturate(dot(IN.Normal, normalize(IN.Eye.xyz))));
	ps.ScreenCoordinate.xy = IN.ScreenTex.xy / IN.ScreenTex.w * 0.5 + float2(0.5, 0.5);
	ps.ScreenCoordinate.xy = float2(ps.ScreenCoordinate.x * ViewportSize.x / ViewportSize.y, 1 - ps.ScreenCoordinate.y) * ViewportSize.y;

	// texture
	if (use_texture)
	{
		texColor = tex2D(ObjTexSampler, IN.Tex);

		float texAlpha = MultiplyTexture.a + AddingTexture.a;

		texColor.rgb = (texColor.rgb * MultiplyTexture.rgb + AddingTexture.rgb) * texAlpha + (1.0 - texAlpha);
		Color *= texColor;
	}
	
///////////////////////////////
//PAToon用の書き換え
      
      float ShadingBias = 0;
      

// spheremap
	
#ifdef USE_SHADOWBIASMAP  //外部影傾向マップを読み込む場合
    
    ShadingBias  += ( tex2D(ShadowBiasSampler, IN.Tex).r * (2 * ShadingBiasPower) - (1 * ShadingBiasPower) );// -1 ～ +1
    
    
    	if (use_spheremap)
	{
		
               
               
               float2 SpTex = lerp((mul(IN.Normal, (float3x3)ViewMatrix).xy * float2(0.5, -0.5) + float2(0.5, 0.5)) ,LocalNormalToDirSph(mul((float3x3)BoneMatrixB, IN.Normal )), 1-SphereZ);
		
               if (spadd)
			      addSphereColor = (tex2D(ObjSphereSampler, SpTex).rgb * MultiplySphere.rgb + AddingSphere.rgb) * AddingSphereP;
		       else
		       {
			      multiplySphereColor = lerp ( tex2D(ObjSphereSampler, SpTex) * MultiplySphere + AddingSphere, (1,1,1), MultiplySphereP);
			      Color *= multiplySphereColor;
                 
	           }

    }
    
    
    
#else  //外部影傾向マップを読み込まない場合
	
	if (use_spheremap)
	{
		//float2 SpTex = mul(IN.Normal, (float3x3)ViewMatrix).xy * float2(0.5, -0.5) + float2(0.5, 0.5);
        
          //影傾向テクスチャの計算  影傾向テクスチャを使う場合はスフィア計算をしない
          
          if (use_subtexture)
            {

               
                   //サブテクスチャを影傾向マップに使う場合
                   #ifdef USE_SHADOWBIAS_SUBTEX
                   ShadingBias  += ( tex2D(ObjSphereSampler, IN.Tex).r * (2 * ShadingBiasPower) - (1 * ShadingBiasPower) ) * UseSubtexForShadowBias;// -1 ～ +1
                   #endif
                   
               
               
            }
          else
            {
               //トゥーンマップを影傾向マップに使いスフィアと併用する場合
               //右上1ドットが(1,1,1)の通常トゥーンは除外する(1-ObjToonFlag)
               #ifdef USE_SHADOWBIAS_TOONTEX   //2*と1*は0.5基準の0～1.0の数値幅をゼロ基準の-1～+1.0に補正するための計算
               ShadingBias  += ( tex2D(SubToonSampler, IN.Tex).r * (2 * ShadingBiasPower) - (1 * ShadingBiasPower) ) * UseSubtexForShadowBias;// -1 ～ +1
               #endif
               
               
               float2 SpTex = lerp((mul(IN.Normal, (float3x3)ViewMatrix).xy * float2(0.5, -0.5) + float2(0.5, 0.5)) ,LocalNormalToDirSph(mul((float3x3)BoneMatrixB, IN.Normal )), 1-SphereZ);
		
               if (spadd)
			      addSphereColor = (tex2D(ObjSphereSampler, SpTex).rgb * MultiplySphere.rgb + AddingSphere.rgb) * AddingSphereP;
		       else
		       {
			      multiplySphereColor = lerp ( tex2D(ObjSphereSampler, SpTex) * MultiplySphere + AddingSphere, (1,1,1), MultiplySphereP);
			      Color *= multiplySphereColor;
                 
	           }

	           
  
       	    }
        }
     else
     {
     //スフィア材質がなしでトゥーンマップを影傾向マップに使う場合
     #ifdef USE_SHADOWBIAS_TOONTEX
     ShadingBias  += ( tex2D(ObjToonSampler, IN.Tex).r * (2 * ShadingBiasPower) - (1 * ShadingBiasPower) )  *  UseToonForShadowBias;// -1 ～ +1
     #endif
     }

#endif

      

	///////////////////////////////////////////////////////////////////////////////////////////////
    //球法線のための追加（ifが１個増えてるので要検証）
        
        #ifdef USE_ROUNDNORMAL
        
        float3 NNormal = normalize(IN.Normal); // 正規化法線ベクトル
        
        float3 SNormal = NNormal;

        if (LocalShadow_Valid){
        // 球法線化ベクトル
        
        SNormal = (NNormal * Smorph)+ (normalize(IN.VPos) * (1 - Smorph) ); // 正規化球法線ベクトル
        
        
        SNormal = float3(SNormal.x, SNormal.y * NormalYZero, SNormal.z);
        }
        
        #else
        
        float3 SNormal = IN.Normal;
        
        #endif
        
    ////////////////////////////////////////////////////////////////////////////////////////////////
	
	
	
	
    #ifdef USE_HGSHADOW
      
        
        #ifndef USE_EXCELLENTSHADOW
        
        float3 S2Normal = SNormal+ -HgLightDirection*(1-LocalShadow_Valid)* HgShadow_Valid;
        
        #else
        
        float3 S2Normal = SNormal+ -ExLightDirection*(1-LocalShadow_Valid)*Exist_ExcellentShadow*(1-HgShadow_Valid)+ -HgLightDirection*(1-LocalShadow_Valid)* HgShadow_Valid;
        
        #endif
        
      
    #else
      
	    #ifdef USE_EXCELLENTSHADOW
        float3 S2Normal = SNormal+ -ExLightDirection*(1-LocalShadow_Valid)*Exist_ExcellentShadow;
        
        #else
      
        float3 S2Normal = SNormal;
        #endif
        
        
       
    #endif

    IN.Normal = normalize(mul(normalize(S2Normal), (float3x3)BoneMatrixA));


    
////////////////////////////////


	// shadow
	float shadowValue = 1;

#ifdef SHADE_TOONLESS
	use_toon = true;
#else
	#ifdef MIKUMIKUMOVING
	use_toon = use_toon ? usetoontexturemap : true;
	#else
	use_toon = use_toon ? MaterialToon != float3(1, 1, 1) : true;
	#endif
#endif

	// blending
	float3 diffuse = 0;
	float3 specular = 0;
	int lightCount = 0;

#ifdef USE_LOCALSHADOW
	LightDirection[0] = LocalShadow_GetLightDirection(LightDirection[0]);
#endif

	if (useSelfShadow)
	{
		shadowValue = CalculateSelfShadowValue(IN);

		if (transp) Color.a = 0.5f;
	}

	[unroll]
	for (int i = 0; i < MMM_LightCount; i++)
		if (LightEnables[i])
		{
			ps.LightNormal = NanAsZero(use_toon ? saturate(min(shadowValue, clamp(dot(IN.Normal, -LightDirection[i])+ShadingBias, -1, 1)  )) : 1);
			ps.ExtendedLightNormal = NanAsZero(use_toon ? saturate(min(shadowValue, clamp(dot(IN.Normal, -LightDirection[i])+ShadingBias, -1, 1) * 0.5 + 0.5)) : 1);
			ps.HalfVectorNormal = NanAsZero(saturate(dot(normalize(normalize(IN.Eye.xyz) + -LightDirection[i]), IN.Normal)));
			ps.SpecularValue = NanAsZero(saturate(pow(ps.HalfVectorNormal, SpecularPower)));
			ps.ToonValue = tex2D(ObjToonSampler, float2(0, 1 - ps.LightNormal)).rgb;

			if (isEdge)
			{
				diffuse += BlendEdge(Color.rgb, ps) + HandleEdgeColor;
				Color.a = HandleEdgeAlpha * (MaterialDiffuse.a - AddingTexture.a) * MultiplyTexture.a;
			}
			else
			{
#ifdef AMBIENT_AS_BASE
				float3 amb = AmbientColor[i] * texColor.rgb * multiplySphereColor;

	#ifdef AMBIENT_TOON_AS_BASE
				amb *= MaterialToon;
	#endif

				diffuse += amb + (BlendDiffuse(Color.rgb, ps) - amb) * (1 - amb);
#else
				diffuse += BlendDiffuse(Color.rgb, ps);
#endif
				specular += BlendSpecular(SpecularColor[i], ps);
				specular += BlendAddSphere(addSphereColor, ps);
			}

			lightCount++;
		}

	Color.rgb = saturate((diffuse + specular) / lightCount);

	return Color;
}

#ifdef HANDLE_EDGE

#define DRAW_EDGE_PASS(useSelfShadow) \
	pass DrawEdge \
	{ \
		CullMode = CW; \
		AlphaTestEnable = true; \
		VertexShader = compile vs_3_0 Basic_VS(useSelfShadow, true); \
		PixelShader  = compile ps_3_0 Basic_PS(useSelfShadow, true); \
	}

technique EdgeTec < string MMDPass = "edge"; >
{
}

#else

#define DRAW_EDGE_PASS(useSelfShadow)

///////////////////////////////////////////////////////////////////////
//PAToon用の追加（ノーマルエッジ）
// 頂点シェーダ
float4 ColorRender_VS(float4 Pos : POSITION) : POSITION 
{
    // カメラ視点のワールドビュー射影変換
    return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 ColorRender_PS() : COLOR
{
    // 輪郭色で塗りつぶし
    return EdgeColor;
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawEdge {
        AlphaBlendEnable = TRUE;
        AlphaTestEnable  = TRUE;

        VertexShader = compile vs_2_0 ColorRender_VS();
        PixelShader  = compile ps_2_0 ColorRender_PS();
    }
}
///////////////////////////////////////////////////////////////////////

#endif

#define DRAW_OBJECT_PASS(useSelfShadow) \
	pass DrawObject \
	{ \
		AlphaTestEnable = true; \
		VertexShader = compile vs_3_0 Basic_VS(useSelfShadow, false); \
		PixelShader  = compile ps_3_0 Basic_PS(useSelfShadow, false); \
	}

technique MainTec0 < string MMDPass = "object"; >
{
	DRAW_OBJECT_PASS(false)
		DRAW_EDGE_PASS(false)
}

technique MainTec1 < string MMDPass = "object_ss"; >
{
	DRAW_OBJECT_PASS(true)
		DRAW_EDGE_PASS(true)
}

///////////////////////////////////////////////////////////////////////////////////////////////
//PAToon用の追加

//------------------------------------------------------------------------------------------------//
// 地面影の描画

float3 PlanarPos = float3(0.0, 0.1, 0.0);    // 投影する平面上の任意の座標
float3 PlanarNormal = float3(0.0, 1.0, 0.0);  // 投影する平面の法線ベクトル


float4x4 ViewProjMatrix  : VIEWPROJECTION;
float3   LightDirectionMMD  : DIRECTION < string Object = "Light"; >;

float3 LightDirectionCTR : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "地面影 XYZ"; >;
float3 LightDirectionModel : CONTROLOBJECT < string name = "(self)"; string item = "地面影 XYZ"; >;


static float3 LightDirectionBone = LightDirectionModel + LightDirectionCTR;

//static float3   LightDirection = DirectionP;

static float3 LightDirectionG = LightDirectionMMD + LightDirectionBone;



// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
    // 光源の仮位置(平行光源なので)
    float3 LightPos = Pos.xyz + LightDirectionG;

    // 任意平面に投影
    float a = dot(PlanarNormal, PlanarPos - LightPos);
    float b = dot(PlanarNormal, Pos.xyz - PlanarPos);
    float c = dot(PlanarNormal, Pos.xyz - LightPos);
    Pos = float4(Pos.xyz * a + LightPos * b, c);

    //Pos = float4(Pos.xyz * a + LightPos * b, c);

    // ビュー射影変換
    return mul( Pos, ViewProjMatrix );
}

// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
    // 地面影色で塗りつぶし
    return GroundShadowColor;
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
    pass DrawShadow {
        VertexShader = compile vs_2_0 Shadow_VS();
        PixelShader  = compile ps_2_0 Shadow_PS();
    }
}

