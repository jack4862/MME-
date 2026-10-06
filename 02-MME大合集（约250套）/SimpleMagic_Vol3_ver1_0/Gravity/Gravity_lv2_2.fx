//メイン色設定
float3 MainColor = float3(1,0,1);

int ParticleNum = 512;
int SmokeNum = 512;
int LightNum = 1;
int WaveNum = 3;
int ThunderNum = 32;

#define CONTROLLER "Gravity_ColorController.pmx"

float morph_r : CONTROLOBJECT < string name = CONTROLLER; string item = "赤"; >;
float morph_g : CONTROLOBJECT < string name = CONTROLLER; string item = "緑"; >;
float morph_b : CONTROLOBJECT < string name = CONTROLLER; string item = "青"; >;
float morph_add_si : CONTROLOBJECT < string name = CONTROLLER; string item = "加算倍率"; >;
float morph_a : CONTROLOBJECT < string name = CONTROLLER; string item = "透明度"; >;

bool bHitSphere : CONTROLOBJECT < string name = "HitSphere.x";>;
float4x4 HitPos : CONTROLOBJECT < string name = "HitSphere.x";>;
float HitScale : CONTROLOBJECT < string name = "HitSphere.x";>;
bool bController : CONTROLOBJECT < string name = CONTROLLER; >;

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
texture TexThunder<
    string ResourceName = "../Texture/Thunder.png";
>;
sampler SampThunder = sampler_state {
    texture = <TexThunder>;
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
	float3 rnd2 = getRandom(index*12.4+123);
    float BaseTr = smoothstep(0,0.75,smoothstep(0,0.75,1-Tr));
	float t = smoothstep(0+rnd2*0.4,0.4+rnd2*0.4,BaseTr);

		
    VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.t = t;
    Pos.z = 0;
    
	//通常回転
	//回転行列の作成
	float rad = Time;
	float4x4 matRot;
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	//Pos.xyz = mul(Pos.xyz,matRot);

	//ビルボード回転
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	Pos.xyz *= 2+rnd2.x*5;

	float3 rnd = getRandom(index*123.456);
	
	float len = 3+rnd.x*128;
	float3 r_rnd = getRandom(index+123);
	float3 rbuf = r_rnd;

	//Y軸回転 
	float3 add=float3(1,0,0);;
	float rady = r_rnd.y*2*3.1415*1;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);
	
	rady = cos(r_rnd.z)*2*3.1415*1;
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);
	
	rad = r_rnd.x*2*3.1415;

	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);
	
	//add.y = inv_pow(abs(add.y),1);
	
    add.xyz = add.zxy;
    add.z *= -1;
	Out.Alpha = rnd2.z;

	Pos.xyz *= rnd2.y;
	add *= 0.1*rnd.x;
	Pos.xyz *= 0.05;
	float3 addbase = add*4*(rnd.z*0.5+0.5);
	add = lerp(addbase,0+addbase*0.5,pow(t,2));
	Pos.xyz += add;
	

    Pos.xyz *= 16;
    
    Out.Alpha *= 1-pow(1-t,8);
    
//    Out.Alpha *= pow(Tr,2);
	float Tr2 = 1-Tr;
	Tr2 = 1-pow(1-Tr2,2);
    Pos.xyz += addbase*16*rnd2.x*(1-pow(1-smoothstep(0.5+rnd.y*0.05,1,Tr2),2));
    Out.Alpha *= 1-smoothstep(0.0,rnd.y,1-Tr);
    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    Out.WPos = mul( Pos, WorldMatrix );
    
    
    return Out;
}


