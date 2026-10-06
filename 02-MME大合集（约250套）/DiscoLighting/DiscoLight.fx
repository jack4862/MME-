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
// DiscoLighting
//--------------------------------------------------------------//
//--------------------------------------------------------------//
// Light
//--------------------------------------------------------------//

float4x4 world_view_proj_matrix : WorldViewProjection;

float BallTime : TIME;
float3x3 CalcRotateMatrix(float time) {
   float cosX,sinX;
   float cosY,sinY;
   float cosZ,sinZ;

   sincos(0.48 * time,sinX,cosX);
   sincos(0.42 * time,sinY,cosY);
   sincos(0.45 * time,sinZ,cosZ);

   return float3x3(
      cosY * cosZ + sinX * sinY * sinZ,  cosY * sinZ - sinX * sinY * cosZ, cosX * sinY,
     -cosX * sinZ,                       cosX * cosZ,                      sinX, 
      sinX * cosY * sinZ - sinY * cosZ, -sinY * sinZ - sinX * cosY * cosZ, cosX * cosY
   );
}
static float3x3 BallRotateMatrix = CalcRotateMatrix(BallTime);


struct VS_OUTPUT 
{
   float4 Pos: POSITION;
   float3 dir: TEXCOORD0;
};

VS_OUTPUT DiscoLighting_Vertex_Shader_main(float4 Pos: POSITION)
{
   VS_OUTPUT Out;

   float3 dir = normalize(Pos.xyz);
   Pos.xyz /= 100;
   
   Out.Pos = mul(Pos, world_view_proj_matrix);
   
   Out.dir = mul(dir, BallRotateMatrix);

   return Out;
}



shared textureCUBE LightCube_Tex
<
   string ResourceName = "LightCube.dds";
>;
samplerCUBE LightCube = sampler_state
{
   Texture = (LightCube_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
float4 DiscoLighting_Pixel_Shader_main(float3 dir: TEXCOORD0) : COLOR 
{
   return texCUBE(LightCube, dir);
}



//--------------------------------------------------------------//
// Technique Section for DiscoLighting
//--------------------------------------------------------------//
technique DiscoLighting
{
   pass Light
   {
      VertexShader = compile vs_1_1 DiscoLighting_Vertex_Shader_main();
      PixelShader = compile ps_2_0 DiscoLighting_Pixel_Shader_main();
   }

}

