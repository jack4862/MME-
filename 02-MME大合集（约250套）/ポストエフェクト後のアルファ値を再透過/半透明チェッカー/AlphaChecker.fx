//半透明部分のアルファ値を書き換える設定
//0:そのまま
//1:全画面をアルファ値1(不透明)にする
#define ALPHA_OVERWRITE 0

//市松模様1マスのピクセル数
const float PicsCec = 16;

//市松模様のカラー
const float3 Colot0 = { 1.0, 1.0, 1.0 };
const float3 Colot1 = { 0.75, 0.75, 0.75 };








// ポストエフェクト宣言
float Script : STANDARDSGLOBAL <
   string ScriptOutput = "color";
   string ScriptClass = "scene";
   string ScriptOrder = "postprocess";
> = 0.8;

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
   float2 ViewPortRatio = {1.0,1.0};
   string Format = "D24S8";
>;

float Accessary_X : CONTROLOBJECT <string name="(self)"; string item="X";>;
float Tr          : CONTROLOBJECT <string name="(self)"; string item="Tr";>;
float Scaling     : CONTROLOBJECT < string name = "(self)"; >;
float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = float2(0.5,0.5)/ViewportSize;

////////////////////////////////////////////////////////////////
// オリジナル画像
// 処理用テクスチャ
texture OrgScreen : RENDERCOLORTARGET <
   string Format = "A8R8G8B8";
   float2 ViewPortRatio = {1.0,1.0};
>;
sampler OrgSampler = sampler_state {
   texture = <OrgScreen>;
   MinFilter = POINT;
   MagFilter = POINT;
   AddressU  = CLAMP;
   AddressV  = CLAMP;
};


/////////////////////////////
// コピー用のシェーダ
struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 Tex: TEXCOORD0;
};

VS_OUTPUT CopyVS(float4 Pos : POSITION, float2 Tex : TEXCOORD0 ){ 
   VS_OUTPUT Out;
   Out.Pos = Pos;
   Out.Tex = Tex + ViewportOffset;
   return Out;
}

/////////////////////////////
// 合成用のシェーダ
float4 MixPS(float2 Tex: TEXCOORD0) : COLOR {
   float4 org = tex2D(OrgSampler, Tex);
   
   float checkerFlag = frac( ( trunc( Tex.x * ViewportSize.x / (PicsCec*Scaling*0.1) ) + trunc( Tex.y * ViewportSize.y / (PicsCec*Scaling*0.1) ) ) / (2.0f) );
   
   float3 checkerColor = checkerFlag<0.5 ? Colot0 : Colot1;
   
   float alphaFlag = org.a < Tr;
   
   float alpha = Accessary_X > 0.9 ? 1 : org.a;
   
   float4 outputcolor = alphaFlag ? float4(checkerColor,alpha) : float4(org.rgb,alpha);
   
  return outputcolor;
}


////////////////////////////////////////////////////////////////
// エフェクトテクニック
//
float4 ClearColor = { 0, 0, 0, 0 };
float ClearDepth  = 1;

technique PostEffectTec <
   string Script =
      "RenderColorTarget=OrgScreen;"
      "RenderDepthStencilTarget=DepthBuffer;"
         "ClearSetColor=ClearColor;"
         "ClearSetDepth=ClearDepth;"
         "Clear=Color;"
         "Clear=Depth;"
         "ScriptExternal=Color;"

      "RenderColorTarget=;"
      "RenderDepthStencilTarget=;"
         "ClearSetColor=ClearColor;"
         "ClearSetDepth=ClearDepth;"
         "Clear=Color;"
         "Clear=Depth;"
         "Pass=PassMix;"
   ;
>{
   pass PassMix < string Script = "Draw=Buffer;"; >{
      AlphaBlendEnable = false;
      AlphaTestEnable  = false;
      VertexShader = compile vs_2_0 CopyVS();
      PixelShader  = compile ps_2_0 MixPS();
   }
};
