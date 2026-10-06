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
// Various Wood Shaders
//--------------------------------------------------------------//
//--------------------------------------------------------------//
// Wood0
//--------------------------------------------------------------//
//--------------------------------------------------------------//
// Single Pass
//--------------------------------------------------------------//

float4x4 world_view_proj_matrix : WorldViewProjection;
float4x4 world_view_matrix : WorldView;
float4x4 view_matrix : View;

float scale
<
   string UIName = "scale";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 0.10;
> = float( 0.3 );
struct VS_OUTPUT {
   float4 Pos:     POSITION;
   float3 pos:     TEXCOORD0;
   float3 normal:  TEXCOORD1;
   float3 viewVec: TEXCOORD2;
};

VS_OUTPUT Wood0_Vertex_Shader_main(float4 Pos: POSITION, float3 normal: NORMAL){
   VS_OUTPUT Out;

   Out.Pos = mul(Pos, world_view_proj_matrix);
   // Pass position to fragment shader
   Out.pos = scale * Pos;
   // Eye-space lighting
   Out.normal = mul(normal, world_view_matrix);
   Out.viewVec = -mul(Pos, world_view_matrix);

   return Out;
}


float Kd
<
   string UIName = "Kd";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 0.89 );
float Ks
<
   string UIName = "Ks";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 0.66 );
float4 darkWood
<
   string UIName = "darkWood";
   string UIWidget = "Color";
   bool UIVisible =  true;
> = float4( 0.44, 0.21, 0.00, 1.00 );
float4 liteWood
<
   string UIName = "liteWood";
   string UIWidget = "Color";
   bool UIVisible =  true;
> = float4( 0.92, 0.50, 0.13, 1.00 );
float frequency
<
   string UIName = "frequency";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 16.00;
> = float( 6.72 );
float noiseScale
<
   string UIName = "noiseScale";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 2.00;
> = float( 0.96 );
float ringScale
<
   string UIName = "ringScale";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 4.00;
> = float( 2.20 );

float3 lightDirW : Direction < string Object = "Light"; >;
static float4 lightDir = -mul(lightDirW, view_matrix);

texture3D Noise_Tex
<
   string ResourceName = "NoiseVolume.dds";
>;
sampler Noise = sampler_state
{
   Texture = (Noise_Tex);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   ADDRESSW = WRAP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
float4 Wood0_Pixel_Shader_main(float3 pos: TEXCOORD0, float3 normal: TEXCOORD1, float3 viewVec: TEXCOORD2) : COLOR {
   // Signed noise
   float snoise = 2 * tex3D(Noise, pos).r - 1;

   // Rings will go along x axis, perturbed with some noise
   float ring = frac(frequency * pos.x + noiseScale * snoise);
   // Map [0,1] to 0->1->0 with 4(x-x^2)
   ring *= 4 * (1 - ring);

   // Adjust ring smoothness and shape, and add some noise
   float lrp = pow(ring, ringScale) + snoise;
   float4 base = lerp(darkWood, liteWood, lrp);

   normal = normalize(normal);
   // Soft diffuse
   float diffuse = 0.5 + 0.5 * max(0,dot(lightDir, normal));
   // Standard specular
   float specular = pow(saturate(dot(reflect(-normalize(viewVec), normal), lightDir)), 12);
   
   float4 color = base;
   color.rgb *= Kd * diffuse;
   color.rgb += Ks * specular;
   return color;
}


//--------------------------------------------------------------//
// Technique Section for Various Wood Shaders
//--------------------------------------------------------------//
technique Wood0
{
   pass Single_Pass
   {
      VertexShader = compile vs_1_1 Wood0_Vertex_Shader_main();
      PixelShader = compile ps_2_0 Wood0_Pixel_Shader_main();
   }

}

