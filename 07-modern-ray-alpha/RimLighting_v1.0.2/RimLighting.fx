////  RimLighting.fx
//  RimLighting
//
//  Created by 洪梓嫣 on 2025/4/20.
//  Copyright © 2019 Bilibili. All rights reserved.
//

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset  = 0.5 / ViewportSize;

float4x4 matView               : VIEW;

float3 SunColor : SPECULAR< string Object = "Light";>;
float3 SunDirection : DIRECTION< string Object = "Light";>;

float mRimLightWidthP : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "Width+";>;
float mRimLightWidthM : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "Width-";>;
float mRimLightIntensityP : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "Intensity+";>;
float mRimLightIntensityM : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "Intensity-";>;
float mRimLightFadeP : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "Fade+";>;
float mRimLightFadeM : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "Fade-";>;
float mRimLightThresholdP : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "Threshold+";>;
float mRimLightThresholdM : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "Threshold-";>;
float mRimLightHueP : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "Hue+";>;
float mRimLightHueM : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "Hue-";>;
float mRimLightSaturationP : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "Saturation+";>;
float mRimLightSaturationM : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "Saturation-";>;
float mRimLightRP : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "R+";>;
float mRimLightGP : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "G+";>;
float mRimLightBP : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "B+";>;
float mRimLightTintP : CONTROLOBJECT<string name="rim_controller.pmx"; string item = "Tint+";>;

static float mRimLightWidth = lerp(lerp(5, 20, mRimLightWidthP), 0, mRimLightWidthM);
static float mRimLightIntensity = lerp(lerp(1, 10, mRimLightIntensityP), 0, mRimLightIntensityM);
static float mRimLightFade = lerp(lerp(0.8, 0, mRimLightFadeP), 1, mRimLightFadeM);
static float mRimLightThreshold = lerp(lerp(0.625, 1, mRimLightThresholdP), 0, mRimLightThresholdM);
static float mRimLightHue = lerp(lerp(0.5, 1.0, mRimLightHueP), 0.0, mRimLightHueM);
static float mRimLightSaturation = lerp(lerp(1.0, 2.0, mRimLightSaturationP), 0.0, mRimLightSaturationM);

texture ScnMap : RENDERCOLORTARGET <
	float2 ViewportRatio = {1.0,1.0};
	bool AntiAlias = false;
	string Format = "A16B16G16R16F";
>;
sampler ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
	AddressU  = CLAMP; AddressV = CLAMP;
};
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET<
	float2 ViewportRatio = {1.0,1.0};
	string Format = "D24S8";
>;

shared texture ZBufferMap: OFFSCREENRENDERTARGET<
	string Description = "Z Buffer map";
	float2 ViewportRatio = {1.0, 1.0};
	float4 ClearColor = { 0, 0, 0, 0 };
	float ClearDepth = 1.0;
	string Format = "R16F";
	string DefaultEffect =
		"self = hide;"
		"*fog.pmx=hide;"
		"*controller*.pmx=hide;"
		"*editor*.pmx=hide;"
		"Volumetric*.pmx=hide;"
		"sky*box*.* = ./zbuffer_on.fx;"
		"sky*cloud*.* = ./zbuffer_on.fx;"
		"LED*.pmx =./zbuffer_on.fx;"
		"*Light*.pmx =./zbuffer_on.fx;"
		"*.pmd = ./zbuffer_on.fx;"
		"*.pmx = ./zbuffer_on.fx;"
		"*.x = hide;"
		"* = hide;";
>;

sampler ZBufferMapSamp = sampler_state {
	texture = <ZBufferMap>;
	MinFilter = NONE; MagFilter = NONE; MipFilter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};

float3 srgb2linear(float3 rgb) {
	return pow(max(rgb, 1e-5), 2.2);
}

float4 srgb2linear(float4 c) {
	return float4(srgb2linear(c.rgb), c.a);
}

float3 linear2srgb(float3 srgb) {
	srgb = max(6.10352e-5, srgb);
	return min(srgb * 12.92, pow(max(srgb, 0.00313067), 1.0/2.4) * 1.055 - 0.055);
}

float4 linear2srgb(float4 c) {
	return float4(linear2srgb(c.rgb), c.a);
}


float3 rgb_to_hsv(float3 rgb) {
  float h, s, v;

  float cmax = max(rgb[0], max(rgb[1], rgb[2]));
  float cmin = min(rgb[0], min(rgb[1], rgb[2]));
  float cdelta = cmax - cmin;

  v = cmax;
  if (cmax != 0.0) {
    s = cdelta / cmax;
  }
  else {
    s = 0.0;
    h = 0.0;
  }

  if (s == 0.0) {
    h = 0.0;
  }
  else {
    float3 c = (cmax - rgb) / cdelta;

    if (rgb.x == cmax) {
      h = c[2] - c[1];
    }
    else if (rgb.y == cmax) {
      h = 2.0 + c[0] - c[2];
    }
    else {
      h = 4.0 + c[1] - c[0];
    }

    h /= 6.0;

    if (h < 0.0) {
      h += 1.0;
    }
  }

  return float3(h, s, v);
}

