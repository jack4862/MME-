////  Shadow.fx
//  MMDStarRail4Fun
//
//  Created by 洪梓嫣 on 2025/4/20.
//  Copyright © 2019 Bilibili. All rights reserved.
//

#define SHADOW_MAP_SIZE 4096

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET<
	float2 ViewportRatio = {1.0,1.0};
	string Format = "D24S8";
>;

shared texture FunZBufferMap: OFFSCREENRENDERTARGET<
	string Description = "Z Buffer map";
	int2 Dimensions = { SHADOW_MAP_SIZE, SHADOW_MAP_SIZE };
	float4 ClearColor = { 0, 0, 0, 0 };
	float ClearDepth = 1.0;
	string Format = "R32F";
	string DefaultEffect =
		"self = hide;"
		"*fog.pmx=hide;"
		"*controller*.pmx=hide;"
		"*editor*.pmx=hide;"
		"Volumetric*.pmx=hide;"
		"sky*box*.* = ./Shadow_zbuffer.fx;"
		"sky*cloud*.* = ./Shadow_zbuffer.fx;"
		"LED*.pmx =./Shadow_zbuffer.fx;"
		"*Light*.pmx =./Shadow_zbuffer.fx;"
		"*.pmd = ./Shadow_zbuffer.fx;"
		"*.pmx = ./Shadow_zbuffer.fx;"
		"*.x = hide;"
		"* = hide;";
>;

float Script : STANDARDSGLOBAL<
	string ScriptOutput = "color";
	string ScriptClass  = "scene";
	string ScriptOrder  = "postprocess";
> = 0.8;

technique Shadow <
	string Script = 
	"RenderColorTarget0=;"
	"RenderDepthStencilTarget=;"
	"ScriptExternal=Color;"
;> {}