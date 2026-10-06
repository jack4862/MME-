//メイン色設定
float3 MainColor = float3(1,1,1);

int ParticleNum = 1024;
int SmokeNum = 0;
int FireNum = 1024;
int FlashNum = 3;
int LightNum = 2;
int WaveNum = 32;

#define CONTROLLER "Gravity_ColorController.pmx"

float morph_r : CONTROLOBJECT < string name = CONTROLLER; string item = "赤"; >;
float morph_g : CONTROLOBJECT < string name = CONTROLLER; string item = "緑"; >;
float morph_b : CONTROLOBJECT < string name = CONTROLLER; string item = "青"; >;
float morph_add_si : CONTROLOBJECT < string name = CONTROLLER; string item = "加算倍率"; >;
float morph_a : CONTROLOBJECT < string name = CONTROLLER; string item = "透明度"; >;
bool bController : CONTROLOBJECT < string name = CONTROLLER; >;

bool bHitSphere : CONTROLOBJECT < string name = "HitSphere.x";>;
float4x4 HitPos : CONTROLOBJECT < string name = "HitSphere.x";>;
float HitScale : CONTROLOBJECT < string name = "HitSphere.x";>;

int index;
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
texture TexParticle<
    string ResourceName = "../Texture/Particle.png";
>;
sampler SampParticle = sampler_state {
    texture = <TexParticle>;
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

texture NoizeTex<
    string ResourceName = "../Texture/Noize.png";
>;
sampler SampNoize = sampler_state {
    texture = <NoizeTex>;
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

float inv_pow(float f,float p)
{
	return 1-(pow(1-f,p));
}

VS_OUTPUT ParticleFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{    
	VS_OUTPUT Out = (VS_OUTPUT)0;
    float addt = (float)index/(float)ParticleNum;
    addt *= 0.4;
	float t = smoothstep(0+addt,0.2+addt,1-Tr);
	Out.t = t;
	float gt = smoothstep(0,1,1-Tr);
	
    Out.Alpha = 1-gt;
    Pos.z = 0;
    
	//通常回転
	//回転行列の作成
	float rad = Time;

	float3 rnd = getRandom(index*12.345);
	float3 rnd2 = getRandom(index*34.567);
	//ビルボード回転
	
	float4x4 matRot;
	rad = rnd.y*2*3.1415+(gt*(rnd2.x*2.0-1.0));
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	Pos = mul(Pos,matRot);
	
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	Pos.xyz *= 0.25;
	
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
	float3 add2 = add;
	add = lerp(add,0,t);
	
	Pos.xyz += add*5;
	
	float t2 = inv_pow(smoothstep(0.55,1,1-Tr),8);
	Pos.xyz += add2*t2*6*(rnd2.x*0.5+0.5);
    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.Alpha *= inv_pow(t,8)*rnd2.z;
	
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
float time : TIME;
VS_OUTPUT FireFunc(int index,float4 Pos,float3 Normal,float2 Tex,float scale)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    float addt = (float)index/(float)FireNum;
    addt *= 0.25;
	float t = smoothstep(0+addt,0.5+addt,1-Tr);
	Out.t = t;
	float gt = smoothstep(0,0.95,1-Tr);
	
    Out.Alpha = 1.0;
    Pos.z = 0;
    
	//通常回転
	//回転行列の作成
	float rad = Time;

	float3 rnd = getRandom(index*12.345);
	float3 rnd2 = getRandom(index*34.567);
	//ビルボード回転
	
	float4x4 matRot;
	rad = rnd.y*2*3.1415+(gt*(rnd2.x*2.0-1.0));
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	Pos = mul(Pos,matRot);
	
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	Pos.xyz *= (2+2*rnd.z)*scale*0.25;

	//Y軸回転 
	float3 add=float3(rnd2.z*0.05,0,0);
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
		
	
    add.xyz = add.zxy;
	Pos.xyz += add*0.25;

	Pos.xyz *= 3;
	Pos.xyz *= 1+(gt)*2;
	Pos.xyz *= 1+smoothstep(0.0,0.1,gt)*5;
	
	Pos.xyz *= 1-smoothstep(0.45,0.55,gt);
	

    Pos.xyz *= 2;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.Alpha *= inv_pow(t,8);
	
	int Index0 = index;
	
	Index0 %= 16;
	Index0 = 0;
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
	float t = 0;
	if(index == 0)
		t = smoothstep(0.4,0.6,1-Tr);
	if(index == 1)
		t = smoothstep(0.55,0.6,1-Tr);
	if(index == 2)
		t = smoothstep(0.6,0.8,1-Tr);
		
	
	float scale = index+1;
	scale *= 10;
		
	Out.t = t;
	//index += ParticleNum;
	
	Pos.z = 0;
	Pos.xyz *= 5+(1-pow(1-t,16))*128;
    Pos.xyz *= 0.5*scale;
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	Pos.xyz *= 2;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
	Out.AddTex.x += 0.5;
	Out.AddTex.y += 0.5;
    
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    Out.Alpha = 1-pow(t,9);
    Out.Alpha *= (t != 0);
    return Out;
}
VS_OUTPUT LightFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float t = smoothstep(0.4+index*0.2,1,1-Tr);
	Out.t = t;
	//index += ParticleNum;
	
    Out.Alpha = 1;
    Pos.z = 0;
	Pos.xyz *= 4000*inv_pow(t,64);
	
    Pos.xyz *= 0.25;
	//ビルボード回転
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	Pos.xyz *= 2;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
	Out.AddTex.x += 0.5;
	Out.AddTex.y += 0.5;
    
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    return Out;
}
VS_OUTPUT SmokeFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float t = smoothstep(0,1,1-Tr);
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
	float3 add=float3(1,0,0);
	float rady = rnd.y*2*3.1415+(1-pow(1-t,8))*(0.2+cos(rnd.x*2*3.1415)*0.8);
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
	
	
	add = add*10+rnd.z*2;
	
	Pos.xyz *= 2+4*(1-rnd.z);
	Out.Alpha *= abs(cos(rnd.z*123.4));
	Out.Alpha *= pow(1-rnd.z,6);
	Out.Alpha = saturate(Out.Alpha * 10);
	
    add.xyz = add.zxy;
	Pos.xyz += lerp(0,add,(1-pow(1-t,24)));
    
    Pos.xyz *= 0.25;
	Pos.xyz *= 2;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.Alpha *= t;

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

    float addt = index;
    addt /= WaveNum;
    addt *= 0.1;

	float3 rnd = getRandom(index*12.345);
	
	float3 rnd2 = getRandom(index*32.345);
	
	float t = smoothstep(0.5+addt,1,1-Tr);
	float gt = 1-Tr;
	float3 PosBuf = Pos;
	
	float in_t = inv_pow(t,16);
	t = inv_pow(t,32);
	float OutSize = t*5+smoothstep(0.6,0.65,gt)*10+rnd2.x*10;//((PosBuf.x*0.5+0.5)*0.5);
	OutSize += gt*2;
	float InSize = lerp(0,OutSize,1);
	
	if(PosBuf.x > 0)
	{
		Pos.x = cos(PosBuf.z*2*3.1415)*(OutSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(OutSize);
		Pos.y = 4*inv_pow(1-gt,4);
	}else{
		Pos.x = cos(PosBuf.z*2*3.1415)*(InSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(InSize);
		Pos.y = -4*inv_pow(1-gt,4);
	}
	//Y軸回転 
	float4x4 matRot;
	float rady = rnd.y*2*3.1415*180.0+t*1+gt*5;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos.xyz = mul(Pos.xyz,matRot);

	float rad = rnd.x*2*3.1415*1;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	Pos.xyz = mul(Pos.xyz,matRot);
	
	rady = rnd.z*2*3.1415*180.0*1;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	Pos.xyz = mul(Pos.xyz,matRot);
	
	Pos.xyz = mul(Pos.xyz,matRot);
	
    Pos.xyz *= 0.25;
	Pos.xyz *= 1.15;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
	int Index0 = index;
	
	Index0 %= 8;
	int tw = Index0%2;
	int th = Index0/2;

	Out.AddTex.x += tw*0.5;
	Out.AddTex.y += th*0.5;
    
	Out.Alpha = t > 0;
	Out.Alpha *= inv_pow(1-gt,64);
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    return Out;
}
VS_OUTPUT BomFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
	Normal.xyz = normalize(Pos.xyz);
	float t = smoothstep(0.5,1,1-Tr);
	
    VS_OUTPUT Out = (VS_OUTPUT)0;
    Out.Alpha = 1.0;
	float3 TexPos = normalize(Pos.xyz);
	Out.Tex.y = TexPos.z / 2 + 0.5;
	
	float par = 2;
    Out.Tex=Tex;
	
	Pos.xyz *= inv_pow(t,32)*3+t*2+smoothstep(0.1,0.2,t)*20;
	

	Pos.xyz *= 0.25;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize(Normal);//normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Alpha = inv_pow(1-t,32);

    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    Out.t = t;
    return Out;
}
VS_OUTPUT NoizeFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
	Normal.xyz = normalize(Pos.xyz);
	float t = smoothstep(0.5,1,1-Tr);
	
    VS_OUTPUT Out = (VS_OUTPUT)0;
    Out.Alpha = 1.0;
	float3 TexPos = normalize(Pos.xyz);
	Out.Tex.y = TexPos.z / 2 + 0.5;
	
	float par = 2;
    Out.Tex=Tex;
	
	Pos.xyz *= inv_pow(t,32)*3+t*2+smoothstep(0.1,0.2,t)*20;
	Pos.xyz *= 0.25;

	Pos.xyz *= 1;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize(Normal);//normalize( mul( Normal, (float3x3)WorldMatrix ) );
	
	Out.Alpha = 1-t;
    Out.Alpha = lerp(Out.Alpha,0,saturate(Pos.y-4));

    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    Out.t = t;
    return Out;
}
// 頂点シェーダ
VS_OUTPUT Main_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0,uniform int mode,int vi: _INDEX)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    int index = Pos.z+0.1;
    Out.Alpha = 1.0;
   
    if(mode == 0)
	{
	    Out = ParticleFunc(index,Pos,Normal,Tex);
	   
		if(ParticleNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 1)
    {
	    Out = FireFunc(index,Pos,Normal,Tex,1);
	    
		if(FireNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 11)
    {
	    Out = FireFunc(index,Pos,Normal,Tex,1.1);
	    
		if(FireNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 2)
    {
	    Out = FlashFunc(index,Pos,Normal,Tex);
	    
		if(FlashNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 3)
    {
	    Out = SmokeFunc(index,Pos,Normal,Tex);
	    
		if(SmokeNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 4)
	{
	    Out = LightFunc(index,Pos,Normal,Tex);
	    
		if(LightNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 5)
	{
	    Out = WaveFunc(Pos,Normal,Tex);
    }
    if(mode == 20)
    {
	    Out = BomFunc(vi,Pos,Normal,Tex);
    }
    if(mode == 21)
    {
	    Out = NoizeFunc(vi,Pos*float4(1.005,1.005,1.005,1),Normal,Tex*float2(8,1));
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
     	Col = tex2D(SampSmoke,(IN.Tex*0.25)+IN.AddTex);

		Col.rgb = float3(0,0,0);
		Col.a = Col.a > 0.1;
		Col.rgb = lerp(0,MainColor*20,pow(t,8));
		
   		//Col.a *= pow(Tr,4);
	}
	if(mode == 1)
	{
		Col = tex2D(SampSmoke,(IN.Tex*0.25)+IN.AddTex);
		Col.a = pow(Col.a,16);
		Col.rgb = 1*MainColor;
		
	}
	if(mode == 11)
	{
		Col = tex2D(SampSmoke,(IN.Tex*0.25)+IN.AddTex);
		Col.a = pow(Col.a,16);
		Col.rgb = lerp(0,MainColor*20,t);
	}
	if(mode == 2)
	{
		Col = tex2D(SampParticle,(IN.Tex*0.5)+IN.AddTex);
		Col.a *= (pow(1-t,64));
		Col.rgb *= MainColor*8;
	}
	if(mode == 3)
	{
		Col = tex2D(SampSmoke,(IN.Tex*0.25)+IN.AddTex);
		Col.a *= (pow(1-t,4));
		Col.rgb *= 0.25;
		Col.rgb *= MainColor;
	}
	if(mode == 4)
	{
		Col = tex2D(SampParticle,(IN.Tex*0.5)+IN.AddTex);
		Col.a = saturate(pow(Col.a*1.25,16));	
		//Col.rgb *= MainColor*0.5;
		Col.rgb = Col.a > 0.5;
		Col.a = Col.a > 0.5;
	}
	if(mode == 5)
	{
		Col = tex2D(SampFire,(IN.Tex*0.5)+IN.AddTex);
		Col.a = Col.r;
		Col.rgb *= MainColor*10;
		
	}
	if(mode == 20)
	{
		Col.rgb = MainColor*2;
		float d = tex2D(SampNoize,IN.Tex+float2(1-pow(1-t,2)*0.1,0)).r;
		d += tex2D(SampNoize,IN.Tex+float2(0.5+1-pow(1-t,2)*-0.05,0)).r;
		
		Col.a -= pow(d,4)*pow(t,8)*16;
		
		//IN.Alpha = (IN.Alpha > 0.25);
	}
	if(mode == 21)
	{
		Col = tex2D(SampNoize,IN.Tex+float2(0,0.4*-t));
		Col.a = 1-Col.r;
		
		float d = abs(dot(float3(0,1,0),normalize(IN.Normal)));
		Col.a -= d*smoothstep(0.25,1,t);
		Col.a *= inv_pow(t,2);

		Col.a *= tex2D(SampNoize,IN.Tex*0.5).r;
		

		//IN.Alpha = saturate(pow(IN.Alpha*1,1));
	}
	
	Col.a *= IN.Alpha;
	Col.a = saturate(Col.a);
		
	if(use_spe && (mode != 4 && mode != 5 && mode != 2))
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
    Col.a = saturate(Col.a);
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
	    "Pass=Fire;"
	    "Pass=Paritcle;"
	    "Pass=Flash;"
	    "Pass=Light;"
    ;
> {
    pass Paritcle {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Main_VS(0);
        PixelShader  = compile ps_3_0 Main_PS(0);
    }
    pass Fire {
    	SRCBLEND = SRCALPHA;
    	//DESTBLEND = ONE;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(1);
        PixelShader  = compile ps_3_0 Main_PS(1);
    }
    pass FireBlack {
    	SRCBLEND = SRCALPHA;
    	//DESTBLEND = ONE;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(11);
        PixelShader  = compile ps_3_0 Main_PS(11);
    }
    pass Flash {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = FALSE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(2);
        PixelShader  = compile ps_3_0 Main_PS(2);
    }
    pass Smoke {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Main_VS(3);
        PixelShader  = compile ps_3_0 Main_PS(3);
    }
    pass Light {
    	SRCBLEND = INVDESTCOLOR;
    	DESTBLEND = ZERO;
    	
    	ZENABLE = FALSE;
    	ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Main_VS(4);
        PixelShader  = compile ps_3_0 Main_PS(4);
    }
}
technique MainTec1 < string MMDPass = "object"; string Subset = "1";
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
		"LoopByCount=WaveNum;"
		"LoopGetIndex=index;"
	    "Pass=MainPass;"
		"LoopEnd=;"
    ;
> {
    pass MainPass {
    	BLENDOP = REVSUBTRACT;
    
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(5);
        PixelShader  = compile ps_3_0 Main_PS(5);
    }
}
technique MainTec2 < string MMDPass = "object"; string Subset = "0";    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=Sphere;"
	    "Pass=SphereBlack;"
    ;
> {
    pass Sphere {
    	SRCBLEND = SRCALPHA;
    	//DESTBLEND = ONE;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = TRUE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(20);
        PixelShader  = compile ps_3_0 Main_PS(20);
    }
    pass SphereBlack {
    	SRCBLEND = SRCALPHA;
    	//DESTBLEND = ONE;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
    	//FILLMODE = WIREFRAME;
        VertexShader = compile vs_3_0 Main_VS(21);
        PixelShader  = compile ps_3_0 Main_PS(21);
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