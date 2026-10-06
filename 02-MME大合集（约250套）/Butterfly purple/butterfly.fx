// sh5改変
/***************************************************************
 *  Effect File exported by RenderMonkey 1.6
 *
 *  - Although many improvements were made to RenderMonkey FX  
 *    file export, there are still situations that may cause   
 *    compilation problems once the file is exported, such as  
 *    occasional naming conflicts for methods, since FX format 
 *    does not support any notions of name spaces. You need to 
 *    try to create workspaces in such a way as to minimize    
 *    potential naming conflicts on export.                    
 *    
 *  - Note that to minimize resulting name collisions in the FX 
 *    file, RenderMonkey will mangle names for passes, shaders  
 *    and function names as necessary to reduce name conflicts. 
 ****************************************************************/

/*--------------------------------------------------------------*/
// BufferflyParticleSystem
//--------------------------------------------------------------//

//--------------------------------------------------------------//
// ParticleSystem
//--------------------------------------------------------------//

float4x4 world_view_proj_matrix : WorldViewProjection;
float4x4 world_view_trans_matrix : WorldViewTranspose;
static float3 billboard_vec_x = normalize(world_view_trans_matrix[0].xyz);
static float3 billboard_vec_y = normalize(world_view_trans_matrix[1].xyz);

// 座法変換行列
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;

static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};

float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;

float time_0_X : Time;

int CloneNum
<
   string UIName = "パーティクルの数";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   int UIMin = int(1);
   int UIMax = int(2000);
   string UIHelp = "パーティクルの数を指定します。";
> = int( 90 );

float particleSpread
<
   string UIName = "パーティクルの広がり";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = float(0.00);
   float UIMax = float(10.00);
> = float( 2.4 );
float particleSpeed
<
   string UIName = "パーティクルのスピード";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = float(-2.00);
   float UIMax = float(2.00);
> = float( 0.25 );
float particleSpeed2
<
   string UIName = "パーティクルのはばたきスピード";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = float(0.00);
   float UIMax = float(100.00);
> = float( 50 );
float particleRotate
<
   string UIName = "パーティクルの拡散方向";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = float(-2.00);
   float UIMax = float(2.00);
> = float( 0.2 );
float particleDirection
<
   string UIName = "パーティクルの向き";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = float(0.00);
   float UIMax = float(2.00);
   string UIHelp = "指定秒後の位置に対してパーティクルを向けます。";
> = float( 0.5 );

float particleSystemDistance
<
   string UIName = "パーティクルまでの距離";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = float(0.00);
   float UIMax = float(100.00);
> = float( 1 );

float particleSystemHeight
<
   string UIName = "パーティクルの上昇距離";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = float(0.00);
   float UIMax = float(100.00);
> = float( 1 );

float particleXRate
<
   string UIName = "X";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = float(0.00);
   float UIMax = float(10.00);
> = float( 1 );
float particleYRate
<
   string UIName = "Y";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = float(0.00);
   float UIMax = float(10.00);
> = float( 0.7 );
float particleZRate
<
   string UIName = "Z";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = float(0.00);
   float UIMax = float(10.00);
> = float( 1 );

float particleSizeMax
<
   string UIName = "パーティクルの最大サイズ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = float(0.00);
   float UIMax = float(10.00);
> = float( 1 );

float particleSizeMin
<
   string UIName = "パーティクルの最小サイズ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = float(0.00);
   float UIMax = float(10.00);
> = float( 1 );

bool up_fade = true;
bool down_fade = true;
static const float fade_width
<
   string UIName = "フェードイン・フェードアウト";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = float(0.00);
   float UIMax = float(0.50);
> = float( 0.2 );

int index = 0;
//パーティクルテクスチャ

texture2D Tex <
    string ResourceName = "butterfly.png";
    int MipLevels = 0;
>;
sampler TexSamp = sampler_state {
    texture = <Tex>;
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
};

// The model for the particle system consists of a hundred quads.
// These quads are simple (-1,-1) to (1,1) quads where each quad
// has a z ranging from 0 to 1. The z will be used to differenciate
// between different particles

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
   float rate: TEXCOORD2;
   float alpha: TEXCOORD3;
};

static const float PI = 3.14159265;

