//ベース色
float3 LightColor = float3(1,1,1)*3;
//ベース影色
float3 ShadowColor = float3(1,1,1);

//ノイズテクスチャ拡大率
float NoizeParam = 2.0;

//ぼかし係数
float BlurParam = 0.2;

//おおきさ
#define SIZE 1

#define LOCAL_LOOP 16

//ループ数（精度。スペックの許す限り上げるといいとおもう）
//美しさを求めるなら1024とか？ＰＣ爆発するかもだけど。でも書き出し時は1024とか！！PC爆発するかもだけど！！
int LoopMax = 512/LOCAL_LOOP;



//こっからさわらない

//円周率
#define PI 3.14159263

float morph_r : CONTROLOBJECT < string name = "(self)"; string item = "赤"; >;
float morph_g : CONTROLOBJECT < string name = "(self)"; string item = "緑"; >;
float morph_b : CONTROLOBJECT < string name = "(self)"; string item = "青"; >;
float morph_scale_old : CONTROLOBJECT < string name = "(self)"; string item = "光量"; >;
float morph_scale_m : CONTROLOBJECT < string name = "(self)"; string item = "光量-"; >;
float morph_scale_p : CONTROLOBJECT < string name = "(self)"; string item = "光量+"; >;
float morph_shadow : CONTROLOBJECT < string name = "(self)"; string item = "影量"; >;
float morph_g_scale : CONTROLOBJECT < string name = "(self)"; string item = "範囲拡大"; >;
float morph_noize : CONTROLOBJECT < string name = "(self)"; string item = "ノイズ"; >;

static float size = SIZE*(1+morph_g_scale*128);

#define WIDTH       1024
#define HEIGHT      1024
#define ANTI_ALIAS  false

float4x4 WorldMatrix            : WORLD;
float4x4 ViewMatrix				: VIEW;

//自身の座標
float3 Position : CONTROLOBJECT < string name = "(self)"; string item = "センター"; >;
float4x4 MatCenter : CONTROLOBJECT < string name = "(self)"; string item = "センター"; >;
float3 CameraPosition    : POSITION  < string Object = "Camera"; >;

texture EnvMap: OFFSCREENRENDERTARGET <
    int Width = WIDTH;
    int Height = HEIGHT;
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1;
    //string Format="R32F";
    string Format = "D3DFMT_A16B16G16R16F" ;
    bool AntiAlias = false;
    int Miplevels=1;
    string DefaultEffect = 
        "self = hide;"
        "*=EnvMap.fx;";
>;

