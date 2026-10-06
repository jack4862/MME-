//--------------------------------------------------------------//
// 集中線エフェクト
// つくったひと：ロベリア
//--------------------------------------------------------------//

float4x4 world_view_proj_matrix : WorldViewProjection;
float4x4 world_view_trans_matrix : WorldViewTranspose;
static float3 billboard_vec_x = normalize(world_view_trans_matrix[0].xyz);
static float3 billboard_vec_y = normalize(world_view_trans_matrix[1].xyz);

float4x4 worldMatrix : World;
float4x4 projectionMatrix : PROJECTION;
float4x4 view_proj_matrix : ViewProjection;

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
};

//ビューポートサイズ
float2 Viewport : VIEWPORTPIXELSIZE; 

//πの値
#define PI 3.1415
//角度をラジアン値に変換
#define RAD(x) ((x * PI) / 180.0)

float4 toProj(float3 tgtpos)
{
	// VP変換
	float4 tgt = mul(float4(tgtpos,1), view_proj_matrix);
	tgt.x /= tgt.w;
	tgt.y /= tgt.w;
	tgt.z /= tgt.w;
		
	return tgt;
}

float time_0_X : TIME <bool SyncInEditMode=false;>;
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

VS_OUTPUT SaturatedLine_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out = (VS_OUTPUT)0;
   Out.Pos.w = 1;
   float3 pos = 0;
   pos = Pos;
   
   pos.y *= Viewport.x / Viewport.y;
   pos.y *= -1;
   
   pos *= length(worldMatrix[0])*0.1;
   float3 TgtPos = worldMatrix[3];
   
   //光源の位置を2Dに変換
   float4 tgt2D = toProj(TgtPos);
   
   if(tgt2D.w < 0)
   {
   		return Out;
   }
   pos += tgt2D.xyz;
   
   pos.z = 0;
   Out.Pos = float4(pos, 1);

   Out.texCoord = ((Pos.xy + 1.0) * 0.5);
   return Out;
}
texture Tex
<
   string ResourceName = "tex.png";
>;
sampler TexSamp = sampler_state
{
   Texture = (Tex);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   Filter = LINEAR; 
};
float4 SaturatedLine_Pixel_Shader_main(float2 texCoord: TEXCOORD0,float usemain: TEXCOORD1, float color: TEXCOORD2) : COLOR {
     
   float4 col = 0;
   col = tex2D(TexSamp, texCoord);   
   col.a = (1-(col.g+(1-MaterialDiffuse.a)))*(1-col.b);
   col.rgb = col.r;
   
   return col;
}

technique SaturatedLine
{
   pass SaturatedLine
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND = SRCALPHA;
      DESTBLEND = INVSRCALPHA;

      VertexShader = compile vs_2_0 SaturatedLine_Vertex_Shader_main();
      PixelShader = compile ps_2_0 SaturatedLine_Pixel_Shader_main();
   }

}