VS_OUTPUT BufferflyParticleSystem_Vertex_Shader_main(float4 Pos: POSITION, float2 Tex : TEXCOORD0){
   VS_OUTPUT Out;

   // Loop particles
   float tt = time_0_X;
   float ttt, z;
   float count = index;
   int icount = (int)round(count);
   z = (float)index / (float)CloneNum;
   float tz = trunc(z + particleSpeed * time_0_X);
   float t = frac(z + particleSpeed * time_0_X);
   float t2 = t + particleDirection;

   float3 pos = 0, dpos = 0;
   // Spread particles in a semi-random fashion
   float yee;
   float zz = z + tz * 1.0002339;
   if (icount % 3 == 0) {
        pos.x = particleSpread *  cos(11343 * zz);
        pos.z = particleSpread *  sin(163 * zz);
        yee = cos(12237*zz + z * 163)*sin(9431*z + zz);
   } else if (icount % 3 == 1) {
        pos.x = particleSpread *  cos(223 * zz + 11 * zz);
        pos.z = particleSpread *  sin(1437 * zz + 777 * tz);
        yee = cos(1227*zz)*sin(93347*z + tz*3);
   } else {
        pos.x = particleSpread *  cos(1347 * zz);
        pos.z = particleSpread *  sin(137 * zz + 1997 * zz);
        yee = cos(1437*zz + z * 13)*sin(94347*z*zz);
   }
   // Particles goes up
   pos.y = frac(z * 163 + z * sin(z * 199467 + 783447));
   dpos.xyz = pos.xyz;

#if 0  // 左の0を1に変えると下の加速処理が有効になる
   // 2882 - 2895 フレームにかけて加速して広がる
   float t_start = 2882.0 / 30;
   float t_end = 2895.0 / 30;
   float t_rate = saturate((time_0_X - t_start) / (t_end - t_start));
#else
   float t_rate = 0;
#endif

   float rate = t;

   float a1 = (abs(pos.x+0.1) * rate/5 * 13)*0.5;
   float b1 = (pos.z*13+1.0 - rate*particleRotate)*PI;
   pos.y = sin(pos.y * PI * rate * 0.5 + yee) * 0.7 + 0.5;
   a1 = a1 + particleSystemDistance * (a1 > 0 ? 1 : -1);
   pos.x = a1 * sin(b1);
   pos.z = a1 * cos(b1);
   pos.y *= particleSystemHeight;

   pos.x *= particleXRate;
   pos.y *= particleYRate;
   pos.z *= particleZRate;

   float drate = t2;

   float a2 = (abs(dpos.x+0.1) * drate/5 * 13)*0.5;
   float b2 = (dpos.z*13+1.0 - drate*particleRotate)*PI;
   dpos.y = sin(dpos.y * PI * drate * 0.5 + yee) * 0.7 + 0.5;
   a2 = a2 + particleSystemDistance * (a2 > 0 ? 1 : -1);
   dpos.x = a2 * sin(b2);
   dpos.z = a2 * cos(b2);
   dpos.y *= particleSystemHeight;

   dpos.x *= particleXRate;
   dpos.y *= particleYRate;
   dpos.z *= particleZRate;

   pos.xz *= 1 + 1 * t_rate;
   dpos.xz *= 1 + 1 * t_rate;

   float3 dir = dpos - pos;

   float size = particleSizeMin + (particleSizeMax - particleSizeMin) * frac(yee);
   Pos.xy *= size;
   Pos.z = 0;
   
   float rad;
   float2x2 rot;
   float ht = t * particleSpeed2 * (1 + t_rate*.5);
   float dr = 50;
   // ぱたぱたと、はねを動かす
   if (Pos.x > 0) {
       rad = sin(zz * yee + ht) * 0.7;
       rot = float2x2(cos(rad),sin(rad),-sin(rad),cos(rad));
       Pos.xz = mul(Pos.xz, rot);
       Pos.z += -rad/dr;
   } else {
       rad = -sin(zz * yee + ht) * 0.7;
       rot = float2x2(cos(rad),sin(rad),-sin(rad),cos(rad));
       Pos.xz = mul(Pos.xz, rot);
       Pos.z += rad/dr;
   }
   // ちょっと仰角姿勢
   rad = PI/2 * 0.8;
   rot = float2x2(cos(rad),sin(rad),-sin(rad),cos(rad));
   Pos.yz = mul(Pos.yz, rot);
   //if (dir.x == 0 && dir.y == 0) dir = 1;
   // 進行方法へ向ける
   rad = -PI/2.0 + atan2(dir.z, dir.x);
   if (particleSpeed < 0)
       rad += PI;
   rot = float2x2(cos(rad),sin(rad),-sin(rad),cos(rad));
   Pos.xz = mul(Pos.xz, rot);
     
   //Pos.xyz = mul(Pos.xyz, BillboardMatrix);

   Pos.xyz += pos;
   Out.Pos = mul(Pos, world_view_proj_matrix);
   Out.texCoord = Tex;

   Out.color = frac(yee);

   Out.alpha = alpha1;
   Out.rate = rate;

   return Out;
}


float4 BufferflyParticleSystem_Pixel_Shader_main(float2 texCoord: TEXCOORD0, float color: TEXCOORD1, float rate: TEXCOORD2, float alpha: TEXCOORD3) : COLOR {
   // Fade the particle to a circular shape

   float4 ret;
   ret = tex2D( TexSamp, texCoord );

   ret.rgb *= alpha;

   float start = fade_width;
   float end = 1.0 - fade_width;
   if (rate > end)
	   ret.rgb *= (((1.0 - rate) / (1.0 - end)));
   if (rate < start)
	   ret.rgb *= (rate / start);
   ret.rgb *= 0.5;
   return ret;
}


//--------------------------------------------------------------//
// Technique Section for Effect Workspace.Particle Effects.BufferflyParticleSystem
//--------------------------------------------------------------//
technique BufferflyParticleSystem <
    string Script = 
		//描画対象をメイン画面に
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    //パスの選択
		"LoopByCount=CloneNum;"
        "LoopGetIndex=index;"
	    "Pass=ParticleSystem;"
        "LoopEnd=;"
    ;
> {
   pass ParticleSystem
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND = ONE;
      DESTBLEND = ONE;

      VertexShader = compile vs_2_0 BufferflyParticleSystem_Vertex_Shader_main();
      PixelShader = compile ps_2_0 BufferflyParticleSystem_Pixel_Shader_main();
   }

}

