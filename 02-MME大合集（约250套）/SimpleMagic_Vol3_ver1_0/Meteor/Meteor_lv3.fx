float Grv = 32.0;


//メイン色設定
float3 MainColor = float3(1,1,1);

int MainIceNum = 32;
int SubIceNum = 128;
int SmokeNum = 128;
int HitMarkNum = 1;
int WaveNum = 64;
int FlashNum = 1;
int LightNum = 1;
int ParticleNum = 128;

#define CONTROLLER "Meteor_ColorController.pmx"

float morph_r : CONTROLOBJECT < string name = CONTROLLER; string item = "赤"; >;
float morph_g : CONTROLOBJECT < string name = CONTROLLER; string item = "緑"; >;
float morph_b : CONTROLOBJECT < string name = CONTROLLER; string item = "青"; >;
float morph_add_si : CONTROLOBJECT < string name = CONTROLLER; string item = "加算倍率"; >;
float morph_a : CONTROLOBJECT < string name = CONTROLLER; string item = "透明度"; >;
bool bController : CONTROLOBJECT < string name = CONTROLLER; >;

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
texture TexFire<
    string ResourceName = "../Texture/Fire.png";
>;
sampler SampFire = sampler_state {
    texture = <TexFire>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = WRAP;
    AddressV  = WRAP;
};
texture TexPat<
    string ResourceName = "../Texture/Particle.png";
>;
sampler SampPat = sampler_state {
    texture = <TexPat>;
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
    float2 tpos = float2(rindex % RNDTEX_WIDTH, trunc(rindex / RNDTEX_WIDTH));
    tpos += float2(0.5,0.5);
    tpos /= float2(RNDTEX_WIDTH, RNDTEX_HEIGHT);
    return tex2Dlod(rnd, float4(tpos,0,1));
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


float4x4 RotX(float4x4 inMat,float rad)
{
	float4x4 ret = inMat;
	
	float4x4 matRot;
	matRot[0] = float4(1,0,0,0); 
	matRot[1] = float4(0,cos(rad),sin(rad),0); 
	matRot[2] = float4(0,-sin(rad),cos(rad),0);
	matRot[3] = float4(0,0,0,1);

	ret = mul(ret,matRot);
	
	return ret;
}
float4x4 RotY(float4x4 inMat,float rad)
{
	float4x4 ret = inMat;
	
	float4x4 matRot;
	matRot[0] = float4(cos(rad),0,-sin(rad),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rad),0,cos(rad),0); 
	matRot[3] = float4(0,0,0,1); 

	ret = mul(ret,matRot);
	return ret;
	
}
float4x4 RotZ(float4x4 inMat,float rad)
{
	float4x4 ret = inMat;
	
	float4x4 matRot;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);

	ret = mul(ret,matRot);
	return ret;
}

