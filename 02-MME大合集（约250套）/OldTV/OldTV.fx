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
// Simulation Effects
//--------------------------------------------------------------//
//--------------------------------------------------------------//
// OldTV
//--------------------------------------------------------------//

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

texture Image_Tex : RenderColorTarget
<
   float2 ViewPortRatio={1.0,1.0};
   string Format="A8R8G8B8";
>;
texture DepthBuffer : RenderDepthStencilTarget <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 pos: TEXCOORD0;
   float2 img: TEXCOORD1;
};

VS_OUTPUT OldTV_TV_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;

   // Clean up inaccuracies
   Pos.xy = sign(Pos.xy);

   Out.Pos = float4(Pos.xy, 0, 1);
   Out.pos = Pos.xy;
   Out.img.x = 0.5 * (1 + Pos.x);
   Out.img.y = 0.5 * (1 - Pos.y);

   return Out;
}





float distortionFreq
<
   string UIName = "distortionFreq";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 10.00;
> = float( 5.70 );
float distortionScale
<
   string UIName = "distortionScale";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 25.00;
> = float( 3.00 );
float distortionRoll
<
   string UIName = "distortionRoll";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 0.40 );
float interference
<
   string UIName = "interference";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 0.49 );
float frameLimit
<
   string UIName = "frameLimit";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = -1.00;
   float UIMax = 1.00;
> = float( 0.38 );
float frameShape
<
   string UIName = "frameShape";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 2.00;
> = float( 0.34 );
float frameSharpness
<
   string UIName = "frameSharpness";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 40.00;
> = float( 8.40 );
float time_0_X : TIME;
static float sin_time_0_X = sin(time_0_X);
sampler Image = sampler_state
{
   Texture = (Image_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = NONE;
};
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
texture3D Rand_Tex
<
   string ResourceName = "Random3D.dds";
>;
sampler Rand = sampler_state
{
   Texture = (Rand_Tex);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   ADDRESSW = WRAP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = NONE;
};
float4 OldTV_TV_Pixel_Shader_main(float2 pos: TEXCOORD0, float2 img: TEXCOORD1) : COLOR {
   // Define a frame shape
   float f = (1 - pos.x * pos.x) * (1 - pos.y * pos.y);
   float frame = saturate(frameSharpness * (pow(f, frameShape) - frameLimit));

   // Interference ... just a texture filled with rand()
   float rand = tex3D(Rand, float3(1.5 * pos, time_0_X)).r - 0.2;

   // Some signed noise for the distortion effect
   float noisy = tex3D(Noise, float3(0, 0.5 * pos.y, 0.1 * time_0_X)).r - 0.5;

   // Repeat a 1 - x^2 (0 < x < 1) curve and roll it with sinus.
   float dst = frac(pos.y * distortionFreq + distortionRoll * sin_time_0_X);
   dst *= (1 - dst);
   // Make sure distortion is highest in the center of the image
   dst /= 1 + distortionScale * abs(pos.y);

   // ... and finally distort
   img.x += distortionScale * noisy * dst;
   float4 image = tex2D(Image, img);

   // Combine frame, distorted image and interference
   image.rgb += interference * rand;
   image.rgb *= frame;
   image.a = 1;
   return image;
}




//--------------------------------------------------------------//
// Technique Section for Simulation Effects
//--------------------------------------------------------------//
technique OldTV<
    string Script = 
        "RenderColorTarget0=Image_Tex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "ScriptExternal=Color;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=TV;"
    ;
> {
   pass TV < string Script= "Draw=Buffer;"; >
   {
      CULLMODE = NONE;
      AlphaBlendEnable = FALSE;

      VertexShader = compile vs_1_1 OldTV_TV_Vertex_Shader_main();
      PixelShader = compile ps_2_0 OldTV_TV_Pixel_Shader_main();
   }

}

