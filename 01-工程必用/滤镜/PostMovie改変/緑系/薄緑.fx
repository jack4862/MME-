//映画っぽくなるかもしれないしそんな事も無いかもしれないエフェクト

//全体彩度
float Saturation = 0.7;

//全体明度
float Bright = 0.65;

//全体色調
float3 LightColor = float3(105,176,118);

//グラデ大きさ
float GradationScale = 1.0;
//グラデ色
float3 GradColor = float3(45,47,72);

//汚し素材テクスチャ
#define MASKTEX "mask.png"

//汚し素材透明度
float MaskAlpha = 0.0;

//コントラスト制御
float Contrast = 1.0;


#define CONTROLLER "PostMovieコントローラ.pmx"
bool bCont : CONTROLOBJECT < string name = CONTROLLER;>;
float morph_r : CONTROLOBJECT < string name = CONTROLLER; string item = "赤"; >;
float morph_g : CONTROLOBJECT < string name = CONTROLLER; string item = "緑"; >;
float morph_b : CONTROLOBJECT < string name = CONTROLLER; string item = "青"; >;
float morph_c : CONTROLOBJECT < string name = CONTROLLER; string item = "コントラスト"; >;
float morph_v : CONTROLOBJECT < string name = CONTROLLER; string item = "明度"; >;
float morph_s : CONTROLOBJECT < string name = CONTROLLER; string item = "彩度"; >;
float morph_scale : CONTROLOBJECT < string name = CONTROLLER; string item = "グラデ大"; >;
float morph_yogosi : CONTROLOBJECT < string name = CONTROLLER; string item = "汚し"; >;




float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;



// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;


float3 Center : CONTROLOBJECT < string name = CONTROLLER; string item = "センター"; >;
float X : CONTROLOBJECT < string name ="(self)"; string item = "X"; >;
float Y : CONTROLOBJECT < string name ="(self)"; string item = "Y"; >;
float Si : CONTROLOBJECT < string name ="(self)"; string item = "Si"; >;
float Tr : CONTROLOBJECT < string name ="(self)"; string item = "Tr"; >;


// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "D3DFMT_A16B16G16R16F" ;
	bool AntiAlias = true;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//ワーク領域
texture2D ScnWork : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "D3DFMT_A16B16G16R16F" ;
	bool AntiAlias = true;
>;
sampler2D WorkSamp = sampler_state {
    texture = <ScnWork>;
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


#include "Movie_Function.fxsub"
#include "Gaussian.fxsub"

struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_passMain( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}
float setmorph(float now,float m)
{
	return m > 0 ? m : now;
}
float4 PS_passMain1(float2 Tex: TEXCOORD0) : COLOR
{   
	if(bCont)
	{
		Saturation = setmorph(Saturation,morph_s);
		Bright = setmorph(Bright,morph_v);
		if(morph_r > 0 || morph_g > 0 || morph_b > 0)
			LightColor = float3(morph_r*255,morph_g*255,morph_b*255);
		MaskAlpha = setmorph(MaskAlpha,morph_yogosi);
		Contrast = setmorph(Contrast,morph_c);
	}

	float4 Col = tex2D(ScnSamp,Tex);
	
	//明るさ落とし
	Col.rgb *= Bright*Si*0.1;
	//彩度落とし
	Col.rgb = lerp(Col.rgb,(Col.r*0.299+Col.g*0.587+Col.b*0.114),1-Saturation);

	//コントラスト調整
	Col.rgb = lerp(Col.rgb,ToneCurve0(Col.rgb),Contrast);
	
	//ソフトライトで色乗せ
	Col.r = SoftLight(Col.r,LightColor.r/255.0f);
	Col.g = SoftLight(Col.g,LightColor.g/255.0f);
	Col.b = SoftLight(Col.b,LightColor.b/255.0f);
	
	
	//トーンカーブでコントラスト上げてスクリーン合成
	float4 Col2 = Col;
	Col2.rgb = ToneCurve1(Col2.rgb);
	Col2.rgb = 1.0 - ((1.0 - Col.rgb) * (1.0 - Col2.rgb));
	
	return Col2;
	
}

float4 PS_passMain2(float2 Tex: TEXCOORD0) : COLOR
{   
	if(bCont)
	{
		Saturation = setmorph(Saturation,morph_s);
		Bright = setmorph(Bright,morph_s);
		if(morph_r > 0 || morph_g > 0 || morph_b > 0)
			LightColor = float3(morph_r*255,morph_g*255,morph_b*255);
		GradationScale = setmorph(GradationScale,morph_scale*5.0);
		if(morph_r > 0 || morph_g > 0 || morph_b > 0)
			GradColor = pow(LightColor/255.0,2)*255*0.37;

		MaskAlpha = setmorph(MaskAlpha,morph_yogosi);
	}
	
	float4 Col = saturate(tex2D(WorkSamp,Tex));
	
	//マスクで周辺減光
	float mask = tex2D(sampMask,Tex).r;
	
	Col.rgb = lerp(ToneCurve2(Col.rgb),Col.rgb,mask);
	//return Col;
	//汚し素材をオーバーレイ
	float4 Noize = tex2D(sampNoize,Tex);
	float4 Col2 = Col;
	Col.r = OverRay(Col.r,Noize.r);
	Col.g = OverRay(Col.g,Noize.g);
	Col.b = OverRay(Col.b,Noize.b);
	
	Col = lerp(Col2,Col,MaskAlpha);
	//最終グラデ乗せ
	if(bCont)
	{
		X += Center.x*0.25;
		Y += Center.y*0.25;
	}
	
	
	float2 GrdTgt = float2(X-1,Y-1);
	float Grad = (1-saturate(length((Tex*2-1)-GrdTgt)*0.4/GradationScale));
	GradColor = GradColor/255.0f;
	Col.r = Screen(Col.r,(GradColor.r)*Grad);
	Col.g = Screen(Col.g,(GradColor.g)*Grad);
	Col.b = Screen(Col.b,(GradColor.b)*Grad);
	
	Col = lerp(tex2D(ScnSamp,Tex),Col,Tr);
	
	return Col;
}


////////////////////////////////////////////////////////////////////////////////////////////////

technique Movie <
    string Script = 
        "RenderColorTarget0=ScnMap;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "ScriptExternal=Color;"
        "RenderColorTarget0=ScnWork;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=Main1;"
	    
        "RenderColorTarget0=ScnMap2;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_X;"
        "RenderColorTarget0=ScnWork;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=Gaussian_Y;"

	    
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=Main2;"
    ;
> {
    pass Main1 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_3_0 VS_passMain();
        PixelShader  = compile ps_3_0 PS_passMain1();
    }
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passY();
        PixelShader  = compile ps_2_0 PS_passY();
    }
    pass Main2 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_3_0 VS_passMain();
        PixelShader  = compile ps_3_0 PS_passMain2();
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////