float3 RotX_vec(float3 pos,float rad)
{
	float4x4 mat;
	
	mat[0] = float4(1,0,0,0); 
	mat[1] = float4(0,1,0,0); 
	mat[2] = float4(0,0,1,0);
	mat[3] = float4(pos.x,pos.y,pos.z,1);
	
	return RotX(mat,rad)[3].xyz;
}
float3 RotY_vec(float3 pos,float rad)
{
	float4x4 mat;
	
	mat[0] = float4(1,0,0,0); 
	mat[1] = float4(0,1,0,0); 
	mat[2] = float4(0,0,1,0);
	mat[3] = float4(pos.x,pos.y,pos.z,1);
	
	return RotY(mat,rad)[3].xyz;
}
float3 RotZ_vec(float3 pos,float rad)
{
	float4x4 mat;
	
	mat[0] = float4(1,0,0,0); 
	mat[1] = float4(0,1,0,0); 
	mat[2] = float4(0,0,1,0);
	mat[3] = float4(pos.x,pos.y,pos.z,1);
	
	return RotZ(mat,rad)[3].xyz;
}
VS_OUTPUT HitMarkFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float t = smoothstep(0.5,1,1-Tr);
	Out.t = t;
	
    Out.Alpha = t > 0;
    
	Pos.xyz = Pos.xzy;
	Pos.y += 0.01;
	Pos.xz *= lerp(0,128,inv_pow(t,8));
    
    Pos.xyz *= Si;
    Pos.xyz += WorldMatrix[3].xyz;
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
    Pos.xyz *= 64;
    
    
    float rad;
    
	float3 rnd = getRandom(g_index+12.345);
	float3 rnd2 = getRandom(g_index);
	
	float addt = g_index*0.001;
	float t = 1-Tr;//smoothstep(0.0+addt,1+addt,1-Tr);

    
	Pos.xyz += rnd.xyz;
    Pos.xyz *= 0.1;
    
    float3 DefPos = float3(0,8,0);

	float4x4 matRot;
	rad = t;
	matRot[0] = float4(cos(rad),0,-sin(rad),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rad),0,cos(rad),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos = mul(Pos,matRot);

    
    Pos.xyz += lerp(DefPos,float3(0,1,0),t);
    
    if(t > 0.5)
    {
    	Pos.y += 0.3*saturate(pow((t-0.5)*2,16));
		Pos.xyz += (getRandom(t*123)*2-1)*0.05;
    }
    Out.AddTex.y = Pos.y;
    
    
    
    
    Pos = mul(Pos,WorldMatrix);
    Out.Alpha = 1;//inv_pow(t,8)*inv_pow(1-Tr,8);
    Out.t = t;
    
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    
    return Out;
}
VS_OUTPUT SubIceFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    Pos = IceInit(Pos,g_index);
    //Pos.xz *= 0.25;
    
    float rad;
    
	float3 rnd = getRandom(g_index+12.345);
	float3 rnd2 = getRandom(g_index);
	float3 rnd3 = getRandom(g_index+123.456);
	
	
    Pos.xyz *= (rnd.z*0.4+0.6)*2;
    Pos.y *= (rnd2.x*0.5+0.5);
    
    
    Pos.xyz = RotX_vec(Pos.xyz,rnd3.x*2*3.1415);
    Pos.xyz = RotY_vec(Pos.xyz,rnd3.y*2*3.1415);
    Pos.xyz = RotZ_vec(Pos.xyz,rnd3.z*2*3.1415);
    
    
    Pos.x += rnd.x*32;
    Pos.xyz = RotY_vec(Pos.xyz,rnd.y*2*3.1415);
	
	float addt = g_index*0.002;
	
	float t = inv_pow(smoothstep(0.52+addt,1+addt,1-Tr),8);
    
    Pos.y += inv_pow(t,8)*4;
    Pos.y += t*2;
    Pos.y -= lerp(1.5,0,t);
    Out.Alpha = t != 0;
    
    Pos = mul(Pos,WorldMatrix);
    Out.t = t;
    
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
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
    
	float t = smoothstep(0,0.9,saturate((1-Tr)-0.5)*2);
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
	rad = cos(rnd.x*100)*2*3.1415;
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
	Out.Alpha = saturate(Out.Alpha * 10);
	
	Pos.xyz += lerp(0,add,(1-pow(1-t,64)+t*0.25));
    
    Pos.xyz *= 1;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.Alpha *= (1-pow(1-t,16))*0.1;

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
VS_OUTPUT FlashFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
	float t = 1-Tr;
	Out.t = t;
	
    Out.Alpha = 1.0;
    Pos.z = 0;
	float ltr = smoothstep(0.45,0.5,t);
	float ltr2 = smoothstep(0.45,0.8,t);

	Pos.xyz *= 100;
	Pos.x *= 1+ltr*10;
	Pos.y *= 1-ltr2;
	Out.Alpha = ltr;
	
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	
	
	
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;

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
VS_OUTPUT LightFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
	float t = 1-Tr;
	Out.t = t;
	
    Out.Alpha = 1.0;
    Pos.z = 0;
	float ltr2 = smoothstep(0.45,0.8,t);

	Pos.xyz *= ltr2*8000;
	Out.Alpha = 1;
	
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	
	
	
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;

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
VS_OUTPUT ParticleFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{    
	VS_OUTPUT Out = (VS_OUTPUT)0;
    float addt = (float)index/(float)ParticleNum;
    addt *= 0.25;
	float t = smoothstep(0+addt,0.75+addt,1-Tr);
	Out.t = t;
	
    Out.Alpha = 1.0;
    Pos.z = 0;
    
	//通常回転
	//回転行列の作成
	float rad = Time;

	float3 rnd = getRandom(index*12.345);
	float3 rnd2 = getRandom(index*34.567);
	//ビルボード回転
	
	float4x4 matRot;
	rad = rnd.y*2*3.1415+((rnd2.x*2.0-1.0));
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	Pos = mul(Pos,matRot);
	
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	Pos.xyz *= (1+2*rnd.z);

	//Y軸回転 
	float3 add=float3(1,0,0);
	//float rady = rnd.y*2*3.1415+t*(0.2+cos(rnd.x*2*3.1415)*0.8);
	float rady = rnd.y*2*3.1415;
	rad = rnd.x*2*3.1415;
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
	
	
	
	Pos.xyz += add*6*rnd.z;
	Pos.y += 6;
	Pos.x -= 0.5;
	
	Pos.xyz = lerp(Pos.xyz,Pos.xyz+float3(0,4,0),t);
	
	//Pos.xyz += add*2;
	
    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.Alpha *= inv_pow(t,8);
    Out.Alpha *= inv_pow(1-t,8);
	
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

VS_OUTPUT WaveFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    float addt = g_index;
    addt /= WaveNum;
    float bufadt = addt;
    addt *= 0.5;
	float t = smoothstep(0+addt,1+addt,1-Tr);
	
	float3 PosBuf = Pos;
	float index_pow = ((float)g_index/(float)WaveNum);
	float in_t = 1-pow(1-t,16);
	t = 1-pow(1-t,32);
	float OutSize = 10+t*10*(index_pow);//((PosBuf.x*0.5+0.5)*0.5);
	float InSize = lerp(0,OutSize,in_t);
	
	float height = 0.5+index_pow*2;
	
	if(PosBuf.x > 0)
	{
		Pos.x = cos(PosBuf.z*2*3.1415)*(OutSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(OutSize);
		Pos.y = height;
	}else{
		Pos.x = cos(PosBuf.z*2*3.1415)*(InSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(InSize);
		Pos.y = -height;
	}
	
	float3 rnd = getRandom(g_index+12.345);
	//Y軸回転 
	float4x4 matRot;
	float rady = rnd.y*2*3.1415*180.0+t*8*(index_pow);
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos.xyz = mul(Pos.xyz,matRot);

	float rad = rnd.x*2*3.1415*0;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	Pos.xyz = mul(Pos.xyz,matRot);
	
	rady = rnd.z*2*3.1415*180.0*0;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos.xyz = mul(Pos.xyz,matRot);
	
	Pos.xyz = mul(Pos.xyz,matRot);
	
	
    Pos.xyz *= 1;
    
    
    float3 DefPos = float3(0,8,0);
    Pos.xyz += lerp(DefPos,0,bufadt+0.05);
	
	Pos.y += t*3*(1-index_pow);
    Pos.y -= 4*(1-index_pow);
    if(t > 0.5)
    {
    	Pos.y += 0.3*saturate(pow((t-0.5)*2,16));
    }
    
    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
	int Index0 = g_index;
	
	Index0 %= 8;
	int tw = Index0%2;
	int th = Index0/2;

	Out.AddTex.x += tw*0.5;
	Out.AddTex.y += th*0.5;
    
	Out.Alpha = 1-pow(t,16);
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
    if(mode == 16)
    {
    	Out = SubIceFunc(Pos,Normal,Tex);
    }
    if(mode == 3)
    {
	    Out = SmokeFunc(index,Pos,Normal,Tex);
	    
		if(SmokeNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 6)
	{
	    Out = WaveFunc(Pos,Normal,Tex);
    }
    if(mode == 10)
    {
	    Out = FlashFunc(index,Pos,Normal,Tex);	
		if(FlashNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 11)
    {
	    Out = ParticleFunc(index,Pos,Normal,Tex);	
		if(ParticleNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 12)
    {
	    Out =LightFunc(index,Pos,Normal,Tex);	
		if(LightNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
	return Out;
}
// ピクセルシェーダ
float4 Main_PS(VS_OUTPUT IN,uniform int mode) : COLOR0
{
	float t = IN.t;
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
		Col.rgb = lerp(Col.rgb,heat*float3(8,4,0),pow(1-t,8));
		
		//Col.a = 1;
	}
	if(mode == 1)
	{
		Col = tex2D(SampIce,IN.Tex);
		Col.rgb *= (saturate(dot(IN.Normal,normalize(-LightDirection))*0.7+0.3))*(LightAmbient+0.333);
		Col.rgb *= MainColor;
		float add = max(0,1-IN.AddTex.y*0.5);
		Col.rgb += lerp(0,float3(1,0.25,0)*1,smoothstep(0.25,1,1-Tr)+add);
	}
	if(mode == 16)
	{
		Col = tex2D(SampIce,IN.Tex);
		Col.rgb *= 0;
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
		Col.a = saturate(Col.a * 32);
	}
	if(mode == 10)
	{
		Col = tex2D(SampPat,IN.Tex*0.5);
		Col.rgb *= float3(1,0.5,0)*32;
	}
	if(mode == 11)
	{
		Col = tex2D(SampPat,IN.Tex*0.5+float2(0.5,0));
		Col.rgb *= float3(1,0.5,0)*1;
	}
	
	if(mode == 12)
	{
		Col = tex2D(SampPat,IN.Tex*0.5+float2(0.0,0));
		Col.rgb *= float3(1,0.5,0.25);
	}
	if(mode == 6)
	{
		Col = tex2D(SampFire,(IN.Tex*0.5)+IN.AddTex);
		Col.a = Col.r;
		Col.rgb *= MainColor*1;
		Col.rgb += lerp(0,float3(2,0.5,0)*8,smoothstep(0.5,1,1-Tr));
	}
	Col.a *= IN.Alpha;
	Col.a = saturate(Col.a);
	
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

// オブジェクト描画用テクニック
technique MainTec0 < string MMDPass = "object"; string Subset = "2"; 
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=Smoke;"
	    "Pass=Smoke2;"
	    "Pass=HitMark;"
	    "Pass=Flash;"
	    "Pass=Particle;"
	    "Pass=Light;"
	    
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
    pass Flash {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = FALSE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(10);
        PixelShader  = compile ps_3_0 Main_PS(10);
    }
    pass Particle {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(11);
        PixelShader  = compile ps_3_0 Main_PS(11);
    }
    pass Light {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = FALSE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(12);
        PixelShader  = compile ps_3_0 Main_PS(12);
    }
}
technique MainTec1 < string MMDPass = "object"; string Subset = "0,1";
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    
	    
		"LoopByCount=MainIceNum;"
		"LoopGetIndex=g_index;"
	    "Pass=MainPass;"
		"LoopEnd=;"
		"LoopByCount=SubIceNum;"
		"LoopGetIndex=g_index;"
	    "Pass=SubPass;"
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
    pass SubPass {
    	SRCBLEND = SRCALPHA;
    	//DESTBLEND = ONE;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = TRUE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(16);
        PixelShader  = compile ps_3_0 Main_PS(16);
    }
}
technique MainTec2 < string MMDPass = "object"; string Subset = "3";
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
		"LoopByCount=WaveNum;"
		"LoopGetIndex=g_index;"
	    "Pass=MainPass;"
		"LoopEnd=;"
    ;
> {
    pass MainPass {
    	SRCBLEND = SRCALPHA;
    	//DESTBLEND = ONE;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(6);
        PixelShader  = compile ps_3_0 Main_PS(6);
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