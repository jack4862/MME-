//メイン色設定
float3 MainColor = float3(2,1,0);
float3 SubColor = float3(1,1,1);
//複製数
#define MISSILE_COUNT 128
//再生スピード
float particleSpeed = 0.1;
//爆発サイズ
float BomScale = 1.0;

//爆破発生半径
float SetScale = 16;

#define TGT "MissileTgt_1.x"
bool bTgt : CONTROLOBJECT < string name = TGT;>;
float3 TgtPos : CONTROLOBJECT < string name = TGT;>;

#define CONTROLLER "Missile_ColorController.pmx"

int g_index_loop;
float morph_r : CONTROLOBJECT < string name = CONTROLLER; string item = "赤"; >;
float morph_g : CONTROLOBJECT < string name = CONTROLLER; string item = "緑"; >;
float morph_b : CONTROLOBJECT < string name = CONTROLLER; string item = "青"; >;

float morph_subr : CONTROLOBJECT < string name = CONTROLLER; string item = "赤sub"; >;
float morph_subg : CONTROLOBJECT < string name = CONTROLLER; string item = "緑sub"; >;
float morph_subb : CONTROLOBJECT < string name = CONTROLLER; string item = "青sub"; >;

float morph_add_si : CONTROLOBJECT < string name = CONTROLLER; string item = "加算倍率"; >;
float morph_a : CONTROLOBJECT < string name = CONTROLLER; string item = "透明度"; >;
float morph_size : CONTROLOBJECT < string name = CONTROLLER; string item = "爆発サイズ"; >;
float morph_len : CONTROLOBJECT < string name = CONTROLLER; string item = "広がり"; >;
float morph_len2 : CONTROLOBJECT < string name = CONTROLLER; string item = "奥行"; >;
float morph_spd : CONTROLOBJECT < string name = CONTROLLER; string item = "発生速度"; >;
bool bController : CONTROLOBJECT < string name = CONTROLLER; >;

bool bHitSphere : CONTROLOBJECT < string name = "HitSphere.x";>;
float4x4 HitPos : CONTROLOBJECT < string name = "HitSphere.x";>;
float HitScale : CONTROLOBJECT < string name = "HitSphere.x";>;

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

texture TexMissileSmoke<
    string ResourceName = "../Texture/MissileSmoke.png";
