////  shader.hlsl
//  MMDStarRail4Fun
//
//  Created by hzy on 2025/4/20.
//  Copyright © 2019 Bilibili. All rights reserved.
//

float4x4 matWorldViewProject : WORLDVIEWPROJECTION;
float4x4 matWorld : WORLD;
float4x4 matView	 : VIEW;

float2 ViewportSize : VIEWPORTPIXELSIZE;

float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;
float3   LightDirection	: DIRECTION < string Object = "Light"; >;
float3   CameraPosition	: POSITION  < string Object = "Camera"; >;
float3   CameraDirection : DIRECTION < string Object = "Camera"; >;

float3 LightColor : SPECULAR< string Object = "Light";>;

float4 MaterialDiffuse : DIFFUSE<string Object = "Geometry";>;
float4 MaterialAmbient : EMISSIVE<string Object = "Geometry";>;
float4 MaterialSpecular : SPECULAR<string Object = "Geometry";>;
float  MaterialPower : SPECULARPOWER<string Object = "Geometry";>;

float4x4 HeadBone : CONTROLOBJECT < string name = "(self)"; string item = "“ª"; >;


float3 uCenter : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "‘S‚Ä‚Ìe"; >;

float uRange : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ShadowRange"; >;
float uUp : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ShadowUp"; >;
float uLeft : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ShadowLeft"; >;
float uBottom : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ShadowBottom"; >;
float uRight : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ShadowRight"; >;

float uLightIntensityP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "LightIntensity+"; >;
float uLightIntensityM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "LightIntensity-"; >;
float uLightRP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "LightR+"; >;
float uLightGP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "LightG+"; >;
float uLightBP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "LightB+"; >;
float uGammaP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "Gamma+"; >;
float uGammaM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "Gamma-"; >;
float uShadowGammaP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ShadowGamma"; >;
float uShadowDarkP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "ShadowDark"; >;
float uSpecularP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "Specular+"; >;
float uSpecularM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "Specular-"; >;
float uRimShadowP : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "RimShadow+"; >;
float uRimShadowM : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "RimShadow-"; >;

static float LightIntensity = lerp(lerp(1, 10, uLightIntensityP), 0, uLightIntensityM);
static float Gamma = lerp(lerp(1, 10, uGammaP), 0.01, uGammaM);
static float SpecularMul = lerp(lerp(1, 10, uSpecularP), 0, uSpecularM);
static float RimShadowMul = lerp(lerp(1, 10, uRimShadowP), 0, uRimShadowM);

#define PI 3.1415926535

float4 EdgeColor : EDGECOLOR;

bool spadd;

float time : TIME;

#define TEXTURE_FILTER ANISOTROPIC
#define TEXTURE_MIP_FILTER ANISOTROPIC
#define TEXTURE_ANISOTROPY_LEVEL 16

sampler DefSampler : register(s0);

texture2D DiffuseTexture: MATERIALTEXTURE<string Format = "A8R8G8B8" ;>;
sampler2D DiffuseTextureSampler = sampler_state {
    texture = <DiffuseTexture>;
    MAXANISOTROPY = TEXTURE_ANISOTROPY_LEVEL;
	MINFILTER = TEXTURE_FILTER; MAGFILTER = TEXTURE_FILTER; MIPFILTER = TEXTURE_MIP_FILTER;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};

texture2D SphereMap: MATERIALSPHEREMAP;
sampler2D SphereMapSampler = sampler_state {
	texture = <SphereMap>;
	MAXANISOTROPY = TEXTURE_ANISOTROPY_LEVEL;
	MINFILTER = TEXTURE_FILTER; MAGFILTER = TEXTURE_FILTER; MIPFILTER = TEXTURE_MIP_FILTER;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};

