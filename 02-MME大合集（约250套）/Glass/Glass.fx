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
// Glass Effect Group
//--------------------------------------------------------------//
//--------------------------------------------------------------//
// ComplexGlass
//--------------------------------------------------------------//
//--------------------------------------------------------------//
// Object
//--------------------------------------------------------------//

float4x4 world_view_proj_matrix : WorldViewProjection;
float4x4 world_matrix : World;
float4 view_position : Position  < string Object = "Camera"; >;
struct VS_OUTPUT {
   float4 Pos:     POSITION;
   float3 normal:  TEXCOORD0;
   float3 viewVec: TEXCOORD1;
};

VS_OUTPUT ComplexGlass_Vertex_Shader_main(float4 Pos: POSITION, float3 normal: NORMAL){
   VS_OUTPUT Out;

   Out.Pos = mul(Pos, world_view_proj_matrix);
   Out.normal = mul(normal, world_matrix);
   Out.viewVec = view_position - mul(Pos, world_matrix);

   return Out;
}



float refractionScale
<
   string UIName = "refractionScale";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 1.00 );
float rainbowScale
<
   string UIName = "rainbowScale";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 0.20 );
float rainbowSpread
<
   string UIName = "rainbowSpread";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 3.00;
> = float( 0.18 );
float4 baseColor
<
   string UIName = "baseColor";
   string UIWidget = "Color";
   bool UIVisible =  true;
> = float4( 0.72, 0.70, 0.76, 1.00 );
float ambient
<
   string UIName = "ambient";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 0.10 );
float indexOfRefractionRatio
<
   string UIName = "indexOfRefractionRatio";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 2.00;
> = float( 1.14 );
float reflectionScale
<
   string UIName = "reflectionScale";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 1.00 );
textureCUBE Environment_Tex
<
   string ResourceName = "stage.dds";
>;
sampler Environment = sampler_state
{
   Texture = (Environment_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
texture Rainbow_Tex
<
   string ResourceName = "Rainbow.tga";
>;
sampler Rainbow = sampler_state
{
   Texture = (Rainbow_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
float4 ComplexGlass_Pixel_Shader_main(float3 normal: TEXCOORD0, float3 viewVec: TEXCOORD1) : COLOR {
   normal = normalize(normal);
   viewVec = normalize(viewVec);

   // Look up the reflection
   float3 reflVec = reflect(-viewVec, normal);
   float4 reflection = texCUBE(Environment, reflVec.xyz);

   // We'll use Snell's refraction law:
   // n  * sin(theta ) = n  * sin(theta )
   //  i            i     r            r

   // sin(theta )
   //          i
   float cosine = dot(viewVec, normal);
   float sine = sqrt(1 - cosine * cosine);

   // sin(theta )
   //          r
   float sine2 = saturate(indexOfRefractionRatio * sine);
   float cosine2 = sqrt(1 - sine2 * sine2);

   // Out of the sine and cosine of the angle between the
   // refraction vector and the normal we can construct the
   // refraction vector itself given two base vectors.
   // These two base vectors are the negative normal and
   // a tangent vector along the path of the incoming vector
   // relative to the surface.
   float3 x = -normal;
   float3 y = normalize(cross(cross(viewVec, normal), normal));

   // Refraction
   float3 refrVec = x * cosine2 + y * sine2;
   float4 refraction = texCUBE(Environment, refrVec.xyz);

   // Colors refract differently and the difference is more
   // visible the stronger the refraction. We'll fake this
   // effect by adding some rainbowish colors accordingly.
   float4 rainbow = tex1D(Rainbow, pow(cosine, rainbowSpread));

   float4 rain = rainbowScale * rainbow * baseColor;
   float4 refl = reflectionScale * reflection;
   float4 refr = refractionScale * refraction * baseColor;

   // There is more light reflected at sharp angles and less
   // light refracted. There is more color separation of refracted
   // light at sharper angles
   
   return sine * refl + (1 - sine2) * refr + sine2 * rain + ambient;
}


//--------------------------------------------------------------//
// Technique Section for Glass Effect Group
//--------------------------------------------------------------//
technique ComplexGlass
{
   pass Object
   {
      ZENABLE = TRUE;
      CULLMODE = CCW;

      VertexShader = compile vs_1_1 ComplexGlass_Vertex_Shader_main();
      PixelShader = compile ps_2_0 ComplexGlass_Pixel_Shader_main();
   }

}

