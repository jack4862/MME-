// アルファ透過時の背景色（各値はRGBA。最後は0にする）
float4 ClearColor = { 0, 0, 0, 0 };





















// ポストエフェクト宣言
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// 共有マスク
shared texture2D CommonClippingMask : RENDERCOLORTARGET <>;
sampler CCMaskSamp = sampler_state {
	texture = <CommonClippingMask>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

float Tr : CONTROLOBJECT <string name="(self)"; string item="Tr";>;
float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = float2(0.5,0.5)/ViewportSize;

////////////////////////////////////////////////////////////////
// オリジナル画像
// 処理用テクスチャ
texture OrgScreen : RENDERCOLORTARGET <
	string Format = "A8R8G8B8";
	float2 ViewPortRatio = {1,1};
>;
sampler OrgSampler = sampler_state {
	texture = <OrgScreen>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV  = CLAMP;
};


/////////////////////////////
// コピー用のシェーダ
struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 Tex: TEXCOORD0;
};

VS_OUTPUT CopyVS(float4 Pos : POSITION, float2 Tex : TEXCOORD0 ){ 
	VS_OUTPUT Out;
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	return Out;
}

/////////////////////////////
// 合成用のシェーダ
float4 MixPS(float2 Tex: TEXCOORD0) : COLOR {
	float4 org = tex2D(OrgSampler, Tex);
    float4 MaskColor = tex2D(CCMaskSamp, Tex);
    org.a = MaskColor.r;
	return org;
}


////////////////////////////////////////////////////////////////
// エフェクトテクニック
//
float ClearDepth  = 1;

technique PostEffectTec <
	string Script =
		"RenderColorTarget=OrgScreen;"
		"RenderDepthStencilTarget=DepthBuffer;"
    		"ClearSetColor=ClearColor;"
    		"ClearSetDepth=ClearDepth;"
    		"Clear=Color;"
    		"Clear=Depth;"
	    	"ScriptExternal=Color;"

		"RenderColorTarget=;"
		"RenderDepthStencilTarget=;"
    		"ClearSetColor=ClearColor;"
    		"ClearSetDepth=ClearDepth;"
    		"Clear=Color;"
    		"Clear=Depth;"
    		"Pass=PassMix;"
	;
>{
	pass PassMix < string Script = "Draw=Buffer;"; >{
	    AlphaBlendEnable = false;
	    AlphaTestEnable = false;
		VertexShader = compile vs_2_0 CopyVS();
		PixelShader  = compile ps_2_0 MixPS();
	}
};