>;
sampler SampMissileSmoke = sampler_state {
    texture = <TexMissileSmoke>;
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

float Tr : CONTROLOBJECT < string name = "(self)";string item = "Tr";>;
float Si : CONTROLOBJECT < string name = "(self)";string item = "Si";>;

#define TEX_HEIGHT  (MISSILE_COUNT)

texture DepthBuffer : RenderDepthStencilTarget <
   int Width=5;
   int Height=TEX_HEIGHT;
    string Format = "D24S8";
>;
texture matBufTex : RenderColorTarget
<
   int Width=5;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture matBufTexCpy : RenderColorTarget
<
   int Width=5;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler matBuf = sampler_state
{
   Texture = (matBufTex);
   ADDRESSU = CLAMP;
   ADDRESSV = WRAP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler matBufCpy = sampler_state
{
   Texture = (matBufTexCpy);
   ADDRESSU = CLAMP;
   ADDRESSV = WRAP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

sampler rnd = sampler_state {
    texture = <rndtex>;
    MINFILTER = NONE;
    MAGFILTER = NONE;
};

//乱数テクスチャサイズ
#define RNDTEX_WIDTH  256
#define RNDTEX_HEIGHT 256

//乱数取得
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

float time : TIME;


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
float4x4 RotView(float4x4 mat,float3 X,float3 Y,float3 Z)
{
	X = normalize(X);
	Y = normalize(Y);
	Z = normalize(Z);

	float4x4 matRot;
	matRot[0] = float4(X.x,X.y,X.z,0); 
	matRot[1] = float4(Y.x,Y.y,Y.z,0); 
	matRot[2] = float4(Z.x,Z.y,Z.z,0);
	matRot[3] = float4(0,0,0,1);
	
	

	return mul(mat,matRot);
}

//エルミート補完関数
float3 HermiteLerp(float3 s,float3 e,float3 svec,float3 evec,float t)
{
	return (((t-1)*(t-1))*(2*t+1)*s) + ((t*t)*(3-2*t)*e) +((1-(t*t))*t*svec) + ((t-1)*(t*t)*evec);
}

// 三次元のCatmull-Romスプライン曲線　p1～p2間をuが0～1で補間する
float3 Catmull(float3 p0, float3 p1, float3 p2, float3 p3, float t)
{
	//return (-0.5*p0+1.5*p1-1.5*p2+0.5*p3)*pow(t,3)+(p0-2.5*p1+2.5*p2+0.5*p3)*pow(t,2)+(-0.5*p0+0.5*p2)*t + p1;

	
    float t2 = t*t;
    float t3 = t2*t;
    float3 v0 = (p3-p1)*0.5;
    float3 v1 = (p2-p0)*0.5;
    float3 pos = (2*p0-2*p1+v0+v1)*t3 + (-3*p0+3*p1-2*v0-v1)*t2 + v0*t + p0;
    return pos;
    
}

float3 GetBasePos()
{
	float2 base_tex_coord = float2( 3.0/5.0+0.01, float(g_index_loop)/TEX_HEIGHT + 0.5/TEX_HEIGHT);
	float3 Base = tex2Dlod(matBuf, float4(base_tex_coord,0,1)).xyz;
	
	return Base;
}
float3 GetTgtPos()
{
	float2 base_tex_coord = float2( 1, float(g_index_loop)/TEX_HEIGHT + 0.5/TEX_HEIGHT);
	float3 Base = tex2Dlod(matBuf, float4(base_tex_coord,0,1)).xyz;
	return Base;
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
	add /= Si;
	
	if(!bController)
	{
		morph_len = 1;
	}
	base_pos.xyz += GetBasePos();
	
	return base_pos.xyz;
}
float4x4 RevMat(float4x4 mat)
{
    return float4x4(
        mat._11, mat._21, mat._31, 0,
        mat._12, mat._22, mat._32, 0,
        mat._13, mat._23, mat._33, 0,
        0,0,0,1
    );
}
float3 Move(float t,int index,float4x4 matRotG)
{
	//仮想基準点の数
	float CurvePoint = 4;

	float3 rnd1 = getRandom(index*123.456);
	float3 rnd2 = getRandom(index*234.567);
	float3 rnd3 = getRandom(index*234.567);
	//SetScale*morph_len*Si*0.1
	
	float3 pps0 = float3(0,0,0);
	float3 pps10 = float3(0,0,-20*(1+morph_len2*5));
	
	float3 AddRnd = rnd3*2-1;
	
	float i = floor(t*CurvePoint);
	
	float3 limit = float3(1,1,0)*inv_pow(t,2)*0.25;
	float3 p0 = (getRandom(((i-1.0)+index)*123.456)*2-1)*limit;
	float3 p1 = (getRandom(((i+0.0)+index)*123.456)*2-1)*limit;
	float3 p2 = (getRandom(((i+1.0)+index)*123.456)*2-1)*limit;
	float3 p3 = (getRandom(((i+2.0)+index)*123.456)*2-1)*limit;

	
	float local_t = frac(t*CurvePoint);
	
	float3 NowPos = Catmull(p0,p1,p2,p3,local_t);
	
	
	//float3 svec = float3(SetScale*(1+morph_len*64),(rnd1.x*2-1)*10,(rnd1.y*2-1)*10);
	float3 svec = float3(20,(rnd1.x*2-1)*10,(rnd1.y*2-1)*10);
	
	//ランダム回転（Z軸）
	float3 rndR = getRandom(index*3.456);
	svec = RotZ_vec(svec,3.1415+rndR.x*123.456);
	
	float3 evec = float3(0,(rnd2.x*2-1)*10,(rnd2.z*2-1)*10);
	//svec.z = -10;
	svec.z += 10;
	evec.z = -50;
	evec.xy *= 0.25;
	svec.xy *= 0.25;
/*
	svec = float3(0,5,15)*(rnd1.x*0.5+0.5);
	evec = float3(0,0,-10)*rnd1.y;
*/
	if(bTgt)
	{
		pps10 = GetTgtPos();
		pps10 -= GetBufPos(index).xyz;
		pps10 = mul(pps10,(float3x3)RevMat(matRotG));
		pps10 *= 0.01;
	}
	pps10 += AddRnd*1;
	NowPos += HermiteLerp(pps0,pps10,svec,evec,t);
	
	return NowPos;
}
float4x4 MissileMove(float t,int index)
{
	float4x4 mat;
	float4x4 matRot;
	mat[0] = float4(1,0,0,0); 
	mat[1] = float4(0,1,0,0); 
	mat[2] = float4(0,0,1,0);
	mat[3] = float4(0,0,0,1);
	matRot = mat;	
	
	//回転行列作成
	float2 base_tex_coord;
	base_tex_coord = float2( 0, float(g_index_loop)/TEX_HEIGHT + 0.5/TEX_HEIGHT);
	matRot[0].xyz = tex2Dlod(matBuf, float4(base_tex_coord,0,1)).xyz;
	base_tex_coord = float2( 1.0/5.0+0.01, float(g_index_loop)/TEX_HEIGHT + 0.5/TEX_HEIGHT);
	matRot[1].xyz = tex2Dlod(matBuf, float4(base_tex_coord,0,1)).xyz;
	base_tex_coord = float2( 2.0/5.0+0.01, float(g_index_loop)/TEX_HEIGHT + 0.5/TEX_HEIGHT);
	matRot[2].xyz = tex2Dlod(matBuf, float4(base_tex_coord,0,1)).xyz;
	
	
	//移動量計算
	float3 NowPos = Move(t,index,matRot);
	float3 NextPos = Move(t+0.01,index,matRot);
	float3 PrevPos = Move(t-0.03,index,matRot);
	
	
	//進行ベクトル
	float3 Vec = normalize(NextPos - NowPos);
	float3 DefVec = float3(0,0,-1);
	
	Vec = lerp(DefVec,Vec,t);
	
	
	//アップベクトル
	float3 Up = float3(0,1,0); // 最初は仮の値
	
	//サイドベクトル
	float3 Side = normalize(cross(Vec,Up));
	
	//アップベクトル再計算
	Up = normalize(cross(Vec,Side));
	
	//サイドベクトル再計算
	Side = normalize(cross(Up,Vec));
	
	mat = RotView(mat,Side,Up,Vec);
	
	
	
	
	mat[3].xyz += NowPos;
	
	//mat = RotZ(mat,t*rndR.z*2*3.1415+rndR.x*2*3.1415);
	
	
	
	
    float3 gAddPos = GetBufPos(g_index_loop).xyz*0.1;

	//回転行列適用
	mat = mul(mat,matRot);
	mat[3].xyz *= 0.1;
	
	mat[3].xyz += gAddPos;
	
	return mat;
}
VS_OUTPUT MissileFunc(float4 Pos,float3 Normal)
{
	float addt = 0;
	float t = frac(float(g_index_loop)/MISSILE_COUNT + particleSpeed * Time * (1-morph_spd));
	t = smoothstep(0,0.2,t);
	if(t > 0.99) t = 0;
	VS_OUTPUT Out = (VS_OUTPUT)0;
    Out.Alpha = 1.0;
	
    Out.Tex=0;
	Pos.xyz *= 0.001;
	
	//初期角度
	float rad = 0.25*2*3.1415;



	
	Pos.xyz = RotX_vec(Pos.xyz,rad);
	Normal = RotX_vec(Normal,rad);	

	float4x4 matMissile = MissileMove(t,g_index_loop);
	Pos = mul(Pos,matMissile);
    Normal = normalize( mul( Normal, (float3x3)matMissile ) );
	
	Pos.xyz *= Si;
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    //Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	Out.Normal = normalize( Normal );
	
	Out.Alpha = t > 0.01;

    Out.t = t;
    return Out;
}
VS_OUTPUT LineFunc(float4 Pos,float3 Normal,float2 Tex,bool cross)
{
	float addt = 0;
	float t = frac(float(g_index_loop)/MISSILE_COUNT + particleSpeed * Time * (1-morph_spd));
	t = smoothstep(0,0.2,t);
	if(t > 0.99) t = 0;
	
	
    VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Alpha = (t > 0);
	
	float id = Pos.z;
	
	
	
	Pos.x *= 0.05;
	
	Pos.z = 0;
	if(cross) Pos.xy = Pos.yx;
	
	float3 Prev,Now;
	//float4x4 matMissileNow = MissileMove(max(0,t - id),g_index_loop);
	float4x4 matMissileNow = MissileMove(max(0,t - id),g_index_loop);
	
	Now = matMissileNow[3].xyz;
	Now -= normalize(matMissileNow[2])*inv_pow(t,4)*8*id;
	
	Pos.xyz += Now;
	

	Pos.xyz *= Si;
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	
	Out.Alpha *= (1*(1-id) * t - id)*inv_pow(1-t,16);
	//Out.Alpha *= t*inv_pow(1-t,8);

    Out.t = t;
    return Out;
}
VS_OUTPUT FlashFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
	float addt = 0;
	float t = frac(float(g_index_loop)/MISSILE_COUNT + particleSpeed * Time * (1-morph_spd));
	float old_t = t;
	if(t > 0.99) t = 0;
	
	t = smoothstep(0,0.2,t);
	
    VS_OUTPUT Out = (VS_OUTPUT)0;

	//t += (1-Tr)*t*0.5;
	if(old_t < 0.19)
	{
		float id = Pos.z;
			
		Pos.xy *= 64;
		Pos.xy *= smoothstep(0.15,0.3,t)+0.1;
		Pos.xy *= smoothstep(0.3,0.1,t);
		Pos.z = 0;
		//ビルボード回転
		float3 rndR = getRandom(g_index_loop*3.456);
		Pos.xyz = RotZ_vec(Pos.xyz,rndR*2*3.1415);
	    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	    Pos.xyz = mul( Pos.xyz,(float3x3)WorldMatrix)*0.1;
	    
		float3 Prev,Now;
		float4x4 matMissileNow = MissileMove(t,g_index_loop);
		
		Now = matMissileNow[3].xyz;
		
		Pos.xyz += Now;
		

		Pos.xyz *= Si;
	    Out.Pos = mul( Pos, ViewProjMatrix );
	    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
	    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	    Out.Tex = Tex;
	    
		Out.AddTex.x += 0.5;
		Out.AddTex.y += 0.0;
		Out.Alpha = t > 0.1;
		
		//Out.Alpha *= smoothstep(0.4,0.08,t);

	    Out.t = t;
	}else{
		float id = Pos.z;
			
		Pos.xy *= 128;
		Pos.xy *= smoothstep(0.19,0.2,old_t)+0.1;
		Pos.xy *= smoothstep(0.3,0.1,old_t);
		Pos.z = 0;
		//ビルボード回転
		float3 rndR = getRandom(g_index_loop*3.456);
		Pos.xyz = RotZ_vec(Pos.xyz,rndR*2*3.1415);
	    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
	    Pos.xyz = mul( Pos.xyz,(float3x3)WorldMatrix)*0.1;
	    
		float3 Prev,Now;
		float4x4 matMissileNow = MissileMove(t,g_index_loop);
		
		Now = matMissileNow[3].xyz;
		
		Pos.xyz += Now;

		Pos.xyz *= Si;
	    Out.Pos = mul( Pos, ViewProjMatrix );
	    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
	    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	    Out.Tex = Tex;
	    
		Out.AddTex.x += 0.5;
		Out.AddTex.y += 0.0;
		Out.Alpha = 1;
		
		//Out.Alpha *= smoothstep(0.4,0.08,t);

	    Out.t = t;
	}
    return Out;
}
VS_OUTPUT LightFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
	float addt = 0;
	float t = frac(float(g_index_loop)/MISSILE_COUNT + particleSpeed * Time * (1-morph_spd));
	t = smoothstep(0,0.2,t);
	if(t > 0.99) t = 0;
	

    VS_OUTPUT Out = (VS_OUTPUT)0;
	
	float id = Pos.z;
		
	Pos.xy *= 5+abs(sin(t*1234.567))*10;
	Pos.z = 0;
	//ビルボード回転
	float3 rndR = getRandom(g_index_loop*3.456);
	Pos.xyz = RotZ_vec(Pos.xyz,rndR*2*3.1415);
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
    Pos.xyz = mul( Pos.xyz,(float3x3)WorldMatrix)*0.1;
    
	float3 Prev,Now;
	float4x4 matMissileNow = MissileMove(t,g_index_loop);
	
	Now = matMissileNow[3].xyz;
	
	Pos.xyz += Now;
	

	Pos.xyz *= Si;
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
	Out.AddTex.x += 0.0;
	Out.AddTex.y += 0.0;
	Out.Alpha = t > 0.3;
	//Out.Alpha *= inv_pow(1-gt,4);

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
	    Out = MissileFunc(Pos,Normal);
    }
    if(mode == 1)
	{
	    Out = LineFunc(Pos,Normal,Tex,false);
    }
    if(mode == 2)
	{
	    Out = LineFunc(Pos,Normal,Tex,true);
    }
    
    if(mode == 3)
    {
	    Out = FlashFunc(index,Pos,Normal,Tex);
	    
		if(1 < index)
		{
			Out.Pos.z = -2;
		}
    }
    if(mode == 4)
	{
	    Out = LightFunc(index,Pos,Normal,Tex);
	    
		if(1 < index)
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
		SubColor.rgb = float3(morph_subr,morph_subg,morph_subb)*(1+morph_add_si);
	}	
	if(mode == 0)
	{
		Col = 1;
		
		float d = saturate(dot(normalize(-LightDirection),normalize(IN.Normal)))*(LightAmbient+0.3);
		Col.rgb *= d;
	}
	if(mode == 1)
	{
		Col = tex2D(SampMissileSmoke,(IN.Tex)+IN.AddTex);
		Col.a = Col.r;
		Col.rgb *= SubColor;
		
	}
	if(mode == 3)
	{
		Col = tex2D(SampParticle,(IN.Tex*0.5)+IN.AddTex);
		Col.rgb *= Col.a;
		Col.a = 1;
		Col.rgb *= MainColor*8;
	}
	if(mode == 4)
	{
		Col = tex2D(SampParticle,(IN.Tex*0.5)+IN.AddTex);
		Col.rgb *= Col.a;
		Col.a = 1;
		Col.rgb *= MainColor*1;
		
	}
	
	Col.a *= IN.Alpha;
	Col.a = saturate(Col.a);
		
	if(use_spe && (mode == 3 || mode == 4))
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

struct VS_OUTPUT2 {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
};


VS_OUTPUT2 ParticleBase_Vertex_Shader_main(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex + float2(0.5/5.0, 0.5/TEX_HEIGHT);
   return Out;
}

float4 ParticleBase_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
	
	int idx = round(texCoord.y*TEX_HEIGHT);
	if ( idx >= MISSILE_COUNT ) idx -= MISSILE_COUNT;

	float t = frac(float(idx)/MISSILE_COUNT + particleSpeed * Time * (1-morph_spd));
	
	//前回の値取得
	float4 old_color = tex2D(matBufCpy, texCoord);
	
	//横（列）+0.1は誤差対策
	int w = (int)((texCoord.x*5.0)+0.1);
	float4 OutColor = 1;
	//tよりもアルファ（経過時間）が小さい場合そのまま保持
	if ( old_color.a <= t ) {
	    old_color.a = t;
	    OutColor = old_color;
	}else{
	//時間経過によるリセット
		//Trが0なら生成ストップ(超長距離に吹き飛ばす)
		if(Tr == 0 && w == 3)
		{
			OutColor = float4(0xffff,0xffff,0xffff,t);
		}else{
			//現在の自分の列に合わせて回転行列出力
			if(w != 4)
			{
				OutColor = float4(WorldMatrix[w].xyz,t);
			}else{
				//ターゲット座標保存
				OutColor = float4(TgtPos,t);
			}
		}
	}
	return OutColor;
}