sampler sampEnvMap = sampler_state {
    texture = <EnvMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture EnvMapLast: RenderColorTarget <
    int Width = WIDTH;
    int Height = HEIGHT;
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1;
    //string Format="R32F";
    string Format = "D3DFMT_A16B16G16R16F" ;
    bool AntiAlias = false;
    int Miplevels=1;
>;

sampler sampEnvMapLast = sampler_state {
    texture = <EnvMapLast>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture EnvDepthBuffer : RenderDepthStencilTarget <
    int Width = WIDTH;
    int Height = HEIGHT;
    string Format = "D24S8";
>;

texture CalcTex : RenderColorTarget<
    float2 ViewPortRatio = {1,1};
    string Format="R32F";
    bool AntiAlias = ANTI_ALIAS;
>;
sampler CalcSamp = sampler_state {
    texture = <CalcTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture CalcTex2 : RenderColorTarget<
    float2 ViewPortRatio = {1,1};
    string Format="R32F";
>;
sampler CalcSamp2 = sampler_state {
    texture = <CalcTex2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture EdgeTex : RenderColorTarget<
    float2 ViewPortRatio = {1,1};
    string Format="R32F";
>;
sampler EdgeSamp = sampler_state {
    texture = <EdgeTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    bool AntiAlias = true;
    string Format = "D3DFMT_A16B16G16R16F" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    bool AntiAlias = true;
    string Format = "D3DFMT_A16B16G16R16F" ;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture DepthBuffer : RenderDepthStencilTarget <
    float2 ViewPortRatio = {1,1};
    string Format = "D24S8";
>;
float4 GetEnv(float3 Vec)
{
	float2 Tex = 0;
	Tex.x = 0.5*acos(Vec.z/length(Vec.xz))/PI;
	if(Vec.x<0) Tex.x = 1-Tex.x; 
	Tex.y = 0.5-asin(Vec.y)/PI;
	
	return tex2D(sampEnvMapLast, Tex);
}

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

//座標描画用RT
texture PosMap: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for PostPointLight.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    string Format = "D3DFMT_A32B32G32R32F" ;
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    
    string DefaultEffect = 
        "self = hide;"
        "* =ModelPos.fx;";
>;
sampler PPLPos_Samp = sampler_state
{
	Texture = (PosMap);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
//深度描画用RT
texture GM_DepthMap : OFFSCREENRENDERTARGET <
	string Description = "DepthMap";
	string Format = "D3DFMT_R16F";
	float2 ViewPortRatio = {1,1};
	float4 ClearColor = {1,0,1,0};
	float ClearDepth = 1.0;
	bool AntiAlias = true;
	int Miplevels = 1;
	string DefaultEffect =
		"self=hide;"
	    "*=DepthDraw.fxsub;";
>;
sampler DepthMapSampler = sampler_state {
	texture = <GM_DepthMap>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

//ノイズテクスチャ
texture NoizeTex<
    string ResourceName = "Noize.png";
>;
sampler NoizeSamp = sampler_state {
    texture = <NoizeTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};



// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

// オリジナルの描画結果を記録するためのレンダーターゲット

struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_Main( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}


#define Z_MAX   65535.0
#define Z_MIN   1.0

float LightPow = 1;


float2 HitSphere(float3 vp,float3 v, float3 p)
{
	float3 u = vp - p;
	float t = length(vp-p);
	float hit = 1;
	if(t > size)
	{
		float a = dot( v, v );
		float b = dot( v, u );
		float c = dot( u, u ) - size * size;

	    float isColli = b * b - a * c;
		t = ( -b - sqrt( b * b - a * c ) ) / a;
		
	    if ( isColli < 0.0f ) {
	        // 衝突しない
	        hit *= -1;
	    }
    }else{
    	t *= -1;
    }
	return float2(max(0,t),hit);
}

float4x4 vp            : VIEWPROJECTION;

int index;

float2 W2S(float3 w)
{
	float4 wp;
	wp.xyz = w;
	wp.w = 1;
	wp = mul(wp,vp);
	wp /= wp.w;
	wp.y *= -1;
	wp.xy += 1;
	wp.xy *= 0.5;
	
	wp.xy += ViewportOffset;
		
	return wp.xy;
}
float4x4 inverseDir(float4x4 mat){
    return float4x4(
        mat._11, mat._21, mat._31, 0,
        mat._12, mat._22, mat._32, 0,
        mat._13, mat._23, mat._33, 0,
        0,0,0,1
    );
}

float4x4 inverse(float4x4 mat){
    float4x4 mv={
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        -mat._41, -mat._42, -mat._43, 1
    };

    return mul(mv,inverseDir(mat));
}

float4 PS_Calc(float2 Tex: TEXCOORD0) : COLOR
{
	float col = 0;

	//視線ベクトル
    float3 WPos = tex2D(PPLPos_Samp,Tex);
	float3 EyeVec = normalize(WPos.xyz - CameraPosition.xyz);    
    
    
    float AddjustNoize = (tex2D(NoizeSamp,Tex).r / (LoopMax*LOCAL_LOOP))*128;
    //AddjustNoize = 0;
    
	[unroll] for(int i=0;i<LOCAL_LOOP;i++)
	{
	    //視点から視線ベクトルを伸ばして、球と判定。距離、当たり判定フラグ取得
		float2 h = HitSphere(CameraPosition,EyeVec,Position);
	    
	    //当たってなければ処理スキップ
	    if(h.y < 0) continue;
		//clip(h.y);
		
		//探査空間座標
		float3 TgtPos = CameraPosition + EyeVec*(h.x + AddjustNoize + (index*LOCAL_LOOP+i)*(size*2)/(LoopMax*LOCAL_LOOP));

		//中心点から探査空間座標までのベクトルと距離
		float3 VecTgt = (TgtPos - Position);	
		float LenTgt = length(VecTgt);
		VecTgt = normalize(VecTgt);

		//中心点からオブジェクトまでの距離
		float LenCenter = GetEnv(VecTgt).r;
		
		//中心点からオブジェクトまでの距離の方が短ければ当たってない為処理スキップ
		if(LenCenter - LenTgt < 0) continue;
		//clip(LenCenter - LenTgt);

		//スクリーンワールド座標
		float3 ScrWPos = tex2D(PPLPos_Samp,W2S(TgtPos)).xyz;
		
		//探査点からスクリーンワールド座標へのベクトル
		float3 VecT2World = normalize(ScrWPos - TgtPos);
		
		//探査点からカメラへのベクトル
		float3 VecT2Cam = normalize(CameraPosition - TgtPos);

		//上2種のベクトルが反対方向を向いていたら印面消去でクリップ
		if(-dot(VecT2World,VecT2Cam) < 0) continue;
		//clip(-dot(VecT2World,VecT2Cam));
		
		//最終出力色
		float Light = 1.0;
		
		//中心からの距離で色を減らす
		Light *= pow(saturate(1-(LenTgt/(size))),4);
		//Light += pow(saturate(1-(LenTgt/(size))),2);
		col += Light;
	}
	return float4(col/(LoopMax*LOCAL_LOOP),0,0,1);
}


float4 PS_Main(float2 Tex: TEXCOORD0) : COLOR
{
	float4 c = tex2D(sampEnvMapLast,Tex);
	c.rgb *= 0.001;
	//return c;
	//return tex2D(EdgeSamp,Tex);

	float4 Base = tex2D(ScnSamp,Tex);
	
    float3 Color;
	Color = tex2D(CalcSamp,Tex).r;
	//return float4(Color,1);
	float3 mcol = float3(1-morph_r,1-morph_g,1-morph_b)*(1-morph_scale_old)*(1-morph_scale_m)*(1+morph_scale_p*8);
	Color.rgb = max(0,Color.r)*LightColor*mcol;
	
	Base.rgb += Color.rgb;
	
	Color.rgb = (saturate(max(0,Color.r))+ShadowColor*float3(1-morph_r*morph_shadow,1-morph_g*morph_shadow,1-morph_b*morph_shadow)*(1-morph_shadow));

	Base.rgb *= Color.rgb;
	Base.a = 1;
	
    return Base;
}
static const float2 PIXEL_SIZE = (float2(1,1)/(ViewportSize));

float4 PS_Edge(float2 Tex: TEXCOORD0) : COLOR
{
	float e0 = tex2D(DepthMapSampler,Tex);
	float e1=tex2D(DepthMapSampler,Tex + float2(-1, 0)*PIXEL_SIZE);
	float e2=tex2D(DepthMapSampler,Tex + float2( 1, 0)*PIXEL_SIZE);
	float e3=tex2D(DepthMapSampler,Tex + float2( 0,-1)*PIXEL_SIZE);
	float e4=tex2D(DepthMapSampler,Tex + float2( 0, 1)*PIXEL_SIZE);

	float sabun = saturate(((e0 - e1) + (e0 - e2) + (e0 - e3) + (e0 - e4))*32);

    return sabun;
}
//面の方向ベクトル
float3 vecA = normalize(float3( 0.0,           1.0, -pow(2.0,0.5)));
float3 vecB = normalize(float3(-pow(2.0,0.5), -1.0,  0.0         ));
float3 vecC = normalize(float3( 0.0,           1.0,  pow(2.0,0.5)));
float3 vecD = normalize(float3( pow(2.0,0.5), -1.0,  0.0         ));

//サンプリング座標を取得する関数
float2 SampPos4(float3 vec){
	float VA = dot(normalize(vec),vecA);
	float VB = dot(normalize(vec),vecB);
	float VC = dot(normalize(vec),vecC);
	float VD = dot(normalize(vec),vecD);
	
	float2 tex = float2(0,0);
	float3 vec2 = float3(0,0,0);
	if(VA>VB && VA>VC && VA>VD){
		//A面の読み取り
		//ベクトルの回転
		vec2 = mul(vec,float3x3(float3(1,0,0),
		                        float3(0,0.816496581,-0.577350269),
		                        float3(0,0.577350269,0.816496581)));
		tex = vec2.xy/(-vec2.z); //共通
		/*
			tex.xy = tex.xy/pow(2,1.5); //共通
			tex.x = tex.x*(2.0/pow(3,0.5)); //共通
			tex.y = tex.y*(4.0/3.0) + 1.0/3.0; //または -1.0/3.0
			tex.x = tex.x+0.5*tex.y-0.5; //または +0.5
			tex.x = tex.x*0.5 - 0.5; //または +0.5
		これらの一連の処理をまとめたのが、次の行列演算 */
		tex = (float2)mul(float3(tex,1),float3x3(float3(0.204124145,0,0),
		                                         float3(0.11785113,0.471404521,0),
		                                         float3(-0.666666667,0.333333333,1)));
	}else if(VB>VC && VB>VD){
		//B面の読み取り
		vec2 = mul(vec,float3x3(float3(0,-0.577350269,0.816496581),
		                        float3(0,0.816496581,0.577350269),
		                        float3(-1,0,0)));
		tex = vec2.xy/(-vec2.z);
		tex = (float2)mul(float3(tex,1),float3x3(float3(0.204124145,0,0),
		                                         float3(0.11785113,0.471404521,0),
		                                         float3(0.666666667,-0.333333333,1)));
	}else if(VC>VD){
		//C面の読み取り
		vec2 = mul(vec,float3x3(float3(-1,0,0),
		                        float3(0,0.816496581,-0.577350269),
		                        float3(0,-0.577350269,-0.816496581)));
		tex = vec2.xy/(-vec2.z);
		tex = (float2)mul(float3(tex,1),float3x3(float3(0.204124145,0,0),
		                                         float3(0.11785113,0.471404521,0),
		                                         float3(0.333333333,0.333333333,1)));
	}else{
		//D面の読み取り
		vec2 = mul(vec,float3x3(float3(0,0.577350269,-0.816496581),
		                        float3(0,0.816496581,0.577350269),
		                        float3(1,0,0)));
		tex = vec2.xy/(-vec2.z);
		tex = (float2)mul(float3(tex,1),float3x3(float3(0.204124145,0,0),
		                                         float3(0.11785113,0.471404521,0),
		                                         float3(-0.333333333,-0.333333333,1)));
	}
	tex = tex*float2(0.5,0.5)+float2(0.5,0.5);
	return tex;
}
VS_OUTPUT VS_BasePass( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float2 TexSize )
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	
	Out.Pos = Pos;
	Out.Tex = Tex.xy + 0.5/TexSize;
	
	return Out;
}
float4 PS_UnfoldPass(float2 Tex: TEXCOORD0) : COLOR
{   
	float pi = 3.1415926;
	
	float A = Tex.x*pi*2;
	float B = (Tex.y-0.5)*pi;
	
	float3 vec = float3(sin(A)*cos(B),sin(B),-cos(A)*cos(B));
	
	float4 TexColor = tex2D(sampEnvMap, SampPos4(vec));
	
	float4 Color;
	Color.a = TexColor.a;
	Color.rgb = TexColor.rgb;
	
	//ノイズテクスチャを乗せる
	Tex.xy %= 0.5;
	float Noize = 0<(tex2D(NoizeSamp,Tex*NoizeParam).r-morph_noize);
	Color *= Noize;
	
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// ガウス処理


static float2 SampStep = (float2(BlurParam,BlurParam)/ViewportSize);

// ぼかし処理の重み係数：
//    ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//    (WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし


VS_OUTPUT VS_passX( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
	SampStep *=min(1, tex2D(EdgeSamp, Tex).r * tex2D(CalcSamp,Tex).r*32);
	Color  = WT_0 *   tex2D( ScnSamp2, Tex );
	Color += WT_1 * ( tex2D( ScnSamp2, Tex+float2(SampStep.x  ,0) ) + tex2D( ScnSamp2, Tex-float2(SampStep.x  ,0) ) );
	Color += WT_2 * ( tex2D( ScnSamp2, Tex+float2(SampStep.x*2,0) ) + tex2D( ScnSamp2, Tex-float2(SampStep.x*2,0) ) );
	Color += WT_3 * ( tex2D( ScnSamp2, Tex+float2(SampStep.x*3,0) ) + tex2D( ScnSamp2, Tex-float2(SampStep.x*3,0) ) );
	Color += WT_4 * ( tex2D( ScnSamp2, Tex+float2(SampStep.x*4,0) ) + tex2D( ScnSamp2, Tex-float2(SampStep.x*4,0) ) );
	Color += WT_5 * ( tex2D( ScnSamp2, Tex+float2(SampStep.x*5,0) ) + tex2D( ScnSamp2, Tex-float2(SampStep.x*5,0) ) );
	Color += WT_6 * ( tex2D( ScnSamp2, Tex+float2(SampStep.x*6,0) ) + tex2D( ScnSamp2, Tex-float2(SampStep.x*6,0) ) );
	Color += WT_7 * ( tex2D( ScnSamp2, Tex+float2(SampStep.x*7,0) ) + tex2D( ScnSamp2, Tex-float2(SampStep.x*7,0) ) );
	
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

VS_OUTPUT VS_passY( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
	SampStep *= min(1, tex2D(EdgeSamp, Tex).r * tex2D(CalcSamp,Tex).r*32);
	Color  = WT_0 *   tex2D( ScnSamp, Tex );
	Color += WT_1 * ( tex2D( ScnSamp, Tex+float2(0,SampStep.y  ) ) + tex2D( ScnSamp, Tex-float2(0,SampStep.y  ) ) );
	Color += WT_2 * ( tex2D( ScnSamp, Tex+float2(0,SampStep.y*2) ) + tex2D( ScnSamp, Tex-float2(0,SampStep.y*2) ) );
	Color += WT_3 * ( tex2D( ScnSamp, Tex+float2(0,SampStep.y*3) ) + tex2D( ScnSamp, Tex-float2(0,SampStep.y*3) ) );
	Color += WT_4 * ( tex2D( ScnSamp, Tex+float2(0,SampStep.y*4) ) + tex2D( ScnSamp, Tex-float2(0,SampStep.y*4) ) );
	Color += WT_5 * ( tex2D( ScnSamp, Tex+float2(0,SampStep.y*5) ) + tex2D( ScnSamp, Tex-float2(0,SampStep.y*5) ) );
	Color += WT_6 * ( tex2D( ScnSamp, Tex+float2(0,SampStep.y*6) ) + tex2D( ScnSamp, Tex-float2(0,SampStep.y*6) ) );
	Color += WT_7 * ( tex2D( ScnSamp, Tex+float2(0,SampStep.y*7) ) + tex2D( ScnSamp, Tex-float2(0,SampStep.y*7) ) );
	
	
	//return float4(tex2D(CalcSamp,Tex).r,0,0,1);
	
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

////////////////////////////////////////////////////////////////////////////////////////////////

technique PostPointLight <
    string Script = 

		"ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
		
        "RenderColorTarget0=EnvMapLast;"
	    "RenderDepthStencilTarget=EnvDepthBuffer;"
		"Clear=Color;""Clear=Depth;"
		"Pass=UnfoldPass;"
	    

        "RenderColorTarget0=ScnMap;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;""Clear=Depth;"
		
	    "ScriptExternal=Color;"
	    

        "RenderColorTarget0=CalcTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"Clear=Color;""Clear=Depth;"
		
		"LoopByCount=LoopMax;"
		"LoopGetIndex=index;"
		
			"Pass=Calc;"
	
		"LoopEnd=;"
		
        "RenderColorTarget0=ScnMap2;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=Main;"
	    
		//境界描画
        "RenderColorTarget0=EdgeTex;"
		"Clear=Color;""Clear=Depth;"
	    "Pass=EdgePass;"
		
		
	    //ぼかし
        "RenderColorTarget0=ScnMap;"
		"Clear=Color;""Clear=Depth;"
	    "Pass=Gaussian_X;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=Gaussian_Y;"
	    
    ;
> {

    pass Calc < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = TRUE;
		SRCBLEND = ONE;
		DESTBLEND = ONE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_Calc();
    }
    pass Main < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = TRUE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_Main();
    }
	pass UnfoldPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_BasePass(float2(WIDTH,HEIGHT));
		PixelShader  = compile ps_3_0 PS_UnfoldPass();
	}
    pass EdgePass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_Main();
        PixelShader  = compile ps_3_0 PS_Edge();
    }
    
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passX();
        PixelShader  = compile ps_3_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passY();
        PixelShader  = compile ps_3_0 PS_passY();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
