//メイン色設定
float3 MainColor = float3(2,1,0);
float3 SubColor = float3(1,1,1);

//発射本数
int MissileNum = 128;
//集中度
float Concent = 0.8;

#define CONTROLLER "Missile_ColorController.pmx"

float morph_r : CONTROLOBJECT < string name = CONTROLLER; string item = "赤"; >;
float morph_g : CONTROLOBJECT < string name = CONTROLLER; string item = "緑"; >;
float morph_b : CONTROLOBJECT < string name = CONTROLLER; string item = "青"; >;
float morph_rsub : CONTROLOBJECT < string name = CONTROLLER; string item = "赤sub"; >;
float morph_gsub : CONTROLOBJECT < string name = CONTROLLER; string item = "緑sub"; >;
float morph_bsub : CONTROLOBJECT < string name = CONTROLLER; string item = "青sub"; >;
float morph_add_si : CONTROLOBJECT < string name = CONTROLLER; string item = "加算倍率"; >;
float morph_a : CONTROLOBJECT < string name = CONTROLLER; string item = "透明度"; >;
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
// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler DefObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};
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

float3 Move(float t,int index)
{
	//仮想基準点の数
	float CurvePoint = 4;

	float3 rnd1 = getRandom(index*123.456);
	float3 rnd2 = getRandom(index*234.567);
	float3 rnd3 = getRandom(index*234.567);
	
	
	float3 pps0 = float3(0,0,0);
	float3 pps10 = float3(0,0,-20)+float3(0,(rnd1.x*2-1)*5,0);
	
	float i = floor(t*CurvePoint);
	
	float3 limit = float3(1,1,0)*inv_pow(t,2)*0.25;
	float3 p0 = (getRandom(((i-1.0)+index)*123.456)*2-1)*limit;
	float3 p1 = (getRandom(((i+0.0)+index)*123.456)*2-1)*limit;
	float3 p2 = (getRandom(((i+1.0)+index)*123.456)*2-1)*limit;
	float3 p3 = (getRandom(((i+2.0)+index)*123.456)*2-1)*limit;

	
	float local_t = frac(t*CurvePoint);
	
	float3 NowPos = Catmull(p0,p1,p2,p3,local_t);
	
	
	float3 svec = float3(0,(rnd1.x*2-1)*10,(rnd1.y*2-1)*10);
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
	
	
	NowPos += HermiteLerp(pps0,pps10,svec,evec,t);
	
	return NowPos;
}
float4x4 MissileMove(float t,int index)
{
	float4x4 mat;
	mat[0] = float4(1,0,0,0); 
	mat[1] = float4(0,1,0,0); 
	mat[2] = float4(0,0,1,0);
	mat[3] = float4(0,0,0,1);
	
	mat[3].xyz = 0;
	
	//移動量計算
	float3 NowPos = Move(t,index);
	float3 NextPos = Move(t+0.01,index);
	float3 PrevPos = Move(t-0.03,index);
	
	
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
	
	
	
	
	//ランダム回転（Z軸）
	float3 rndR = getRandom(index*3.456);
	mat[3].xyz += NowPos;
	
	//mat = RotZ(mat,t*rndR.z*2*3.1415+rndR.x*2*3.1415);
	mat = RotZ(mat,3.1415+rndR.x*2*3.1415);
	
	//mat[3].z -= 2;
	
	return mat;
}
VS_OUTPUT MissileFunc(float4 Pos,float3 Normal,float2 Tex)
{
	float addt = (float)g_index / (float)MissileNum*Concent;
	float gt = 1-Tr;
	float t = smoothstep(0+addt,0.2+addt,1-Tr);
	t += (1-Tr)*t*0.5;
	
    VS_OUTPUT Out = (VS_OUTPUT)0;
    Out.Alpha = 1.0;
	
    Out.Tex=0;
	Pos.xyz *= 0.2;
	
	//初期角度
	float rad = 0.5*2*3.1415;



	
	Pos.xyz = RotX_vec(Pos.xyz,rad);
	Normal = RotX_vec(Normal,rad);	

	float4x4 matMissile = MissileMove(t,g_index);
	Pos = mul(Pos,matMissile);
    Normal = normalize( mul( Normal, (float3x3)matMissile ) );
	
	Out.Tex = Tex;
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	
	Out.Alpha = t > 0.1;

    Out.t = t;
    return Out;
}
VS_OUTPUT LineFunc(float4 Pos,float3 Normal,float2 Tex,bool cross)
{
	float addt = (float)g_index / (float)MissileNum*Concent;
	float gt = 1-Tr;
	float t = smoothstep(0+addt,0.2+addt,1-Tr);

    VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Alpha = (t > 0);
	
	t += (1-Tr)*t*0.5;
	
	float id = Pos.z;
	
	
	
	Pos.x *= 0.1;
	Pos.z = 0;
	if(cross) Pos.xy = Pos.yx;
	
	float3 Prev,Now;
	float4x4 matMissileNow = MissileMove(max(0,t - id),g_index);
	
	Now = matMissileNow[3].xyz;
	Now.z += inv_pow(t,4)*48*id;
	
	Pos.xyz += Now;
	

    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	
	Out.Alpha *= 0.5*(1-id)*inv_pow(1-gt,4) * t - id;

    Out.t = t;
    return Out;
}
VS_OUTPUT FlashFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
	float addt = (float)g_index / (float)MissileNum*Concent;
	float gt = 1-Tr;
	float t = smoothstep(0+addt,0.2+addt,1-Tr);

    VS_OUTPUT Out = (VS_OUTPUT)0;

	t += (1-Tr)*t*0.5;
	
	float id = Pos.z;
		
	Pos.xy *= 64;
	Pos.xy *= smoothstep(0.15,0.3,t)+0.1;
	Pos.xy *= smoothstep(0.3,0.1,t);
	Pos.z = 0;
	//ビルボード回転
	float3 rndR = getRandom(g_index*3.456);
	Pos.xyz = RotZ_vec(Pos.xyz,rndR*2*3.1415);
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
    
	float3 Prev,Now;
	float4x4 matMissileNow = MissileMove(t,g_index);
	
	Now = matMissileNow[3].xyz;
	
	Pos.xyz += Now;
	

    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
	Out.AddTex.x += 0.5;
	Out.AddTex.y += 0.0;
	Out.Alpha = t > 0.1;
	Out.Alpha *= inv_pow(1-gt,4);
	
	//Out.Alpha *= smoothstep(0.4,0.08,t);

    Out.t = t;
    return Out;
}
VS_OUTPUT LightFunc(int index,float4 Pos,float3 Normal,float2 Tex)
{
	float addt = (float)g_index / (float)MissileNum*Concent;
	float gt = 1-Tr;
	float t = smoothstep(0+addt,0.2+addt,1-Tr);

    VS_OUTPUT Out = (VS_OUTPUT)0;

	t += (1-Tr)*t*0.5;
	
	float id = Pos.z;
		
	Pos.xy *= 5+abs(sin(t*1234.567))*10;
	Pos.z = 0;
	//ビルボード回転
	float3 rndR = getRandom(g_index*3.456);
	Pos.xyz = RotZ_vec(Pos.xyz,rndR*2*3.1415);
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
    
    Pos.y -= 0.0;
	float3 Prev,Now;
	float4x4 matMissileNow = MissileMove(t,g_index);
	
	Now = matMissileNow[3].xyz;
	
	Pos.xyz += Now;

    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.Tex = Tex;
    
	Out.AddTex.x += 0.5;
	Out.AddTex.y += 0.0;
	Out.Alpha = t > 0.3;
	Out.Alpha *= inv_pow(1-gt,4);

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
	    Out = MissileFunc(Pos,Normal,Tex);
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
		MainColor.rgb = float3(morph_r,morph_g,morph_b)*(1+morph_add_si*8);
		SubColor.rgb = float3(morph_rsub,morph_gsub,morph_bsub)*32;
	}	
	if(mode == 0)
	{
		Col = tex2D(DefObjTexSampler,IN.Tex);
		Col.rgb += MainColor;
		
		float3 d = saturate(dot(normalize(-LightDirection),normalize(IN.Normal))*0.5+0.5)*(LightAmbient+0.3);
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
		Col.a = 0;
	}
	if(mode == 4)
	{
		Col = tex2D(SampParticle,(IN.Tex*0.5)+IN.AddTex);
		Col.rgb *= Col.a;
		Col.a = 1;
		Col.rgb *= MainColor*1;
		Col.a = 0;
		
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

// オブジェクト描画用テクニック
technique MainTec0 < string MMDPass = "object"; string Subset = "3"; 
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"

		"LoopByCount=MissileNum;"
		"LoopGetIndex=g_index;"
		    "Pass=Flash;"
		    "Pass=Light;"
		"LoopEnd=;"
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
}
technique MainTec1 < string MMDPass = "object"; string Subset = "2";
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
		"LoopByCount=MissileNum;"
		"LoopGetIndex=g_index;"
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
	    
		"LoopByCount=MissileNum;"
		"LoopGetIndex=g_index;"
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