float3 hsv_to_rgb(float3 hsv) {
  float i, f, p, q, t, h, s, v;
  float3 rgb;

  h = hsv[0];
  s = hsv[1];
  v = hsv[2];

  if (s == 0.0) {
    rgb = v;
  }
  else {
    if (h == 1.0) {
      h = 0.0;
    }

    h *= 6.0;
    i = floor(h);
    f = h - i;
    rgb = f;
    p = v * (1.0 - s);
    q = v * (1.0 - (s * f));
    t = v * (1.0 - (s * (1.0 - f)));

    if (i == 0.0) {
      rgb = float3(v, t, p);
    }
    else if (i == 1.0) {
      rgb = float3(q, v, p);
    }
    else if (i == 2.0) {
      rgb = float3(p, v, t);
    }
    else if (i == 3.0) {
      rgb = float3(p, q, v);
    }
    else if (i == 4.0) {
      rgb = float3(t, p, v);
    }
    else {
      rgb = float3(v, p, q);
    }
  }

  return rgb;
}

float3 hue_sat_value(float3 col, float hue, float sat, float value, float fac = 1) {
  float3 hsv = rgb_to_hsv(col);

  hsv[0] = frac(hsv[0] + hue + 0.5);
  hsv[1] = clamp(hsv[1] * sat, 0.0, 1.0);
  hsv[2] = hsv[2] * value;

  float3 rgb = hsv_to_rgb(hsv);

  return lerp(col, rgb, fac);
}

float4 ScreenSpaceQuadOffsetVS(
	in float4 Position : POSITION,
	in float2 Texcoord : TEXCOORD,
	out float2 oTexcoord : TEXCOORD0,
	uniform float2 offset) : POSITION {
	oTexcoord = Texcoord + offset;
	return Position;
}

float4 RimLightingPS(in float4 coord: TEXCOORD0, uniform sampler source) : COLOR {
	float3 color = tex2Dlod(source, float4(coord.xy, 0, 0)).rgb;
  color = srgb2linear(color);

  const float maxDepth = 5000.0;

  float linearEyeDepth = tex2Dlod(ZBufferMapSamp, float4(coord.xy, 0, 0)).r;
  bool mask = linearEyeDepth > 1e-5;
  if (mask) {
    linearEyeDepth = abs(linearEyeDepth);
    linearEyeDepth = linearEyeDepth <= 1e-5 ? maxDepth : linearEyeDepth;

    float perspective = 0.05/(12.5 + linearEyeDepth);
    float width = max(0, mRimLightWidth) * perspective;

    float3 lightDirectionVS = normalize(mul(-SunDirection, (float3x3)matView));

    float2 offset = lightDirectionVS.xy * width * float2(1, -1);
    float offsetLinearEyeDepth = abs(tex2Dlod(ZBufferMapSamp, float4(coord.xy + offset, 0, 0)).r);
    offsetLinearEyeDepth = offsetLinearEyeDepth <= 1e-5 ? maxDepth : offsetLinearEyeDepth;
    float rimLight = saturate((offsetLinearEyeDepth - (linearEyeDepth + mRimLightThreshold)) * mRimLightFade);
    rimLight *= mRimLightIntensity;

    float3 rimColor = rimLight * SunColor * lerp(1, color, mRimLightTintP);

    float maxRimP = max(max(mRimLightRP, mRimLightGP), mRimLightBP);
    float minRimP = min(min(mRimLightRP, mRimLightGP), mRimLightBP);
    float minmaxRimDiff = maxRimP - minRimP;
    if (minmaxRimDiff > 1e-5) {
        float3 colorRatio = (float3(mRimLightRP, mRimLightGP, mRimLightBP) - minRimP) / minmaxRimDiff;
        float3 colorTint = colorRatio * minmaxRimDiff + 1.0 - minmaxRimDiff;
        rimColor *= colorTint;
    }

    rimColor = hue_sat_value(
        rimColor, 
        mRimLightHue,
        mRimLightSaturation,
        mRimLightIntensity
    );
    color += rimColor;
  }
  color = linear2srgb(color);

	return float4(color, 1);
}

float Script : STANDARDSGLOBAL<
	string ScriptOutput = "color";
	string ScriptClass  = "scene";
	string ScriptOrder  = "postprocess";
> = 0.8;

const float4 ClearColor  = float4(0,0,0,0);
const float ClearDepth  = 1.0;

technique RimLighting <
	string Script = 
	"RenderColorTarget0=;"
	"ClearSetColor=ClearColor;"
	"ClearSetDepth=ClearDepth;"

	"RenderColorTarget0=ScnMap;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
	"ScriptExternal=Color;"

	"RenderColorTarget=;"
	"RenderDepthStencilTarget=;"
	"Pass=RimLighting;"
;> {
	pass RimLighting<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(ViewportOffset);
		PixelShader  = compile ps_3_0 RimLightingPS(ScnSamp);
	}
}