VS_OUTPUT2 ParticleBase2_Vertex_Shader_main(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex + float2(0.5/5.0, 0.5/TEX_HEIGHT);
   return Out;
}

float4 ParticleBase2_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
	//そのままコピー
	float4 col = tex2D(matBuf, texCoord);
	return col;
	
}

int nParticleCount = MISSILE_COUNT;

float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

// オブジェクト描画用テクニック
technique MainTec0 < string MMDPass = "object"; string Subset = "3"; 
    string Script = 
		"RenderColorTarget0=matBufTex;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=ParticleBase;"
		"RenderColorTarget0=matBufTexCpy;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=ParticleBase2;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"

		"LoopByCount=nParticleCount;"
		"LoopGetIndex=g_index_loop;"
		    "Pass=Flash;"
		    "Pass=Light;"
		"LoopEnd=;"
		//"Pass=ParticleBase2;"
    ;
> {
    pass Flash {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(3);
        PixelShader  = compile ps_3_0 Main_PS(3);
    }
    pass Light {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = ONE;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(4);
        PixelShader  = compile ps_3_0 Main_PS(4);
    }
	pass ParticleBase < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_3_0 ParticleBase_Vertex_Shader_main();
	    PixelShader = compile ps_3_0 ParticleBase_Pixel_Shader_main();
	}
	pass ParticleBase2 < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_3_0 ParticleBase2_Vertex_Shader_main();
	    PixelShader = compile ps_3_0 ParticleBase2_Pixel_Shader_main();
	}
}
technique MainTec1 < string MMDPass = "object"; string Subset = "2";
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"

		"LoopByCount=nParticleCount;"
		"LoopGetIndex=g_index_loop;"
		    "Pass=MainPass1;"
		    "Pass=MainPass2;"
		"LoopEnd=;"
    ;
