// パラメータ宣言

//ビームの透明度
#define BEAM_ALPHA 1
//ビームの濃さ
#define BEAM_POW 0.95
//ビームの長さ
#define BEAM_LENGTH 30
//ビームの太さ
#define BEAM_SIZE 6
//回転速度（芯）
#define BASE_ROT 3
//回転速度（周囲）
#define ADD_ROT -3
//大きさ（芯）
#define BASE_SCALE 0.9
//大きさ（周囲）
#define ADD_SCALE 1
//照射速度
#define BEAM_SPD 1.0
//ビームの色（ＲＧＢ）
static float3 BeamColor = float3(0.1,0.5,1);

//--ここから触らない--//

texture DepthRT: OFFSCREENRENDERTARGET <
    string Description = "BlackMaskRT for Beam.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
    string Format="R32F";
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "Beam.fx = hide;"
        "* = Depth.fx;" 
    ;
>;
sampler DepthSamp = sampler_state {
    texture = <DepthRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

texture BeamTex
<
   string ResourceName = "Tex.png";
>;
sampler BeamSamp = sampler_state
{
   Texture = (BeamTex);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
texture ZTex : RenderColorTarget
<
   string Format="R32F";
>;
sampler ZPrev = sampler_state
{
   Texture = (ZTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
texture BackZTex : RenderColorTarget
<
   string Format="R32F";
>;
sampler BackZPrev = sampler_state
{
   Texture = (BackZTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
texture DepthBuffer : RenderDepthStencilTarget <

    string Format = "D24S8";
>;



// 変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 ViewProjMatrix      : VIEWPROJECTION;
float4x4 WorldMatrix      : WORLD;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;


// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {

}


// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {

}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float4 W_Pos	  : TEXCOORD2;	 // 自分の座標
    float2 ScrUV	  : TEXCOORD3;	 // スクリーン座標
    float2 AddUV	  : TEXCOORD4;	 // 歪み用UV値
};

float time : Time;

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0,uniform bool DrawType)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	
	float4x4 matRot;
	float rady = time;
	if(DrawType)
	{
		rady *= BASE_ROT;
		Pos.xz *= BASE_SCALE;
	}else{
		rady *= ADD_ROT;
		Pos.xz *= ADD_SCALE;
	}
	
	Pos.xz *= 0.1+((1+tex2Dlod(BeamSamp, float4(Tex+float2(0,time*BEAM_SPD),0,1)).r)*0.5)*0.5;
	Pos.xz *= BEAM_SIZE*MaterialDiffuse.a*0.5;
	Pos.y *= BEAM_LENGTH;
	//Y軸回転 
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos = mul(Pos,matRot);
	
    // カメラ視点のワールドビュー射影変換
	Out.W_Pos = mul( Pos, WorldMatrix );
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    float4 WVP_Pos = Out.Pos;
    float4 WVP_Vec = mul(float4( 0,0,0,1 ),WorldViewProjMatrix);
    
    //スクリーン座標を計算
 	float3 TgtPos = WVP_Pos.xyz/WVP_Pos.w;
	TgtPos.y *= -1;
	TgtPos.xy += 1;
	TgtPos.xy *= 0.5;
    Out.ScrUV = TgtPos.xy;
    
    //スクリーン座標内ベクトルを計算
   	TgtPos = WVP_Vec.xyz/WVP_Vec.w;
	TgtPos.y *= -1;
	TgtPos.xy += 1;
	TgtPos.xy *= 0.5;
    Out.AddUV = normalize(TgtPos.xy);
    
    // テクスチャ座標
    Out.Tex = Tex+float2(0,time*BEAM_SPD);
    

    return Out;
}

// ピクセルシェーダ
float4 BasePS(VS_OUTPUT IN) : COLOR0
{   
    return float4(0,0,0,1);
}
float4 Base_ZPS(VS_OUTPUT IN) : COLOR0
{   
	//Z深度を計算
	float len = length(IN.W_Pos - CameraPosition);
    return float4(len,0,0,1);
}
float4 AddPS(VS_OUTPUT IN) : COLOR0
{   
	float len = length(IN.W_Pos - CameraPosition);
    //return tex2D(BeamSamp,IN.Tex);

	
	float4 ZSabun = 1-pow(saturate((tex2D(ZPrev,IN.ScrUV.xy).r - len)*(1-BEAM_POW)),1);

	float4 col = float4(BeamColor,1);
	col.rgb += ZSabun.r;
		
	float2 AddUV = normalize(IN.AddUV - IN.ScrUV);
	IN.ScrUV.xy += AddUV*(pow(ZSabun.r,8));
	
	float TgtDepth = tex2D(DepthSamp,IN.ScrUV.xy).r;

	if(TgtDepth < tex2D(BackZPrev,IN.ScrUV.xy).r)
	{
		col.rgb = lerp(col.rgb,0,1-ZSabun.r);
	}
	
	
    return saturate(col);
}
// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

technique MainTec < string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=ZTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=DrawObject_baseZ;"
	    
        "RenderColorTarget0=BackZTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=DrawObject_backZ;"
	    
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    
	    //"Pass=DrawObject_base;"
	    "Pass=DrawObject_add;"
    ;
> {
    pass DrawObject_base {
		ZENABLE = TRUE;
		ZWRITEENABLE = FALSE;
		CULLMODE = CW;
		ALPHABLENDENABLE = TRUE;
		SRCBLEND = SRCALPHA;
		DESTBLEND = INVSRCALPHA;
        VertexShader = compile vs_3_0 Basic_VS(true);
        PixelShader  = compile ps_3_0 BasePS();
    }
    pass DrawObject_baseZ {
		ZENABLE = TRUE;
		ZWRITEENABLE = TRUE;
		CULLMODE = NONE;
		ALPHABLENDENABLE = TRUE;
		SRCBLEND = SRCALPHA;
		DESTBLEND = INVSRCALPHA;
        VertexShader = compile vs_3_0 Basic_VS(true);
        PixelShader  = compile ps_3_0 Base_ZPS();
    }
    pass DrawObject_backZ {
		ZENABLE = TRUE;
		ZWRITEENABLE = TRUE;
		CULLMODE = CW;
		ALPHABLENDENABLE = TRUE;
		SRCBLEND = SRCALPHA;
		DESTBLEND = INVSRCALPHA;
        VertexShader = compile vs_3_0 Basic_VS(true);
        PixelShader  = compile ps_3_0 Base_ZPS();
    }
    pass DrawObject_add {
		ZENABLE = TRUE;
		ZWRITEENABLE = FALSE;
		CULLMODE = NONE;
		ALPHABLENDENABLE = TRUE;
		SRCBLEND = SRCALPHA;
		DESTBLEND = ONE;
		
		ZENABLE = TRUE;
		ZWRITEENABLE = TRUE;
		CULLMODE = NONE;
		ALPHABLENDENABLE = TRUE;
		SRCBLEND = SRCALPHA;
		DESTBLEND = INVSRCALPHA;
		
        VertexShader = compile vs_3_0 Basic_VS(false);
        PixelShader  = compile ps_3_0 AddPS();
    }
}