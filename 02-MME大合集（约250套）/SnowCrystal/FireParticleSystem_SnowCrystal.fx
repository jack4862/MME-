//**************************************************************//
//  Effect File exported by RenderMonkey 1.6
//
//  - Although many improvements were made to RenderMonkey FX  
//    file export, there are still situations that may cause   
//    compilation problems once the file is exported, such as  
//    occasional naming conflicts for methods, since FX format 
//    does not support any notions of name spaces. You need to 
//    try to create workspaces in such a way as to minimize    
//    potential naming conflicts on export.                    
//    
//  - Note that to minimize resulting name collisions in the FX 
//    file, RenderMonkey will mangle names for passes, shaders  
//    and function names as necessary to reduce name conflicts. 
//**************************************************************//

//--------------------------------------------------------------//
// FireParticleSystem
//--------------------------------------------------------------//
//--------------------------------------------------------------//
// ParticleSystem
//--------------------------------------------------------------//

float4x4 world_view_proj_matrix : WorldViewProjection;
float4x4 world_view_trans_matrix : WorldViewTranspose;
static float3 billboard_vec_x = normalize(world_view_trans_matrix[0].xyz);
static float3 billboard_vec_y = normalize(world_view_trans_matrix[1].xyz);

float time_0_X : Time;
float particleSystemShape
<
   string UIName = "particleSystemShape";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 2.00;
> = float( 0.0 );
float particleSpread
<
   string UIName = "particleSpread";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 50.00;
> = float( 50.00 );
float particleSpeed
<
   string UIName = "particleSpeed";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 2.00;
> = float( 0.02 );
float particleSystemHeight
<
   string UIName = "particleSystemHeight";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 160.00;
> = float( 80.00 );
float particleSize
<
   string UIName = "particleSize";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 20.00;
> = float( 0.50 );

// 透過情報Tr取得：苦肉の策（本当はどう取得すべきなのでしょうか・・・）
float Tr : CONTROLOBJECT < string name = "FireParticleSystem_SnowCrystal.x"; string item = "Tr"; >;

// The model for the particle system consists of a hundred quads.
// These quads are simple (-1,-1) to (1,1) quads where each quad
// has a z ranging from 0 to 1. The z will be used to differenciate
// between different particles

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float3 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
};

VS_OUTPUT FireParticleSystem_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;

   // Loop particles
   float t = frac(Pos.z + particleSpeed * time_0_X);
   // Determine the shape of the system
   float s = pow(t, particleSystemShape);

   float3 pos;

   // Spread particles in a semi-random fashion
   float s1 = time_0_X + 3.14159265 * 2 * Pos.z;
   float s4 = abs(cos(s1));

   pos.x = particleSpread * s * cos(62 * Pos.z);
   pos.z = particleSpread * s * sin(163 * Pos.z);
   // Particles goes up
   pos.y = 60 - particleSystemHeight * t;

   // Billboard the quads.
   // The view matrix gives us our right and up vectors.
   //pos += particleSize * (Pos.x * view_trans_matrix[0] + Pos.y * view_trans_matrix[1]);
   pos += particleSize * (Pos.x * billboard_vec_x * s4 + Pos.y * billboard_vec_y);
   pos /= 10;
   
   Out.Pos = mul(float4(pos, 1), world_view_proj_matrix);
   Out.texCoord = Pos.xyz;
   Out.color = 1 - t;
   
   return Out;
}


float particleShape
<
   string UIName = "particleShape";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 0.1 );
texture Flame_Tex
<
   string ResourceName = "SnowCrystal.tga";
>;
sampler Flame = sampler_state
{
   Texture = (Flame_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
float4 FireParticleSystem_Pixel_Shader_main(float3 texCoord: TEXCOORD0, float color: TEXCOORD1) : COLOR {
   // Fade the particle to a circular shape
   float fade = pow(dot(texCoord.xy, texCoord.xy), particleShape);
//   return color *tex2D(Flame, float2(1+(texCoord.x-1)/200-texCoord.z, -texCoord.y*0.5+0.5));
   return Tr * Tr * color * tex2D(Flame, float2(1+(texCoord.x-1)/200-texCoord.z, -texCoord.y*0.5+0.5));

//   return color * tex2D(Flame, float2(color,0.5f));
}


//--------------------------------------------------------------//
// Technique Section for Effect Workspace.Particle Effects.FireParticleSystem
//--------------------------------------------------------------//
technique FireParticleSystem_fish
{
   pass ParticleSystem
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND = ONE;
      DESTBLEND = ONE;

      VertexShader = compile vs_1_1 FireParticleSystem_Vertex_Shader_main();
      PixelShader = compile ps_2_0 FireParticleSystem_Pixel_Shader_main();
   }

}