> {
    pass MainPass1 {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(1);
        PixelShader  = compile ps_3_0 Main_PS(1);
    }
    pass MainPass2 {
    	SRCBLEND = SRCALPHA;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = FALSE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(2);
        PixelShader  = compile ps_3_0 Main_PS(1);
    }
}
technique MainTec2 < string MMDPass = "object"; string Subset = "1";    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=Sphere;"
    ;
> {
    pass Sphere {
    	SRCBLEND = SRCALPHA;
    	//DESTBLEND = ONE;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = TRUE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(10);
        PixelShader  = compile ps_3_0 Main_PS(10);
    }
}
technique MainTec3 < string MMDPass = "object"; string Subset = "0";    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    
		"LoopByCount=nParticleCount;"
		"LoopGetIndex=g_index_loop;"
	    "Pass=Model;"
		"LoopEnd=;"
    ;
> {
    pass Model {
    	SRCBLEND = SRCALPHA;
    	//DESTBLEND = ONE;
    	DESTBLEND = INVSRCALPHA;
    	ZENABLE = TRUE;
    	ZWRITEENABLE = TRUE;
    	CULLMODE = NONE;
        VertexShader = compile vs_3_0 Main_VS(0);
        PixelShader  = compile ps_3_0 Main_PS(0);
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