VS_OUTPUT LightFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    float BaseTr = smoothstep(0,0.75,smoothstep(0,0.75,1-Tr));
	float t = smoothstep(0.75,1,BaseTr);
	Out.t = t;
	//index += ParticleNum;
	
    Out.Alpha = 1-pow(t,9);
    Pos.z = 0;
	Pos.xyz *= 5+(1-pow(1-t,16))*16;
	
    Pos.xyz *= 1;
	//ビルボード回転
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
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
    
    float addt = ((float)index / (float)SmokeNum)*0.5;
    float BaseTr = smoothstep(0,0.75,smoothstep(0,0.75,1-Tr));
    
	float t = BaseTr;
	t = smoothstep(0+addt,0.5+addt,t);
	
    if(index < 32)
    {
    	t = smoothstep(0,0.5,smoothstep(0,0.5,Tr));
    }
	Out.t = t;
	
    Out.Alpha = 1.0;
    Pos.z = 0;
    
	//通常回転
	//回転行列の作成
	float rad;

	float3 rnd = getRandom(index+12.345);
	Pos.xyz *= 1+1*rnd.z;

	//Y軸回転 
	float3 add=float3(1,0,0);
	float rady = rnd.y*2*3.1415+(1-pow(1-t,8))*(0.2+cos(rnd.x*2*3.1415)*0.8);
	float4x4 matRot;
	rad = cos(rnd.x*100)*2*3.1415;
	
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	Pos = mul(Pos,matRot);
	add = mul(add,matRot);
	//ビルボード回転
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);
	
	
	
	Pos.xyz *= 2+4*(1-rnd.z);
	
    add.xyz = add.zxy*0.5;
    
    if(index < 32)
    {
    	add = 0;
    	Pos.xyz *= 0.25*saturate((1-Tr)*10);
    }else{
    	Out.Alpha *= 1-pow(1-smoothstep(0,0.5,BaseTr),8);
    }
    
	Pos.xyz += lerp(add,0,t);
	
	Pos.yz = lerp(Pos.yz * 0.2,Pos.yz,pow(saturate((1-BaseTr)*4),8));
	Pos.yz *= saturate((1-BaseTr)*4);
	Pos.x = lerp(Pos.x*3,Pos.x,pow(saturate((1-BaseTr)*4),8));
	Pos.x *= (1-saturate((1-BaseTr)*4))+1;
	
    
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
    
    Out.Alpha *= Tr;
    
    return Out;
}
VS_OUTPUT WaveFunc(float4 Pos,float3 Normal,float2 Tex)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    float addt = index;
    addt /= WaveNum;
    addt *= 0.5;
	float t = smoothstep(0.35,0.8,1-Tr);
	
	float3 PosBuf = Pos;
	
	float in_t = 1-pow(1-t,1);
	t = 1-pow(1-t,2);
	float OutSize = inv_pow(t,8)*10;//((PosBuf.x*0.5+0.5)*0.5);
	float InSize = lerp(OutSize*0.8,OutSize,in_t);
	
	if(PosBuf.x > 0)
	{
		Pos.x = cos(PosBuf.z*2*3.1415)*(OutSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(OutSize);
		Pos.y = 0.0;
	}else{
		Pos.x = cos(PosBuf.z*2*3.1415)*(InSize);
		Pos.z = sin(PosBuf.z*2*3.1415)*(InSize);
		Pos.y = 0;
	}
	
	float3 rnd = getRandom(index+12.345);
	//Y軸回転 
	float4x4 matRot;
	float rady = rnd.y*2*3.1415*180.0+t*1;
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
	
	
    Pos.xyz *= 0.5;
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
    
    Out.Alpha = 1;
	//Out.Alpha = 1-pow(t,16);
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    return Out;
}
VS_OUTPUT ThunderFunc(int index,float4 Pos,float3 Normal,float2 Tex,float addscale)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    float addt = ((float)(index) / (float)ThunderNum);
    float BaseTr = smoothstep(0.0+addt*0.7,0.2+addt*0.7,smoothstep(0,0.65,1-Tr));
    
	float t = BaseTr;
	
	Out.t = t;
	
    Out.Alpha = 1.0;
    Pos.z = 0;
    
	//通常回転
	//回転行列の作成

	float3 rnd = getRandom(index+12.345);

	//Y軸回転 
	float3 add=float3(1,0,0);
	
	float4x4 matRot;

	float radx = cos(rnd.x)*2*3.14159265;
	float rady = cos(rnd.y)*2*3.14159265;
	float radz = cos(rnd.z)*2*3.14159265;
	float radz2 = sin(rnd.z)*2*2*3.14159265;
	
	//Z軸回転
	matRot[0] = float4(cos(radz),sin(radz),0,0); 
	matRot[1] = float4(-sin(radz),cos(radz),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);

	//Y軸回転 
	matRot[0] = float4(cos(rady),0,-sin(rady),0); 
	matRot[1] = float4(0,1,0,0); 
	matRot[2] = float4(sin(rady),0,cos(rady),0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);


	//X軸回転
	matRot[0] = float4(1,0,0,0); 
	matRot[1] = float4(0,cos(radx),sin(radx),0); 
	matRot[2] = float4(0,-sin(radx),cos(radx),0); 
	matRot[3] = float4(0,0,0,1); 
	add = mul(add,matRot);

	//ビルボード回転
	matRot[0] = float4(cos(radz2),sin(radz2),0,0); 
	matRot[1] = float4(-sin(radz2),cos(radz2),0,0); 
	matRot[2] = float4(0,0,1,0); 
	matRot[3] = float4(0,0,0,1); 
	Pos = mul(Pos,matRot);
	
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
    Pos.xyz *= 5;
	Pos.xyz += add;

    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex*0.25;
	
	int id = t*7;
    
	if(t < 0.1)
	{
		id = 7;
	}
	
	Out.AddTex.x += (id%4)*0.25;
	Out.AddTex.y += ((id/4)%4)*0.25;
	
	
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
	    Out = ParticleFunc(index,Pos,Normal,Tex);
	    
		if(ParticleNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 1)
	{
	    Out = ThunderFunc(index,Pos,Normal,Tex,0);
	    
		if(ThunderNum-1 < index)
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
    if(mode == 6)
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
		Col = tex2D(SampParticle,(IN.Tex*0.5)+float2(0.5,0.0));

		Col.rgb *= MainColor*8;
	}
	if(mode == 1)
	{
		Col = tex2D(SampThunder,(IN.Tex)+IN.AddTex);
		Col.a = Col.r;
		Col.rgb = MainColor*2;
	}
	if(mode == 3)
	{
		Col = tex2D(SampSmoke,(IN.Tex*0.25)+IN.AddTex);
		Col.rgb = 0;
		Col.a = saturate(Col.a * 1.5);
	}
	if(mode == 6)
	{
		Col = tex2D(SampSmoke,(IN.Tex*0.25)+IN.AddTex);
		Col.rgb = MainColor*16;
		Col.a = pow(saturate(Col.a * 1.0),2);
	}
	if(mode == 4)
	{
		Col = tex2D(SampParticle,(IN.Tex*0.5)+IN.AddTex);
		Col.a *= (pow(1-t,4));
		Col.rgb *= MainColor*8;
	}
	if(mode == 5)
	{
		Col = tex2D(SampFire,(IN.Tex*0.5)+IN.AddTex);
		Col.a = Col.r;
		Col.rgb *= MainColor*8;
		
	}
	Col.a *= IN.Alpha;
	Col.a = saturate(Col.a);
	
	if(bHitSphere && (mode == 1 || mode == 0))
	{
		float3 vA = IN.WPos.xyz - WorldMatrix[3].xyz;
		float3 vB = HitPos[3].xyz - WorldMatrix[3].xyz;
		float3 vC = HitPos[3].xyz - IN.WPos.xyz;
		
		float t = dot( normalize( vA),vB) / length(vA);
		
		float3 h = vA * t - vB;
		
		
		if(t < 0)
		{
			h = vA;
		}
		if(t > 1)
		{
			h = vC;
		}
		
		if(length(h) < HitScale)
		{
			Col.a = 0;
		}
		
	}
	
	if(use_spe)
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
	    dep = smoothstep(0,1,dep);
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
technique MainTec0 < string MMDPass = "object"; string Subset = "0"; 
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=Smoke2;"
	    "Pass=Thunder;"
	    "Pass=Smoke;"
	    "Pass=Paritcle;"
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
        VertexShader = compile vs_3_0 Main_VS(6);
        PixelShader  = compile ps_3_0 Main_PS(6);
    }
    pass Thunder {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
        VertexShader = compile vs_3_0 Main_VS(1);
        PixelShader  = compile ps_3_0 Main_PS(1);
    }
    pass Light {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = TRUE;
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
    	SRCBLEND = SRCALPHA;
    	//DESTBLEND = ONE;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(5);
        PixelShader  = compile ps_3_0 Main_PS(5);
    }
}
technique MainTec2 < string MMDPass = "object"; string Subset = "2"; > {
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