//複製数
#define PARTICLE_COUNT 128

//重力
float3 Grv = float3(0,64,0);



//メイン色設定
float3 MainColor = float3(1,1,1);

int MainIceNum = 4;
int SmokeNum = 0;
int HitMarkNum = 0;

//爆発サイズ
float BomScale = 0.5;

//爆破発生半径
float SetScale = 0.25;

//再生スピード
float particleSpeed = 0.1;

//一定速度以上で爆破する
float CutSpeed = 0;


int g_index_loop;

#if FIX_FIRE_DIRECTION
#define TEX_HEIGHT  PARTICLE_COUNT
#else
#define TEX_HEIGHT  (PARTICLE_COUNT*2)
#endif

texture ParticleBaseTex : RenderColorTarget
<
   int Width=1;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture ParticleBaseTex2 : RenderColorTarget
<
   int Width=1;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture DepthBuffer : RenderDepthStencilTarget <
   int Width=1;
   int Height=TEX_HEIGHT;
    string Format = "D24S8";
>;
texture SavePosTex : RenderColorTarget
<
   int Width=1;
   int Height=1;
   string Format="A32B32G32R32F";
>;
sampler SavePosSamp = sampler_state
{
   Texture = (SavePosTex);
   FILTER = NONE;
};
sampler ParticleBase = sampler_state
{
   Texture = (ParticleBaseTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler ParticleBase2 = sampler_state
{
   Texture = (ParticleBaseTex2);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler ParticleBase2L = sampler_state
{
   Texture = (ParticleBaseTex2);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = LINEAR;
};


#define CONTROLLER "Impact_ColorController.pmx"

float morph_r : CONTROLOBJECT < string name = CONTROLLER; string item = "赤"; >;
float morph_g : CONTROLOBJECT < string name = CONTROLLER; string item = "緑"; >;
float morph_b : CONTROLOBJECT < string name = CONTROLLER; string item = "青"; >;
float morph_add_si : CONTROLOBJECT < string name = CONTROLLER; string item = "加算倍率"; >;
float morph_a : CONTROLOBJECT < string name = CONTROLLER; string item = "透明度"; >;
bool bController : CONTROLOBJECT < string name = CONTROLLER; >;
float morph_size : CONTROLOBJECT < string name = CONTROLLER; string item = "爆発サイズ"; >;
float morph_len : CONTROLOBJECT < string name = CONTROLLER; string item = "発生半径"; >;
float morph_spd : CONTROLOBJECT < string name = CONTROLLER; string item = "発生速度"; >;
float3 ContPos : CONTROLOBJECT < string name = CONTROLLER; string item = "位置調整用"; >;

int g_index;
//深度マップ保存テクスチャ
shared texture2D SPE_DepthTex : RENDERCOLORTARGET;
sampler2D SPE_DepthSamp = sampler_state {
    texture = <SPE_DepthTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//ソフトパーティクルエンジン使用フラグ
bool use_spe : CONTROLOBJECT < string name = "SoftParticleEngine.x"; >;

//乱数テクスチャ
texture2D rndtex <
    string ResourceName = "../Texture/random256x256.bmp";
>;

texture TexIce<
    string ResourceName = "../Texture/Ice.png";
>;
sampler SampIce = sampler_state {
    texture = <TexIce>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV  = WRAP;
};
texture TexSmoke<
    string ResourceName = "../Texture/Smoke.png";
>;
sampler SampSmoke = sampler_state {
    texture = <TexSmoke>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV  = WRAP;
};

texture TexIM<
    string ResourceName = "../Texture/Impactmark.png";
>;
sampler SampIM = sampler_state {
    texture = <TexIM>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV  = WRAP;
};
float Tr : CONTROLOBJECT < string name = "(self)";string item = "Tr";>;
float Si : CONTROLOBJECT < string name = "(self)";string item = "Si";>;



sampler rnd = sampler_state {
    texture = <rndtex>;
    MINFILTER = NONE;
    MAGFILTER = NONE;
};

//乱数テクスチャサイズ
#define RNDTEX_WIDTH  256
#define RNDTEX_HEIGHT 256

//乱数取得
float4 getRandom(float rindex)
{
	/*
    float2 tpos = float2(rindex % RNDTEX_WIDTH, trunc(rindex / RNDTEX_WIDTH));
    tpos += float2(0.5,0.5);
    tpos /= float2(RNDTEX_WIDTH, RNDTEX_HEIGHT);
    */
    float4 ret;
    rindex += g_index_loop;
    ret.x = rindex;
    ret.y = rindex*1.234+123.4;
    ret.z = rindex*2.345+234.5;
    ret.w = rindex*3.456+345.6;
    
    ret = ret%1.0;
    
    return ret;
    
    //return tex2Dlod(rnd, float4(tpos,0,1));
}

//ベース座標取得
float3 GetBasePos()
{
	float2 base_tex_coord = float2( 0.5, float(g_index_loop)/TEX_HEIGHT + 0.5/TEX_HEIGHT);
	//float2 base_tex_coord = float2( 0.5, float(g_index_loop)/TEX_HEIGHT + 0.5/TEX_HEIGHT - (0.5/TEX_HEIGHT));
	float3 Base = tex2Dlod(ParticleBase2L, float4(base_tex_coord,0,1)).xyz;
	
	return Base;
}



struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float t		  : TEXCOORD4;
    float2 AddTex	  : TEXCOORD5;
    float Alpha		  : TEXCOORD6;
	float3 WPos		: TEXCOORD7;
	float4 LastPos	: TEXCOORD8;
};


// 座法変換行列
float4x4 WorldViewProjMatrix    : WORLDVIEWPROJECTION;
float4x4 WorldMatrix            : WORLD;
float4x4 ViewMatrix				: VIEW;
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;
float4x4 ViewProjMatrix    		: VIEWPROJECTION;

float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
float4   EdgeColor         : EDGECOLOR;
float4x4 view_trans_matrix : ViewTranspose;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightSpecular + MaterialEmmisive*1);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};

float Time : TIME;

////////////////////////////////////////////////////////////////////////////////////////////////
// 座標の2D回転
float2 Rotation2D(float2 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.y * sin(rot);
    float y = pos.x * sin(rot) + pos.y * cos(rot);

    return float2(x,y);
}

float inv_pow(float x,float p)
{
	return 1-pow(1-x,p);
}
//保持座標追加
float3 GetBufPos(int idx)
{
	float4 base_pos = 0;
	float3 add = 0;
	add.z = abs(cos(idx*123.455)*100);
	float rad = abs(cos(idx*1.2345))*2*3.1415;
	float4x4 matRot;
	matRot[0] = float4(cos(rad),0,-sin(rad),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rad),0,cos(rad),0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);

    add.xyz = mul(add.xyz,(float3x3)WorldMatrix);
	add /= Si;
	if(!bController)
	{
		morph_len = 1;
	}
	base_pos.xyz += add*SetScale*morph_len*Si*0.1;
	base_pos.xyz += GetBasePos();
	
	return base_pos.xyz;
}
VS_OUTPUT HitMarkFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float t = frac(float(g_index_loop)/PARTICLE_COUNT + particleSpeed * Time * (1-morph_spd));
	t = smoothstep(0,0.9,t);
	Out.t = t;
	
    Out.Alpha = t > 0;
    
	Pos.xyz = Pos.xzy;
	Pos.y += 0.01;
	float3 rnd = getRandom(index+123.345);
	Pos.xz *= 2+cos(g_index_loop*1.234)*0.5;
    
	Pos.xyz *= Si*BomScale*(1+morph_size*5);
    
    
    Pos.xyz = mul(Pos.xyz,(float3x3)WorldMatrix);
    Pos.xyz /= Si;
    float3 gAddPos = GetBufPos(g_index_loop).xyz;
    
    
	Pos.xyz += gAddPos;
    
    float rady;
    float4x4 matRot;
    rady = Time;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	//Pos = mul(Pos,matRot);
    
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;

    
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    return Out;
}
float4 IceInit(float4 Pos,int i)
{
	float4 rnd = getRandom(i);
	float4 Out = Pos;
	
	int type = g_index % 4;
	
	Out.z += 7;
	Out.z -= 16*type;
	Out.xyz *= Out.z > 0;
	Out.xyz *= Out.z < 16;
	Out.xyz *= 0.1;
	Out.yz -= 0.75;
	Out.y -= 0.25;
	
	
	return Out;
}
float time : TIME;
VS_OUTPUT MainIceFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    Pos = IceInit(Pos,g_index);
    //Pos.xz *= 0.25;
    Pos.xyz *= 3;
    
    
    float rad;
    float4x4 matRot;
    
	float3 rnd = getRandom(g_index*12.345);
	float3 rnd2 = getRandom(g_index*34.567);
	
	float addt = g_index*0.001;
	float t = frac(float(g_index_loop)/PARTICLE_COUNT + particleSpeed * Time * (1-morph_spd));
	t = smoothstep(0,0.15,t);
    

    Pos.xyz *= 0.3;
    Pos.xz *= 1*(rnd2.x*0.5+0.5);
    
    if(Pos.y > 0) Pos.y *= 0.01;
    else		  Pos.y *= 0.35*(rnd2.z*0.8+0.2);
    
    rad = t*rnd.z*10;
    
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	Pos = mul(Pos,matRot);
	Out.Normal = mul(Normal,matRot);


    Pos.y += t*32*(rnd2.y+0.2);
    Pos.z += rnd2.x*10*inv_pow(t,2);
    

    
    rad = rnd.y * 2 * 3.1415;
	matRot[0] = float4(cos(rad),0,-sin(rad),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rad),0,cos(rad),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos = mul(Pos,matRot);
	Out.Normal = mul(Out.Normal,matRot);

    Pos.xyz = mul(Pos.xyz,(float3x3)WorldMatrix);
    Pos.xyz /= Si;	
    Out.Alpha = (t > 0.01);//inv_pow(t,8)*inv_pow(1-Tr,8);
    Out.t = t;
    
    Pos.xyz *= 0.5;
	Pos.xyz *= Si*BomScale*(1+morph_size*5);
    //Pos = mul(Pos,WorldMatrix);
    
    float3 gAddPos = GetBufPos(g_index_loop).xyz;
	Pos.xyz += gAddPos;
	
	
    //重力
    if(bController)
    {
    	Grv -= ContPos;
    }
    
    Pos.xyz -= (t*t)*Grv*Si;
    
	Out.Normal = mul(Out.Normal,(float3x3)WorldMatrix);
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Tex = Tex;
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    
    return Out;
}
VS_OUTPUT SmokeFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    float addt = index;
    addt /= SmokeNum;
    addt *= 0.01;
    
	float t = frac(float(g_index_loop)/PARTICLE_COUNT + particleSpeed * Time * (1-morph_spd));
	t = smoothstep(0+addt,0.9+addt,t);
	t = smoothstep(-0.02,0.15,t);
    
	Out.t = t;
	
    Out.Alpha = 1.0;
    Pos.z = 0;
    
	//通常回転
	//回転行列の作成
	float rad = Time;

	//ビルボード回転
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	float3 rnd = getRandom(index+12.345);
	Pos.xyz *= 5+5*rnd.z;

	//Y軸回転 
	float3 add=float3(1+cos(rnd.y)*0.25,0,0);
	float rady = rnd.y*2*3.1415*64;
	float4x4 matRot;
	rad = cos(rnd.x*100)*2*3.1415*0.025;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	add = mul(add,matRot);
	
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);
	
	
	add = add*20*rnd.z*1;
	
	Pos.xyz *= 2+4*(1-rnd.z);
	Out.Alpha *= abs(cos(rnd.z*123.4));
	Out.Alpha *= pow(1-rnd.z,6);
	Out.Alpha = saturate(Out.Alpha * 10)*0.05;
	
	Pos.xyz += lerp(0,add,(1-pow(1-t,16)+t*0.25));
    
    Pos.xyz *= 0.25;
    
	Pos.xyz *= Si*BomScale*(1+morph_size*5);
	
    Pos.xyz = mul(Pos.xyz,(float3x3)WorldMatrix);
    Pos.xyz /= Si;
    
    float3 gAddPos = GetBufPos(g_index_loop).xyz;
	Pos.xyz += gAddPos;
	
    
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.Alpha *= (1-pow(1-t,16))*0.15;

	int Index0 = index;
	
	Index0 %= 16;
	int tw = Index0%4;
	int th = Index0/4;

	Out.AddTex.x += tw*0.25;
	Out.AddTex.y += th*0.25;
	
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    return Out;
}
VS_OUTPUT SmokeFunc2(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    float addt = index;
    addt /= SmokeNum;
    addt *= 0.01;
    
	float t = frac(float(g_index_loop)/PARTICLE_COUNT + particleSpeed * Time * (1-morph_spd));
	t += addt;
	//t = smoothstep(0.0+addt,1+addt,t);
	t = smoothstep(-0.01,0.15,t);
	Out.t = t;
	
    Out.Alpha = 0.1 * smoothstep(0,0.2,t);
    Pos.z = 0;
    
	//通常回転
	//回転行列の作成
	float rad = Time;

	//ビルボード回転
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	float3 rnd = getRandom(index+12.345);
	float3 rnd2 = getRandom(index);
	Pos.xyz *= 5+5*rnd.z;

	//Y軸回転 
	float3 add=float3(1+cos(rnd.y)*0.25,0,0);
	float rady = rnd2.z*2*3.1415;
	float4x4 matRot;
	rad = cos(rnd2.y*100)*2*3.1415*0.025;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	add = mul(add,matRot);
	
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);
	
	
	add = lerp(0,add*4*rnd.x,inv_pow(t,4));
	
	Pos.xyz *= 2+4*(1-rnd.z);
	Out.Alpha *= abs(cos(rnd.z*123.4));
	Out.Alpha *= pow(1-rnd.z,6);
	Out.Alpha = saturate(Out.Alpha * 10);
	
	Pos.xyz += add;
    
    Pos.xyz *= 0.15;
    Pos.y += 0.25+inv_pow(t,16)*3*rnd.y+t*rnd2.x;
    
	Pos.xyz *= Si*BomScale*(1+morph_size*5);
	
    Pos.xyz = mul(Pos.xyz,(float3x3)WorldMatrix);
    Pos.xyz /= Si;
	
    float3 gAddPos = GetBufPos(g_index_loop).xyz;
	Pos.xyz += gAddPos;
		    
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.Alpha *= 1-pow(1-t,16);
    Out.Alpha *= 0.025;

	int Index0 = index;
	
	Index0 %= 16;
	int tw = Index0%4;
	int th = Index0/4;

	Out.AddTex.x += tw*0.25;
	Out.AddTex.y += th*0.25;
	
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    return Out;
}
// 頂点シェーダ
VS_OUTPUT Main_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0,uniform int mode)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    int index = Pos.z+0.1;
    Out.Alpha = 1.0;
   
    if(mode == 0)
	{
	    Out = HitMarkFunc(index,Pos,Normal,Tex);
	    
		if(HitMarkNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 1)
    {
    	Out = MainIceFunc(Pos,Normal,Tex);
    }
    if(mode == 3)
    {
	    Out = SmokeFunc(index,Pos,Normal,Tex);
	    
		if(SmokeNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 5)
    {
	    Out = SmokeFunc2(index,Pos,Normal,Tex);
	    
		if(SmokeNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
	return Out;
}
// ピクセルシェーダ
float4 Main_PS(VS_OUTPUT IN,uniform int mode) : COLOR0
{
	float t = frac(float(g_index_loop)/PARTICLE_COUNT + particleSpeed * Time * (1-morph_spd));
	float4 Col = 1;	
	
	if(bController)
	{
		MainColor.rgb = float3(morph_r,morph_g,morph_b)*(1+morph_add_si);
	}	
	
	
	if(mode == 0)
	{
		Col = tex2D(SampIM,IN.Tex);
		float heat = 1-Col.r;
		Col.a = 1-Col.r;
		Col.rgb *= MainColor*0.25;
		Col.rgb = lerp(Col.rgb,heat*float3(8,4,0),pow(1-t,128));	
	}
	if(mode == 1)
	{
		Col = tex2D(SampIce,IN.Tex);
		Col.rgb *= (saturate(dot(IN.Normal,normalize(-LightDirection))*0.7+0.3))*(LightAmbient+0.333);
		Col.rgb *= MainColor;
	}
	if(mode == 2)
	{
	}
	if(mode == 3)
	{
		Col = tex2D(SampSmoke,(IN.Tex*0.25)+IN.AddTex);
		Col.a *= (pow(1-t,2));
		Col.rgb *= 1;
		Col.rgb *= MainColor;
	}
	if(mode == 4)
	{
	}
	if(mode == 5)
	{
		Col = tex2D(SampSmoke,(IN.Tex*0.25)+IN.AddTex);
		Col.a *= (pow(1-t,2));
		Col.rgb *= 1;
		Col.rgb *= MainColor;
	}
	Col.a *= IN.Alpha;
	Col.a = saturate(Col.a);
	
	/*
	if(use_spe && mode > 1)
	{
		float2 ScTex = IN.LastPos.xyz/IN.LastPos.w;
		ScTex.y *= -1;
		ScTex.xy += 1;
		ScTex.xy *= 0.5;
		
	    // 深度
	    float dep = length(CameraPosition - IN.WPos);
	    float scrdep = tex2D(SPE_DepthSamp,ScTex).r;
	    
	    float adddep = 1-saturate(length(abs(frac(IN.Tex*4)-0.5)));
	    dep = length(dep-scrdep);
	    dep = smoothstep(0,10,dep);
	    //return float4(dep,0,0,1);
	    Col.a *= dep;
    }
    */
	Col.a *= 1-morph_a;
    return Col;
}

float4 Clear_VS() : POSITION
{
	return float4(0,0,0,0);
}

float4 Clear_PS() : COLOR0
{
    return 0;
}

struct VS_OUTPUT2 {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
};


VS_OUTPUT2 ParticleBase_Vertex_Shader_main(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex ;
   return Out;
}

float4 ParticleBase_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   int idx = round(texCoord.y*TEX_HEIGHT);
   if ( idx >= PARTICLE_COUNT ) idx -= PARTICLE_COUNT;
   
   float t = frac(float(idx)/PARTICLE_COUNT + particleSpeed * Time * (1-morph_spd));
   texCoord += float2(0.5, 0.5/TEX_HEIGHT);
   
   float4 old_color = tex2D(ParticleBase2, texCoord);
   if ( old_color.a <= t ) {
      old_color.a = t;
      return old_color;
   } else {
      if(length(WorldMatrix._41_42_43 - tex2D(SavePosSamp,0).xyz) < CutSpeed || Tr == 0)
      {
      	WorldMatrix._41_42_43 = 65535;
      }
#if !FIX_FIRE_DIRECTION
      if ( texCoord.y < 0.5 ) {
         return float4(WorldMatrix._41_42_43, t);
      } else {
         return float4(WorldMatrix._21_22_23, t);
      }
#else
      return float4(WorldMatrix._41_42_43, t);
#endif
   }
}

VS_OUTPUT2 ParticleBase2_Vertex_Shader_main(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex + float2(0.5, 0.5/TEX_HEIGHT);
   return Out;
}

float4 ParticleBase2_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   return tex2D(ParticleBase, texCoord);
}
VS_OUTPUT2 SavePosVS(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex;
   return Out;
}

float4 SavePosPS(float2 texCoord: TEXCOORD0) : COLOR {
   return float4(WorldMatrix._41_42_43,1);
}
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

int nParticleCount = PARTICLE_COUNT;


// オブジェクト描画用テクニック
technique MainTec0 < string MMDPass = "object"; string Subset = "2"; 
    string Script = 
        "RenderColorTarget0=ParticleBaseTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=ParticleBase;"
        "RenderColorTarget0=ParticleBaseTex2;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=ParticleBase2;"
    
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"

		"LoopByCount=nParticleCount;"
		"LoopGetIndex=g_index_loop;"
		    "Pass=Smoke;"
		    "Pass=Smoke2;"
		    "Pass=HitMark;"
		"LoopEnd=;"
		
        "RenderColorTarget0=SavePosTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=SavePos;"
    ;
> {
    pass HitMark {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Main_VS(0);
        PixelShader  = compile ps_3_0 Main_PS(0);
    }
    pass Smoke {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Main_VS(3);
        PixelShader  = compile ps_3_0 Main_PS(3);
    }
    pass Smoke2 {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Main_VS(5);
        PixelShader  = compile ps_3_0 Main_PS(5);
    }
	pass ParticleBase < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_1_1 ParticleBase_Vertex_Shader_main();
	    PixelShader = compile ps_2_0 ParticleBase_Pixel_Shader_main();
	}
	pass ParticleBase2 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_1_1 ParticleBase2_Vertex_Shader_main();
	    PixelShader = compile ps_2_0 ParticleBase2_Pixel_Shader_main();
	}
	pass SavePos < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE= FALSE;
	    VertexShader = compile vs_1_1 SavePosVS();
	    PixelShader = compile ps_2_0 SavePosPS();
	}
}
technique MainTec1 < string MMDPass = "object"; string Subset = "0,1";
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
		"LoopByCount=nParticleCount;"
		"LoopGetIndex=g_index_loop;"
		    
			"LoopByCount=MainIceNum;"
			"LoopGetIndex=g_index;"
				"Pass=MainPass;"
			"LoopEnd=;"	
		"LoopEnd=;"
    ;
> {
    pass MainPass {
    	SRCBLEND = SRCALPHA;
    	//DESTBLEND = ONE;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = TRUE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(1);
        PixelShader  = compile ps_3_0 Main_PS(1);
    }
}
technique MainTec2 < string MMDPass = "object"; string Subset = "3"; > {
    pass MainPass {
        VertexShader = compile vs_3_0 Clear_VS();
        PixelShader  = compile ps_3_0 Clear_PS();
    }
}
technique MainTecBS0  < string MMDPass = "object_ss";> {
    pass MainPass {
        VertexShader = compile vs_3_0 Main_VS(0);
        PixelShader  = compile ps_3_0 Main_PS(0);
    }
}

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}