#ifdef COLOR_TEXTURE
texture2D ColorTexture < string ResourceName = COLOR_TEXTURE;>;
sampler2D ColorTextureSampler = sampler_state
{
    texture = <ColorTexture>;
    MAXANISOTROPY = TEXTURE_ANISOTROPY_LEVEL;
	MINFILTER = TEXTURE_FILTER; MAGFILTER = TEXTURE_FILTER; MIPFILTER = TEXTURE_MIP_FILTER;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
#endif

#ifdef LIGHTMAP_TEXTURE
texture2D LightMapTexture < string ResourceName = LIGHTMAP_TEXTURE;>;
sampler2D LightMapTextureSampler = sampler_state
{
    texture = <LightMapTexture>;
    MAXANISOTROPY = TEXTURE_ANISOTROPY_LEVEL;
	MINFILTER = TEXTURE_FILTER; MAGFILTER = TEXTURE_FILTER; MIPFILTER = TEXTURE_MIP_FILTER;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
#endif

#ifdef FACEMAP_TEXTURE
texture2D FaceMapTexture < string ResourceName = FACEMAP_TEXTURE;>;
sampler2D FaceMapTextureSampler = sampler_state
{
    texture = <FaceMapTexture>;
    MAXANISOTROPY = TEXTURE_ANISOTROPY_LEVEL;
	MINFILTER = TEXTURE_FILTER; MAGFILTER = TEXTURE_FILTER; MIPFILTER = TEXTURE_MIP_FILTER;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
#endif

#ifdef STOCKINGS_TEXTURE
texture2D StockingsTexture < string ResourceName = STOCKINGS_TEXTURE;>;
sampler2D StockingsTextureSampler = sampler_state
{
    texture = <StockingsTexture>;
    MAXANISOTROPY = TEXTURE_ANISOTROPY_LEVEL;
	MINFILTER = TEXTURE_FILTER; MAGFILTER = TEXTURE_FILTER; MIPFILTER = TEXTURE_MIP_FILTER;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
#endif

#ifdef RAMP_COOL_TEXTURE
texture2D RampCoolTexture < string ResourceName = RAMP_COOL_TEXTURE;>;
sampler2D RampCoolTextureSampler = sampler_state
{
    texture = <RampCoolTexture>;
    FILTER = POINT;
    ADDRESSU = CLAMP; ADDRESSV = CLAMP;
};
#endif

#ifdef RAMP_WARM_TEXTURE
texture2D RampWarmTexture < string ResourceName = RAMP_WARM_TEXTURE;>;
sampler2D RampWarmTextureSampler = sampler_state
{
    texture = <RampWarmTexture>;
    FILTER = POINT;
    ADDRESSU = CLAMP; ADDRESSV = CLAMP;
};
#endif

#ifdef EMISSIVE_TEXTURE
texture2D EmissiveTexture < string ResourceName = EMISSIVE_TEXTURE;>;
sampler2D EmissiveTextureSampler = sampler_state
{
    texture = <EmissiveTexture>;
    MAXANISOTROPY = TEXTURE_ANISOTROPY_LEVEL;
	MINFILTER = TEXTURE_FILTER; MAGFILTER = TEXTURE_FILTER; MIPFILTER = TEXTURE_MIP_FILTER;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
#endif

#ifdef EYES_EFFECT_TEXTURE
texture2D EyesEffectTexture < string ResourceName = EYES_EFFECT_TEXTURE;>;
sampler2D EyesEffectTextureSampler = sampler_state
{
    texture = <EyesEffectTexture>;
    FILTER = POINT;
    ADDRESSU = WRAP; ADDRESSV = WRAP;
};
#endif

#ifdef STARRYSKY_TEXTURE
texture2D SkyTexture < string ResourceName = STARRYSKY_TEXTURE;>;
sampler2D SkyTextureSampler = sampler_state
{
    texture = <SkyTexture>;
    MAXANISOTROPY = TEXTURE_ANISOTROPY_LEVEL;
	MINFILTER = TEXTURE_FILTER; MAGFILTER = TEXTURE_FILTER; MIPFILTER = TEXTURE_MIP_FILTER;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
#endif

#ifdef STARRYSKY_MASK_TEXTURE
texture2D SkyMaskTexture < string ResourceName = STARRYSKY_MASK_TEXTURE;>;
sampler2D SkyMaskTextureSampler = sampler_state
{
    texture = <SkyMaskTexture>;
    MAXANISOTROPY = TEXTURE_ANISOTROPY_LEVEL;
	MINFILTER = TEXTURE_FILTER; MAGFILTER = TEXTURE_FILTER; MIPFILTER = TEXTURE_MIP_FILTER;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
#endif

#ifdef STARRYSKY_STAR_TEXTURE
texture2D SkyStarTexture < string ResourceName = STARRYSKY_STAR_TEXTURE;>;
sampler2D SkyStarTextureSampler = sampler_state
{
    texture = <SkyStarTexture>;
    MAXANISOTROPY = TEXTURE_ANISOTROPY_LEVEL;
	MINFILTER = TEXTURE_FILTER; MAGFILTER = TEXTURE_FILTER; MIPFILTER = TEXTURE_MIP_FILTER;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
#endif

#ifdef STARRYSKY_STAR_MASK_TEXTURE
texture2D SkyStarMaskTexture < string ResourceName = STARRYSKY_STAR_MASK_TEXTURE;>;
sampler2D SkyStarMaskTextureSampler = sampler_state
{
    texture = <SkyStarMaskTexture>;
    MAXANISOTROPY = TEXTURE_ANISOTROPY_LEVEL;
	MINFILTER = TEXTURE_FILTER; MAGFILTER = TEXTURE_FILTER; MIPFILTER = TEXTURE_MIP_FILTER;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
#endif

shared texture SHADOW_MAP: OFFSCREENRENDERTARGET;

sampler ZBufferMapSamp = sampler_state {
	texture = <SHADOW_MAP>;
	MinFilter = NONE; MagFilter = NONE; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};

#ifdef NORMALMAP_TEXTURE
texture2D NormalMapTexture < string ResourceName = NORMALMAP_TEXTURE;>;
sampler2D NormalMapTextureSampler = sampler_state
{
    texture = <NormalMapTexture>;
    MAXANISOTROPY = TEXTURE_ANISOTROPY_LEVEL;
	MINFILTER = TEXTURE_FILTER; MAGFILTER = TEXTURE_FILTER; MIPFILTER = TEXTURE_MIP_FILTER;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
#endif

#ifdef MATCAP_TEXTURE
texture2D MatCapTexture < string ResourceName = MATCAP_TEXTURE;>;
sampler2D MatCapTextureSampler = sampler_state
{
    texture = <MatCapTexture>;
    MAXANISOTROPY = TEXTURE_ANISOTROPY_LEVEL;
	MINFILTER = TEXTURE_FILTER; MAGFILTER = TEXTURE_FILTER; MIPFILTER = TEXTURE_MIP_FILTER;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
#endif

#ifdef MATCAP_MASK_TEXTURE
texture2D MatCapMaskTexture < string ResourceName = MATCAP_MASK_TEXTURE;>;
sampler2D MatCapMaskTextureSampler = sampler_state
{
    texture = <MatCapMaskTexture>;
    MAXANISOTROPY = TEXTURE_ANISOTROPY_LEVEL;
	MINFILTER = TEXTURE_FILTER; MAGFILTER = TEXTURE_FILTER; MIPFILTER = TEXTURE_MIP_FILTER;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};
#endif

float3 srgb2linear(float3 srgb) {
	return pow(max(srgb, 1e-5), 2.2);
}

float3 linear2srgb(float3 rgb) {
	return pow(max(rgb, 1e-5), 1.0/2.2);
}

float4 GetChannelMask(int swizzle) {
    if (swizzle == 0)
        return float4(1,0,0,0);
    else if (swizzle == 1)
        return float4(0,1,0,0);
    else if (swizzle == 2)
        return float4(0,0,1,0);
    else
        return float4(0,0,0,1);
}

float3 GetBaseColor(float2 uv, bool useTexture) {
    float3 color = BaseColorConst;

    uv = uv * BaseColorMapST.xy + BaseColorMapST.zw + BaseColorMapSpeed * time;

    #if BASE_COLOR_FROM == BASE_COLOR_FROM_PMX
    {
        color = saturate(MaterialDiffuse.rgb + MaterialAmbient.rgb);
        if (useTexture) {
            float4 c = tex2D(DiffuseTextureSampler, uv);
            color *= srgb2linear(c.rgb);
        }
    }
    #elif BASE_COLOR_FROM == BASE_COLOR_FROM_TEX
    {
        float4 c = tex2D(ColorTextureSampler, uv);
        color = srgb2linear(c.rgb);
    }
    #endif

    return color;
}

float3 GetBaseColorTint(int materialId) {
    const float3 tints[8] = {
        BaseColorTint0,
        BaseColorTint1,
        BaseColorTint2,
        BaseColorTint3,
        BaseColorTint4,
        BaseColorTint5,
        BaseColorTint6,
        BaseColorTint7
    };
    return tints[materialId];
}

float GetBaseColorGamma(int materialId) {
    const float gammas[8] = {
        BaseColorGamma0,
        BaseColorGamma1,
        BaseColorGamma2,
        BaseColorGamma3,
        BaseColorGamma4,
        BaseColorGamma5,
        BaseColorGamma6,
        BaseColorGamma7
    };
    return gammas[materialId];
}

float GetAlpha(float2 uv, bool useTexture) {
    float alpha = AlphaConst;

    uv = uv * BaseColorMapST.xy + BaseColorMapST.zw + BaseColorMapSpeed * time;

    #if BASE_ALPHA_FROM == BASE_ALPHA_FROM_PMX
    {
        alpha = MaterialDiffuse.a;
        if (useTexture) {
            alpha *= tex2D(DiffuseTextureSampler, uv).a;
        }
    }
    #elif BASE_ALPHA_FROM == BASE_ALPHA_FROM_TEX
    {
        alpha = tex2D(ColorTextureSampler, uv).a;
    }
    #endif

    alpha *= AlphaMultiplier;
    alpha = saturate(alpha);

    return alpha;
}

float3 UseSphere(float3 color, float3 normalVS, bool useSphereMap) {
	float3 final = color;
	if (useSphereMap) {
        float2 matCapUV = (normalVS.xy / 2.0 + 0.5) * float2(1, -1);
        float3 sphereColor = tex2D(SphereMapSampler, matCapUV).rgb;
		sphereColor = srgb2linear(sphereColor);
		if(spadd) {
			final += sphereColor;
		} else {
			final *= sphereColor;
		}
	}
	return final;
}

float3 UseMatCap(float3 color, float2 uv, float3 normalVS) {
    #ifdef MATCAP_TEXTURE
    {
        float2 matCapUV = (normalVS.xy / 2.0 + 0.5) * float2(1, -1);
        float3 capColor = tex2D(MatCapTextureSampler, matCapUV).rgb;
        capColor = srgb2linear(capColor);
        float mask = 1.0;
        #ifdef MATCAP_MASK_TEXTURE
        {
            uv = uv * MatCapMaskMapST.xy + MatCapMaskMapST.zw + MatCapMaskMapSpeed * time;
            mask = dot(tex2D(MatCapMaskTextureSampler, uv), GetChannelMask(MATCAP_MASK_SWIZZLE));
        }
        #endif
        #if MATCAP_BLEND_MODE == 0
        {
            float alpha = saturate(MatCapAlphaBurst * mask);
            float3 blendColor = MatCapColorTint * capColor * MatCapColorBurst;
            return lerp(color, blendColor, alpha);
        }
        #elif MATCAP_BLEND_MODE == 1
        {
            float alpha = saturate(MatCapAlphaBurst * mask);
            float3 blendColor = MatCapColorTint * capColor * MatCapColorBurst;
            return color + alpha * blendColor;
        }
        #elif MATCAP_BLEND_MODE == 2
        {
            float alpha = saturate(MatCapAlphaBurst * mask);
            float3 blendColor = saturate((capColor * MatCapColorTint - 0.5) * MatCapColorBurst + capColor * MatCapColorTint);
            blendColor = lerp(0.5, blendColor, alpha);
            return lerp(blendColor * color * 2, 1 - 2 * (1 - color) * (1 - blendColor), color >= 0.5);
        }
        #else
        {
            return color;
        }
        #endif
    }
    #else
    {
        return color;
    }
    #endif
}

int GetMaterialId(float2 uv) {
    int index = SubMaterialIndexConst;

    #if SUB_INDEX_FROM == SUB_INDEX_FROM_TEX
    {
        #if MATERIAL_DOMAIN == MATERIAL_DOMAIN_FACE
        {
            float4 faceMap = tex2D(FaceMapTextureSampler, uv);
            float a = dot(faceMap, GetChannelMask(SUB_INDEX_SWIZZLE));
            index = a < 0.2 ? 0 : (a < 0.7 ? 1 : 2);
        }
        #else
        {
            uv = uv * SubMaterialMapST.xy + SubMaterialMapST.zw + SubMaterialMapSpeed * time;
            float4 lightMap = tex2D(LightMapTextureSampler, uv);
            float a = dot(lightMap, GetChannelMask(SUB_INDEX_SWIZZLE));
            float w = 8 * a;
            w = floor(w);
            w = w * 0.125;
            w = frac(w);
            w *= 8;
            index = (int)w;
        }
        #endif
    }
    #endif

    return index;
}

float GetDiffuseThreshold(float2 uv) {
    float threshold = DiffuseThresholdConst;

    uv = uv * DiffuseThresholdMapST.xy + DiffuseThresholdMapST.zw + DiffuseThresholdMapSpeed * time;

    #if DIFFUSE_THRESHOLD_FROM == DIFFUSE_THRESHOLD_FROM_TEX
    {
        threshold = dot(tex2D(LightMapTextureSampler, uv), GetChannelMask(DIFFUSE_THRESHOLD_SWIZZLE));
    }
    #endif
    return threshold;
}

float3 SampleShadowColor(float attenuation, float shadow, float diffuseThreshold, int materialId, float3 lightDirectionWS) {
    float3 color = 1;
    const float gammas[8] = {
        RampGamma0,
        RampGamma1,
        RampGamma2,
        RampGamma3,
        RampGamma4,
        RampGamma5,
        RampGamma6,
        RampGamma7
    };
    float gamma = gammas[materialId];
    #if RAMP_COLOR_FROM == RAMP_COLOR_FROM_TEX
    {
        float threshold = diffuseThreshold;
        threshold = min(0.8, threshold);
        threshold = shadow < 0.1 ? threshold : 1;

        float fatten = max(0.001, attenuation);
        fatten = fatten * 0.85 + 0.15;
        fatten *= threshold;
        bool notShadow = ShadowRamp < attenuation; 
        float x = notShadow ? 1.0 : fatten;
        float y = (materialId * 2 + 1) * 0.0625;

        float3 cool = tex2Dlod(RampCoolTextureSampler, float4(x, 1 - y, 0, 0)).xyz;
        float3 warm = tex2Dlod(RampWarmTextureSampler, float4(x, 1 - y, 0, 0)).xyz;

        cool = srgb2linear(cool);
        warm = srgb2linear(warm);

        float lightDirY = saturate(lightDirectionWS.y * 2 - 1);

        color = lerp(cool, warm, lightDirY);

        if (!notShadow) {
            gamma += lerp(0, 10, uShadowGammaP);
            color = pow(max(1e-5, color), gamma);
            color *= (1 - uShadowDarkP);
        }
    }
    #else
    {
        const float3 shadowColors[8] = {
            ShadowColor0,
            ShadowColor1,
            ShadowColor2,
            ShadowColor3,
            ShadowColor4,
            ShadowColor5,
            ShadowColor6,
            ShadowColor7
        };
        float3 shadowColor = shadowColors[materialId];
        const float3 shallowColors[8] = {
            ShallowColor0,
            ShallowColor1,
            ShallowColor2,
            ShallowColor3,
            ShallowColor4,
            ShallowColor5,
            ShallowColor6,
            ShallowColor7
        };
        float3 shallowColor = shallowColors[materialId];
        const float2 ranges[8] = {
            ShadowRampRange0,
            ShadowRampRange1,
            ShadowRampRange2,
            ShadowRampRange3,
            ShadowRampRange4,
            ShadowRampRange5,
            ShadowRampRange6,
            ShadowRampRange7
        };
        float2 range = ranges[materialId];

        float fatten = saturate((attenuation - range.x) / (range.y - range.x));
        color = lerp(shadowColor, shallowColor, fatten);
        gamma += lerp(0, 10, uShadowGammaP);
        color = pow(max(1e-5, color), gamma);
        color *= (1 - uShadowDarkP);
        color = ShadowRamp < attenuation ? 1.0 : color;
    }
    #endif

    return color;
}

float3 ShadingStockings(float3 color, float2 uv, float3 normalVS, float3 viewDirectionVS) {
    float tile = StockingsTileConst;
    #if STOCKINGS_TILE_FROM == STOCKINGS_TILE_FROM_TEX
    {
        float2 uva = uv * StockingsTileMapST.xy + StockingsTileMapST.zw + StockingsTileMapSpeed * time;
        tile = dot(tex2D(StockingsTextureSampler, uva), GetChannelMask(STOCKINGS_TILE_SWIZZLE));
    }
    #endif
    tile = tile * 0.5 - 0.5;
    tile = StockingsRoughness * tile + 1;

    float mask = StockingsMaskConst;
    #if STOCKINGS_MASK_FROM == STOCKINGS_MASK_FROM_TEX
    {
        float2 uva = uv * StockingsMaskMapST.xy + StockingsMaskMapST.zw + StockingsMaskMapSpeed * time;
        mask = dot(tex2D(StockingsTextureSampler, uva), GetChannelMask(STOCKINGS_MASK_SWIZZLE));
    }
    #endif
    float bmask = mask > 0.001 ? 1 : 0;

    float stockPower = max(0.04, StockingsPower);
    float NoV = saturate(dot(normalVS, normalize(viewDirectionVS + StockingsOffset)));
    NoV = max(0.001, NoV);
    float stockDarkFade = smoothstep(stockPower, max(0, StockingsDarkWidth * stockPower), NoV);
    stockDarkFade *= StockingsLightIntensity;
    stockDarkFade *= bmask;
    stockDarkFade *= mask;

    float3 stockColor = lerp(1, StockingsDarkColor, stockDarkFade);
    stockColor = lerp(1, color * stockColor, stockDarkFade);
    stockColor *= color;

    float thickness = StockingsThicknessConst;
    #if STOCKINGS_THICKNESS_FROM == STOCKINGS_THICKNESS_FROM_TEX
    {
        float2 uva = uv * StockingsThicknessMapST.xy + StockingsThicknessMapST.zw + StockingsThicknessMapSpeed * time;
        thickness = dot(tex2D(StockingsTextureSampler, uva), GetChannelMask(STOCKINGS_THICKNESS_SWIZZLE));
    }
    #endif
    thickness *= tile;
    thickness *= (1 - StockingsThickness);

    float lighted = pow(NoV, StockingsLightWidth);
    lighted = max(0.004, lighted);
    lighted = saturate(lighted * thickness);

    stockColor = lerp(stockColor, StockingsColor, lighted);

    return stockColor;
}

float3 GetRimShadow(int materialId, float3 normalVS, float3 viewDirectionVS) {
    const float3 colors[8] = {
        RimShadowColor0,
        RimShadowColor1,
        RimShadowColor2,
        RimShadowColor3,
        RimShadowColor4,
        RimShadowColor5,
        RimShadowColor6,
        RimShadowColor7
    };
    float3 color = colors[materialId];
    const float widths[8] = {
        RimShadowWidth0,
        RimShadowWidth1,
        RimShadowWidth2,
        RimShadowWidth3,
        RimShadowWidth4,
        RimShadowWidth5,
        RimShadowWidth6,
        RimShadowWidth7
    };
    float width = widths[materialId];
    const float feathers[8] = {
        RimShadowFeather0,
        RimShadowFeather1,
        RimShadowFeather2,
        RimShadowFeather3,
        RimShadowFeather4,
        RimShadowFeather5,
        RimShadowFeather6,
        RimShadowFeather7
    };
    float feather = feathers[materialId];

    float NoV = saturate(dot(normalVS, normalize(viewDirectionVS + RimShadowOffset.xyz)));
    float p = pow(max(0.001, 1 - NoV), RimShadowPower);
    p *= width;
    p = saturate(p);
    p = smoothstep(feather, 1, p);
    p *= RimShadowIntensity * 0.25;
    p *= RimShadowMul;

    return lerp(1, color, p);
}

float3 GetSpecularColor(int materialId) {
    const float3 colors[8] = {
        SpecularColor0,
        SpecularColor1,
        SpecularColor2,
        SpecularColor3,
        SpecularColor4,
        SpecularColor5,
        SpecularColor6,
        SpecularColor7
    };
    return colors[materialId];
}

float GetSpecularShininess(int materialId) {
    const float values[8] = {
        SpecularShininess0,
        SpecularShininess1,
        SpecularShininess2,
        SpecularShininess3,
        SpecularShininess4,
        SpecularShininess5,
        SpecularShininess6,
        SpecularShininess7
    };
    return values[materialId];
}

float GetSpecularRoughness(int materialId) {
    const float values[8] = {
        SpecularRoughness0,
        SpecularRoughness1,
        SpecularRoughness2,
        SpecularRoughness3,
        SpecularRoughness4,
        SpecularRoughness5,
        SpecularRoughness6,
        SpecularRoughness7
    };
    return values[materialId];
}

float GetSpecularIntensity(int materialId) {
    const float values[8] = {
        SpecularIntensity0,
        SpecularIntensity1,
        SpecularIntensity2,
        SpecularIntensity3,
        SpecularIntensity4,
        SpecularIntensity5,
        SpecularIntensity6,
        SpecularIntensity7
    };
    return values[materialId];
}

float GetSpecularThreshold(float2 uv) {
    float threshold = SpecularThresholdConst;

    uv = uv * SpecularThresholdMapST.xy + SpecularThresholdMapST.zw + SpecularThresholdMapSpeed * time;

    #if SPECULAR_THRESHOLD_FROM == SPECULAR_THRESHOLD_FROM_TEX
    {
        threshold = dot(tex2D(LightMapTextureSampler, uv), GetChannelMask(SPECULAR_THRESHOLD_SWIZZLE));
    }
    #endif
    return threshold;
}

float3 GetEmissiveColor(float2 uv, float useTexture) {
    float3 color = EmissiveColorConst;

    uv = uv * EmissiveColorMapST.xy + EmissiveColorMapST.zw + EmissiveColorMapSpeed * time;

    #if EMISSIVE_COLOR_FROM == EMISSIVE_COLOR_FROM_PMX
    {
        color = saturate(MaterialDiffuse.rgb + MaterialAmbient.rgb);
        if (useTexture) {
            float4 c = tex2D(DiffuseTextureSampler, uv);
            color *= srgb2linear(c.rgb);
        }
    }
    #elif EMISSIVE_COLOR_FROM == EMISSIVE_COLOR_FROM_TEX
    {
        float4 c = tex2D(EmissiveTextureSampler, uv);
        color = srgb2linear(c.rgb);
    }
    #endif

    float mask = EmissiveMaskConst;

    #if EMISSIVE_MASK_FROM == EMISSIVE_MASK_FROM_TEX
    {
        mask = dot(tex2D(EmissiveTextureSampler, uv), GetChannelMask(EMISSIVE_MASK_SWIZZLE));
        mask = mask < 0.02 ? 0 : mask;
    }
    #endif

    color *= EmissiveColorTint;
    color = pow(max(1e-5, color), EmissiveGamma);
    color *= EmissiveIntensity;
    color *= mask;

    return color;
}

#if MATERIAL_DOMAIN == MATERIAL_DOMAIN_FACE
float GetFaceAttenuation(float2 uv, float3 lightDirectionWS) {
    float3 headForward = normalize(HeadBone._31_32_33) * float3(-1,-1,-1);
    float3 headRight  = normalize(HeadBone._11_12_13) * float3(-1,-1,-1);
    float3 headUp = cross(headForward, headRight);
    float3 lightDirectionProjHeadWS = normalize(lightDirectionWS - dot(lightDirectionWS, headUp) * headUp);

    float sX = dot(lightDirectionProjHeadWS, headRight);
    float sZ = dot(lightDirectionProjHeadWS, -headForward);
    float angleThreshold = atan2(sX, sZ) / 3.14159265359;
    angleThreshold = angleThreshold > 0 ? (1 - angleThreshold) : (1 + angleThreshold);

    bool b = dot(lightDirectionProjHeadWS, headRight) < 0;
    float angleMapping = dot(tex2D(FaceMapTextureSampler, float2(b ? uv : float2(1.0 - uv.x, uv.y))), GetChannelMask(FACE_THRESHOLD_SWIZZLE));

    float softness = clamp(FaceThresholdSoftness, 1e-5, 1);
    return smoothstep(angleThreshold - FaceThresholdSoftness, angleThreshold + FaceThresholdSoftness, angleMapping);
}

float GetNoseLineMask(float2 uv) {
    return dot(tex2D(FaceMapTextureSampler, uv), GetChannelMask(NOSE_LINE_SWIZZLE));
}

float3 GetEyesEffect(float2 uv) {
    #if ANMIATED_EYES
    {
        if (uv.x < 1e-5 || uv.y < 1e-5) return 0;
        uv = float2(uv.x, 1.0 - uv.y);
        uv = uv * EyesAnimatedST.xy + EyesAnimatedST.zw;
        uv = uv * 2.0 - 1.0;
        float hollow = length(uv);
        hollow = smoothstep(EyesAnimatedHollowRange.x, EyesAnimatedHollowRange.y, hollow);
        float2 n = normalize(uv);
        uv += n * frac(time * EyesAnimatedSpeed);
        float l = length(uv);
        l = l - frac(l);
        uv -= l * n;
        uv = uv * 0.5 + 0.5;
        float3 c = tex2Dlod(EyesEffectTextureSampler, float4(uv, 0, 0)).rgb;
        return c * EyesAnimatedColor * hollow;
    }
    #endif
    return 0;
}

#endif

float3x3 CreateViewRotate() {
	float pitch = (uUp - uBottom) * PI / 2.0;
	float yaw   = (uRight - uLeft) * PI / 2.0;

	float cosYaw   = cos(yaw);
	float sinYaw   = sin(yaw);
	float cosPitch = cos(pitch);
	float sinPitch = sin(pitch);

	float3x3 rotY = {
		cosYaw, 0, sinYaw,
		0,      1, 0,
		-sinYaw, 0, cosYaw
	};

	float3x3 rotX = {
		1, 0,        0,
		0, cosPitch, -sinPitch,
		0, sinPitch, cosPitch
	};

	return mul(rotY, rotX);
}

float4x4 CreateOrthographicMatrix(float left, float right, float bottom, float top, float znear, float zfar)
{
    float4x4 orthoMatrix;

    orthoMatrix[0][0] = 2.0f / (right - left);
    orthoMatrix[0][1] = 0.0f;
    orthoMatrix[0][2] = 0.0f;
    orthoMatrix[0][3] = 0.0f;

    orthoMatrix[1][0] = 0.0f;
    orthoMatrix[1][1] = 2.0f / (top - bottom);
    orthoMatrix[1][2] = 0.0f;
    orthoMatrix[1][3] = 0.0f;

    orthoMatrix[2][0] = 0.0f;
    orthoMatrix[2][1] = 0.0f;
    orthoMatrix[2][2] = 1.0f / (zfar - znear);
    orthoMatrix[2][3] = 0.0f;

    orthoMatrix[3][0] = -(right + left) / (right - left);
    orthoMatrix[3][1] = -(top + bottom) / (top - bottom);
    orthoMatrix[3][2] = -znear / (zfar - znear);
    orthoMatrix[3][3] = 1.0f;

    return orthoMatrix;
}

float SampleCompare(sampler source, float2 shadowCoord, float depth) {
	float s = tex2Dlod(source, float4(shadowCoord, 0, 0)).r;
	return s < 1e-5 ? 1 : (s > depth ? 1 : 0);
}

float3 GetStarrySkyBaseColor(float2 uv, bool useTexture) {
#if STARRYSKY
    float3 skyColor = SkyColorConst;
    #if STARRYSKY_COLOR_FROM == STARRYSKY_COLOR_FROM_PMX
    {
        skyColor = saturate(MaterialDiffuse.rgb + MaterialAmbient.rgb);
        if (useTexture) {
            float2 auv = uv * SkyMapST.xy + SkyMapST.zw + time * SkyMapSpeed;
            float4 c = tex2D(DiffuseTextureSampler, auv);
            skyColor *= srgb2linear(c.rgb);
        }
    }
    #elif STARRYSKY_COLOR_FROM == STARRYSKY_COLOR_FROM_TEX
    {
        float2 auv = uv * SkyMapST.xy + SkyMapST.zw + time * SkyMapSpeed;
        float4 c = tex2D(SkyTextureSampler, auv);
        skyColor = srgb2linear(c.rgb);
    }
    #endif
    return skyColor;
#else
    return 0;
#endif
}

float2 GetStarrySkyMask(float2 uv) {
#if STARRYSKY
    float2 skyMask = SkyMaskConst;
    #if STARRYSKY_MASK_FROM == STARRYSKY_MASK_FROM_TEX
    {
        float2 auv = uv * SkyMaskMapST.xy + SkyMaskMapST.zw + time * SkyMaskMapSpeed;
        float4 c = tex2D(SkyMaskTextureSampler, auv);
        skyMask.x = dot(c, GetChannelMask(STARRYSKY_MASK_A_SWIZZLE));
        skyMask.y = dot(c, GetChannelMask(STARRYSKY_MASK_B_SWIZZLE));
    }
    #endif
    return skyMask;
#else
    return 0;
#endif
}

float3 ShadingStarrySky(float2 skyMask,float4 positionNDC, float3 positionWS, float3 positionOS, float3 normalWS, float3 viewDirectionWS, float2 uv, bool useTexture) {
    #if STARRYSKY
    float2 maskRange = skyMask + SkyRange;

    float2 screenUV = positionNDC.xy / positionNDC.w;
    screenUV.y = 1.0 - screenUV.y;
    screenUV.y = (screenUV.y * 2.0 - 1.0) * ViewportSize.y / ViewportSize.x * 0.5 + 0.5;
    float3 cameraPositionWS = CameraPosition;
    float distance = length(cameraPositionWS - positionWS);
    float2 starUV = (screenUV - 0.5) * distance / 12.5 * SkyStarDepthScale * SkyStarMapST.xy + SkyStarMapST.zw + time * SkyStarMapSpeed;
    float3 starColor = SkyStarColorConst.x;
    #if STARRYSKY_STAR_FROM == STARRYSKY_STAR_FROM_TEX
    {
        starColor = tex2D(SkyStarTextureSampler, starUV).rrr;
    }
    #endif
    starColor *= SkyStarColor * SkyStarTexScale * maskRange.x;

    float3 starMaskP = SkyStarMaskConst;
    float3 starMaskN = SkyStarMaskConst;
    #if STARRYSKY_STAR_MASK_FROM == STARRYSKY_STAR_MASK_FROM_TEX
    {
        float2 auv = uv * SkyStarMaskMapST.xy + SkyStarMaskMapST.zw + time * SkyStarMaskMapSpeed;
        starMaskP = tex2D(SkyStarMaskTextureSampler, auv + time * SkyStarMaskTexSpeed).xyz;
        starMaskN = tex2D(SkyStarMaskTextureSampler, auv + -time * SkyStarMaskTexSpeed).xyz;
    }
    #endif
    float3 starMask = starMaskP + starMaskN;
    starMask *= SkyStarMaskTexScale;

    float3 positionOSScaled = positionOS / 12.5 / OSScale;
    float3 oscoord = float3(
        smoothstep(0, 1, (1 - 2 * positionOSScaled.yz) * 0.5),
        smoothstep(0, 1, (1 - positionOSScaled.x) * 0.5)
    );
    float starColorW = SkyStarColorConst.w;
    #if STARRYSKY_STAR_FROM == STARRYSKY_STAR_FROM_TEX
    {
        float2 wuv = oscoord.yz * 20.0;
        starColorW = tex2D(SkyStarTextureSampler, wuv).w;
    }
    #endif

    float2 starColorYZ = SkyStarColorConst.yz;
    #if STARRYSKY_STAR_FROM == STARRYSKY_STAR_FROM_TEX
    {
        starColorYZ = tex2D(SkyStarTextureSampler, uv).yz;
    }
    #endif

    float starColorX_0 = SkyStarColorConst.x;
    float starColorX_1 = SkyStarColorConst.x;
    #if STARRYSKY_STAR_FROM == STARRYSKY_STAR_FROM_TEX
    {
        float2 uv0 = oscoord.xz * SkyStarMapST.xy + SkyStarMapST.zw;
        float2 uv1 = oscoord.yz * SkyStarMapST.xy + SkyStarMapST.zw;
        starColorX_0 = tex2D(SkyStarTextureSampler, uv0).x;
        starColorX_1 = tex2D(SkyStarTextureSampler, uv1).x;
    }
    #endif

    float3 starXYZWColor = (starColorX_0 - starColorX_1) * starColorYZ.y + starColorX_1;
    starXYZWColor *= saturate((starColorW - starColorYZ.x * StarDensity) / (1.0 - StarDensity));
    starXYZWColor *= SkyStarColor;
    starXYZWColor *= SkyStarTexScale;

    float3 dp1 = ddx(positionWS);
	float3 dp2 = ddy(positionWS);
	float2 duv1 = ddx(uv);
	float2 duv2 = ddy(uv);
	float3x3 M = float3x3(dp1, dp2, normalWS);
	float2x3 I = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
	float3 T = mul(float2(duv1.x, duv2.x), I);
	float scaleT = 1.0f / (dot(T, T) + 1e-6);
	float3 tangentWS = normalize(T * scaleT);
    float3 tangentVS = mul(tangentWS, (float3x3)matView);

    float3 viewDirectionVS = mul(viewDirectionWS, (float3x3)matView);
    float TdotV = dot(tangentVS, viewDirectionVS);
    float invToV = 1.0 - TdotV;
    float zz = invToV * invToV;
    float invToV6 = zz * zz * zz;
    float fresnel = smoothstep(0.5, SkyFresnelSmooth, 
        (1.0 - SkyFresnelBaise) * invToV6 + SkyFresnelBaise
    );
    float3 fresnelColor = fresnel * SkyFresnelScale * SkyFresnelColor;

    float3 color = lerp(starColor * starMask.x * maskRange.x, starXYZWColor * starMask.xyz, StarMode);
    color += fresnelColor * maskRange.y;
 
    return color;
    #else
    return 0;
    #endif
}

float3 GetNormal(float3 positionWS, float2 uv, float3 normalWS) {
#ifdef NORMALMAP_TEXTURE
{
    float2 suv = uv * NormalMapST.xy + NormalMapST.zw + NormalMapSpeed * time;
    float4 t = tex2D(NormalMapTextureSampler, suv);
    float r = dot(t, GetChannelMask(NORMALMAP_X_SWIZZLE));
    float g = dot(t, GetChannelMask(NORMALMAP_Y_SWIZZLE));
    #if NORMALMAP_INVERT_Y_CHANNEL
    g = 1.0 - g;
    #endif
    r = r * 2.0 - 1.0;
    g = g * 2.0 - 1.0;
    float3 normalTS = float3(r, g, 1);
    normalTS.xy *= NormalScale;
    normalTS.z = sqrt(1 - min(1.0, dot(normalTS.xy, normalTS.xy)));
    normalTS = normalize(normalTS);

    float3 dp1 = ddx(positionWS);
	float3 dp2 = ddy(positionWS);
	float2 duv1 = ddx(uv);
	float2 duv2 = ddy(uv);
	float3x3 M = float3x3(dp1, dp2, normalWS);
	float2x3 I = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
	float3 T = mul(float2(duv1.x, duv2.x), I);
	float3 B = mul(float2(duv1.y, duv2.y), I);
	float scaleT = 1.0f / (dot(T, T) + 1e-6);
	float scaleB = 1.0f / (dot(B, B) + 1e-6);
    float3 tangentWS = normalize(T * scaleT);
    float3 bitangentWS = -normalize(B * scaleB);
    float3x3 tbnTransform;
	tbnTransform[0] = tangentWS;
	tbnTransform[1] = bitangentWS;
	tbnTransform[2] = normalWS;
    return normalize(mul(normalTS, tbnTransform));
}
#else
{
    return normalize(normalWS);
}
#endif
}

struct Attributes {
    float4 positionOS : POSITION;
    float3 normalOS   : NORMAL;
    float2 texcoord0   : TEXCOORD0;
    float2 texcoord1   : TEXCOORD1;
};

struct Varyings {
	float4 positionCS		    : SV_POSITION;	
    float4 uv		            : TEXCOORD0;
    float4 positionWSAndDepth   : TEXCOORD1;
	float3 normalWS	            : TEXCOORD2;	
	float3 viewDirectionWS		: TEXCOORD3;
    float3 positionOS           : TEXCOORD4;
    float4 positionNDC          : TEXCOORD5;
    #if SHADOW_MODE == 1
    float4 shadowCoord          : TEXCOORD6;
    #endif
};

Varyings vert(Attributes input) {
    Varyings output = (Varyings)0;

    float3 positionWS = mul(input.positionOS, matWorld).xyz;
    float4 positionCS = mul(input.positionOS, matWorldViewProject);

	output.positionCS = positionCS;
    output.uv = float4(input.texcoord0, input.texcoord0);
    output.positionWSAndDepth.xyz = positionWS;
    output.positionWSAndDepth.w = positionCS.w;
    output.viewDirectionWS = CameraPosition - output.positionWSAndDepth.xyz;
    output.normalWS = normalize(mul(input.normalOS, (float3x3)matWorld));
    output.positionOS = input.positionOS.xyz;
    output.positionNDC = float4(
        positionCS.w * 0.5 + positionCS.x * 0.5,
        positionCS.w * 0.5 + positionCS.y * 0.5,
        positionCS.z,
        positionCS.w
    );

    #if SHADOW_MODE == 1
    {
        float3x3 viewRotate = CreateViewRotate();
        float3x3 oldRotate = (float3x3)matView;
        float3x3 newRotate = mul(oldRotate, viewRotate);

        float3 forward = newRotate[2];
        forward.xy *= -1;

        float radius = lerp(6.25, 31.25, uRange);
        float3 centerWS = uCenter;
        float3 cameraPosWS = centerWS + normalize(-forward) * radius;
        float3 t = mul(-cameraPosWS, newRotate);

        float4x4 viewMatrix = float4x4(
            newRotate[0], 0,
            newRotate[1], 0,
            newRotate[2], 0,
            t,      1
        );

        float3 positionVS = mul(float4(positionWS, 1), viewMatrix).xyz;
        float3 centerVS = mul(float4(centerWS, 1), viewMatrix).xyz;

        float4x4 projMatrix = CreateOrthographicMatrix(
            centerVS.x - radius, 
            centerVS.x + radius, 
            centerVS.y - radius, 
            centerVS.y + radius, 
            centerVS.z - radius,
            centerVS.z + radius
        );

        float4 positionCS = mul(float4(positionVS, 1), projMatrix);

        output.shadowCoord = positionCS;
        output.shadowCoord.z = positionVS.z;
    }
    #endif

    return output;
}

float4 frag(Varyings input, float vFace : VFACE, uniform bool useTexture, uniform bool useSphereMap, uniform bool useSelfShadow) : COLOR0 {
    float2 uv = vFace > 0 ? input.uv.xy : input.uv.zw;
    float3 rawBaseColor = GetBaseColor(uv, useTexture);
    float alpha = GetAlpha(uv, useTexture);

    float3 skyBaseColor = GetStarrySkyBaseColor(uv, useTexture);
    float2 skyMask = GetStarrySkyMask(uv);
    rawBaseColor = lerp(rawBaseColor, skyBaseColor, skyMask.x);

    float3 normalWS = GetNormal(input.positionWSAndDepth.xyz, uv, input.normalWS);
    normalWS *= vFace > 0 ? 1 : -1;
    float3 normalVS = mul(normalWS, (float3x3)matView);

    float3 viewDirectionWS = normalize(input.viewDirectionWS);
    float3 viewDirectionVS = mul(viewDirectionWS, (float3x3)matView);

    int materialId = GetMaterialId(uv);
    rawBaseColor *= GetBaseColorTint(materialId);
    rawBaseColor = pow(max(1e-5, rawBaseColor), GetBaseColorGamma(materialId));
    float3 baseColor = ShadingStockings(rawBaseColor, uv, normalVS, viewDirectionVS);
    baseColor = UseSphere(baseColor, normalVS, useSphereMap);
    baseColor = UseMatCap(baseColor, uv, normalVS);

    float diffuseThreshold = GetDiffuseThreshold(uv);

    float3 lightDirectionWS = normalize(-LightDirection);
    float NoL = dot(normalWS, lightDirectionWS);
    float attenuation = saturate(NoL * 0.5 + 0.5) * 2 * diffuseThreshold;

    float shadow = 1;
    #if SHADOW_MODE == 1
    if (useSelfShadow)
    {
        float depth = input.shadowCoord.z;
        float2 shadowCoord = input.shadowCoord.xy / input.shadowCoord.w;
        shadowCoord = shadowCoord * 0.5 + 0.5;
        shadowCoord.y = 1.0 - shadowCoord.y;

        float4 attenuation4;
        float invShadowAtlasWidth = 1.0 / SHADOW_MAP_SIZE;
        float invShadowAtlasHeight = 1.0 / SHADOW_MAP_SIZE;
        float invHalfShadowAtlasWidth = 0.5f * invShadowAtlasWidth;
        float invHalfShadowAtlasHeight = 0.5f * invShadowAtlasHeight;
        float2 offset = float2(invHalfShadowAtlasWidth, invHalfShadowAtlasHeight);
        attenuation4.x = SampleCompare(ZBufferMapSamp, shadowCoord.xy + offset * float2(-1, -1), depth);
        attenuation4.y = SampleCompare(ZBufferMapSamp, shadowCoord.xy + offset * float2(+1, -1), depth);
        attenuation4.z = SampleCompare(ZBufferMapSamp, shadowCoord.xy + offset * float2(-1, +1), depth);
        attenuation4.w = SampleCompare(ZBufferMapSamp, shadowCoord.xy + offset * float2(+1, +1), depth);
        shadow = dot(attenuation4, 0.25);
    }
    #endif

    #if MATERIAL_DOMAIN == MATERIAL_DOMAIN_FACE
    {
        attenuation = materialId == 0 ? GetFaceAttenuation(uv, lightDirectionWS) : 1;
    }
    #endif
    attenuation *= shadow;

    float3 shadowColor = SampleShadowColor(attenuation, shadow, diffuseThreshold, materialId, lightDirectionWS);
    float3 rimShadow = GetRimShadow(materialId, normalVS, viewDirectionVS);

    float3 diffuseColor = baseColor * shadowColor * rimShadow;
    float3 specularColor = GetSpecularColor(materialId);
    {
        float3 halfWS = normalize(viewDirectionWS + lightDirectionWS);
        float NoH = dot(normalWS, halfWS);

        float shininess = GetSpecularShininess(materialId);
        float roughness = GetSpecularRoughness(materialId);
        float intensity = GetSpecularIntensity(materialId);
        float threshold = GetSpecularThreshold(uv);

        float blinnPhong = pow(max(0.001, NoH), shininess);
        blinnPhong *= (shadow * 0.6 + 0.4);
        roughness = max(0.001, roughness);
        blinnPhong = smoothstep(1 - threshold - roughness, 1 - threshold + roughness, blinnPhong);

        specularColor *= blinnPhong * intensity * rawBaseColor * SpecularMul;
    }
    float3 emissiveColor = GetEmissiveColor(uv, useTexture);
    emissiveColor *= lerp(1.0, float3(0.6,0.45,0.25), pow(1.0 - saturate(dot(normalWS, viewDirectionWS)), 2.5));

    float3 lightColor = LightColor;
    float maxLightP = max(max(uLightRP, uLightGP), uLightBP);
    float minLightP = min(min(uLightRP, uLightGP), uLightBP);
    float minmaxLightDiff = maxLightP - minLightP;
    if (minmaxLightDiff > 1e-5) {
        float3 colorRatio = (float3(uLightRP, uLightGP, uLightBP) - minLightP) / minmaxLightDiff;
        float3 colorTint = colorRatio * minmaxLightDiff + 1.0 - minmaxLightDiff;
        lightColor *= colorTint;
    }
    lightColor *= LightIntensity;

    float3 albedo = (diffuseColor + specularColor) * lightColor + emissiveColor;

    #if MATERIAL_DOMAIN == MATERIAL_DOMAIN_FACE
    {
        float3 effect = materialId == 1 ? GetEyesEffect(uv) : 0;
        albedo += effect;
    }
    #endif
    albedo = pow(max(1e-5, albedo), Gamma);
    #if MATERIAL_DOMAIN == MATERIAL_DOMAIN_FACE && NOSE_LINE_ENABLE
    {
        float3 headForward = normalize(HeadBone._31_32_33) * float3(-1,-1,-1);
        float3 headRight  = normalize(HeadBone._11_12_13) * float3(-1,-1,-1);
        float3 headUp = normalize(cross(headForward, headRight));

        float viewDotHeadUp = dot(headUp, viewDirectionWS);
        float viewDotHeadForward = dot(headForward, viewDirectionWS);

        float mask = GetNoseLineMask(uv);

        float dispValue = lerp(0.62, 0.92, smoothstep(0, 0.75, saturate(0.85 + viewDotHeadUp)));
        dispValue = viewDotHeadForward - dispValue;
        dispValue = smoothstep(0, 0.02, dispValue);
        dispValue -= mask;

        albedo = lerp(albedo, NoseLineColor, saturate(mask));
    }
    #endif

    float3 skyColor = ShadingStarrySky(
        skyMask,
        input.positionNDC, 
        input.positionWSAndDepth.xyz, 
        input.positionOS, 
        normalWS,
        viewDirectionWS,
        uv, 
        useTexture);
    albedo += skyColor;

    float4 color = float4(albedo, alpha);

    color.rgb = linear2srgb(color.rgb);

    return color;
}

#define OBJECT_TEC(name, mmdpass, usetexture, usesphere, useselfshadow)\
	technique name<string MMDPass = mmdpass;\
	string Script =\
		"RenderColorTarget0=;"\
		"Pass=DrawObject;"\
	;\
	bool UseTexture = usetexture;\
	bool UseSphereMap = usesphere;\
    bool UseSelfShadow = useselfshadow;>{\
		pass DrawObject {\
			VertexShader = compile vs_3_0 vert();\
			PixelShader  = compile ps_3_0 frag(usetexture, usesphere, useselfshadow);\
		}\
	}

OBJECT_TEC(MainTec0, "object", false, false, false)
OBJECT_TEC(MainTecBS0, "object_ss", false, false, true)
OBJECT_TEC(MainTec1, "object", true, false, false)
OBJECT_TEC(MainTecBS1, "object_ss", true, false, true)
OBJECT_TEC(MainTec2, "object", false, true, false)
OBJECT_TEC(MainTecBS2, "object_ss", false, true, true)
OBJECT_TEC(MainTec3, "object", true, true, false)
OBJECT_TEC(MainTecBS3, "object_ss", true, true, true)