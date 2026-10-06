//メイン色設定
float3 MainColor = float3(1,0,1);

int ParticleNum = 64;
int SmokeNum = 1;
int LightNum = 1;
int ThunderNum = 2;

int DuplicateNum = 256;

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
int loop_index;
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
    string ResourceName = "../Texture/Grv.png";
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
float inv_pow(float f,float p)
{
	return 1-(pow(1-f,p));
}

float3 AddPosIndex(int i)
{
	float3 rnd = getRandom(i+12.345);
	float3 rnd2 = getRandom(i+34.567);
	
	float3 addPos;
    addPos.z = i*0.1;
    addPos.y = rnd.y*5;
    addPos.x = 0;
    
	addPos.xyz = RotZ_vec(addPos.xyz,rnd.z*2*3.1415);
	addPos.xyz = RotY_vec(addPos.xyz,rnd2.y*2*3.1415);
	
	return addPos;
}
VS_OUTPUT ParticleFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
	float3 rnd2 = getRandom(index*12.4+123);
    float BaseTr = 1-Tr;
	float t = smoothstep(0+rnd2*0.5,0.3+rnd2*0.5,BaseTr);

		
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
	Pos.xyz *= 0.1;
	float3 addbase = add*4*(rnd.z*0.5+0.5);
	add = lerp(addbase,0,pow(t,2));
	Pos.xyz += add*10;
	
	

    Pos.xyz *= 16;
    
    Out.Alpha *= 1-pow(1-t,8);
    Out.Alpha *= 1-t;
   

    
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
    
    float BaseTr = 1-Tr;
	float t = smoothstep(0,0.2,BaseTr);
	Out.t = t;
	//index += ParticleNum;
	
    Out.Alpha = 1-pow(t,9);
    Out.Alpha *= 0.25;
    Pos.z = 0;
	Pos.xyz *= 5+(1-inv_pow(t,16))*16;
	
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
VS_OUTPUT SmokeFunc(int index,float4 Pos,float3 Normal,float2 Tex,float addscale)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
	float3 rnd = getRandom(loop_index+12.345);
	float3 rnd2 = getRandom(loop_index+34.567);
    
    
    Pos.z = 0;
    
    float4x4 matRot;

	
    float GlobalTr = 1-Tr;
    
	float3 radrnd = getRandom(loop_index%8);
    float rad = radrnd.x*2*3.1415;

	Pos.x *= 1+inv_pow(smoothstep(0.95-radrnd.y*0.05,1,GlobalTr),8);
	Pos.y *= 1-inv_pow(smoothstep(0.95-radrnd.y*0.05,1,GlobalTr),8);
	
	matRot[0] = float4(cos(rad),sin(rad),0,0); 
	matRot[1] = float4(-sin(rad),cos(rad),0,0); 
	matRot[2] = float4(0,0,1,0);
	matRot[3] = float4(0,0,0,1);
	Pos = mul(Pos,matRot);
	
    Pos.xyz = mul( Pos.xyz, BillboardMatrix )*10;
    Out.Alpha = 1;
    
    float addTr = 1.0/(float)DuplicateNum;
    float w = addTr*4;
    addTr *= loop_index*0.1+rnd.x*0.1;
    float BaseTr = smoothstep(0+addTr,w+addTr,1-Tr);
    
    
    Pos.xyz *= BaseTr*0.5*(1+(1.0-loop_index/(float)DuplicateNum))+(BaseTr != 0)*GlobalTr*0.5;
	Pos.xyz *= 1+addscale;
	Pos.xyz += AddPosIndex(loop_index)*inv_pow(1-smoothstep(0,0.8,GlobalTr),8);
    Pos.xyz *= 1+5*inv_pow(smoothstep(0.75,1,GlobalTr),32);


    
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
	
    Out.WPos = mul(Pos,WorldMatrix);
    Out.LastPos = Out.Pos;
    
    
    return Out;
}
VS_OUTPUT ThunderFunc(int index,float4 Pos,float3 Normal,float2 Tex,float addscale)
{
	float3 rnd = getRandom(index+loop_index+12.345);
	float3 rnd2 = getRandom(index+loop_index+34.567);
	
    VS_OUTPUT Out = (VS_OUTPUT)0;

    float BaseTr = ((1-Tr)*20);
    BaseTr = max(0,BaseTr-(loop_index/(float)DuplicateNum)*2);
    BaseTr = min(1,BaseTr);
	float t = BaseTr;
	
	Out.t = t;
	
    Out.Alpha = 1.0;
    Pos.z = 0;
    
	//通常回転
	//回転行列の作成

	//Y軸回転 
	float3 add=float3(inv_pow(BaseTr,1.25),0,0);
	
	float4x4 matRot;

	float radx = cos(rnd.x)*2*3.14159265;
	float rady = cos(rnd.y)*2*3.14159265;
	float radz = cos(rnd.z)*2*3.14159265;
	float radz2 = rnd.x*2*2*3.14159265;
	
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
	Pos.xyz *= 10;
	//Pos.xyz *= 1+(smoothstep(0.5,1,BaseTr))*25;
	add *= 1-smoothstep(0.5,1,BaseTr);
	Pos.xyz += add;
	Pos.xyz += AddPosIndex(loop_index);

    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex*0.25;
	
	int id = t*7;
    
	if(t == 0)
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
	    Out = SmokeFunc(index,Pos,Normal,Tex,0);
	    
		if(SmokeNum-1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 6)
    {
	    Out = SmokeFunc(index,Pos,Normal,Tex,0.025);
	    
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

		Col.rgb *= MainColor*2;
	}
	if(mode == 1)
	{
		Col = tex2D(SampThunder,(IN.Tex)+IN.AddTex);
		Col.a = Col.r;
		Col.rgb = MainColor*2;
	}
	if(mode == 3)
	{
		Col = tex2D(SampSmoke,(IN.Tex)+IN.AddTex);
		Col.rgb = 0;
	}
	if(mode == 6)
	{
		Col = tex2D(SampSmoke,(IN.Tex)+IN.AddTex);
		Col.rgb = MainColor*4;
	}
	if(mode == 4)
	{
		Col = tex2D(SampParticle,(IN.Tex*0.5)+IN.AddTex);
		Col.a *= (pow(1-t,4));
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
		"LoopByCount=DuplicateNum;"
		"LoopGetIndex=loop_index;"
		    "Pass=Smoke2;"
		"LoopEnd=;"
		"LoopByCount=DuplicateNum;"
		"LoopGetIndex=loop_index;"
		    "Pass=Smoke;"
		    "Pass=Thunder;"
		    "Pass=Paritcle;"
		"LoopEnd=;"
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
    	CULLMODE = NONE;
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
technique MainTec1 < string MMDPass = "object"; string Subset = "1"; > {
    pass MainPass {
        VertexShader = compile vs_3_0 Clear_VS();
        PixelShader  = compile ps_3_0 Clear_PS();
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