
texture MultiMonitorRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for MultiMonitor.fx";
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "MultiMonitor.x = hide;"
        "* = DrawObject.fx;";
>;
sampler MonitorSamp = sampler_state
{
   Texture = (MultiMonitorRT);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR; 
};
//ウィンドウテクスチャ
texture WinTex
<
   string ResourceName = "window.png";
>;
sampler WinSamp = sampler_state {
    texture = <WinTex>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};


float4x4 world_view_proj_matrix : WorldViewProjection;
float4x4 world_view_trans_matrix : WorldViewTranspose;
float4x4 worldMatrix : World;
float4x4 projectionMatrix : PROJECTION;
float4x4 view_proj_matrix : ViewProjection;

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

float fSize = 1.25;
struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
};

//ビューポートサイズ
float2 Viewport : VIEWPORTPIXELSIZE; 

float time_0_X : TIME <bool SyncInEditMode=false;>;
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

VS_OUTPUT MultiMonitor_VS(float4 Pos: POSITION){
   VS_OUTPUT Out;
   Out.Pos = 0;
   Out.texCoord = 0; 

   Out.texCoord = Pos.xy*0.5+0.5;

   float3 pos = 0;
   float2 ViewportRatio = normalize(Viewport);
   
   pos = Pos * 0.25 * fSize;
   pos *= length(worldMatrix[0])*0.1;
   pos.y *= Viewport.x / Viewport.y;
   pos.y *= -1;
   pos.xy *= ViewportRatio;
   
   float4 tgt2D = worldMatrix[3]*0.05;

   pos += tgt2D.xyz;
   pos.z = 0;
   Out.Pos = float4(pos, 1);

   return Out;
}

float4 MultiMonitor_PS(float2 texCoord: TEXCOORD0) : COLOR {
     
   float4 col = 0;
   col = tex2D(MonitorSamp, texCoord);
   col*=tex2D(WinSamp,texCoord);
   col.a *= MaterialDiffuse.a;
   
   return col;
}

technique MultiMonitor
{
   pass mainpass
   {
      ZENABLE = FALSE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND = SRCALPHA;
      DESTBLEND = INVSRCALPHA;

      VertexShader = compile vs_1_1 MultiMonitor_VS();
      PixelShader = compile ps_2_0 MultiMonitor_PS();
   }

}

