//スクロール速度
float2 ScrollSpd
<
   string UIName = "ScrollSpd";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float2 UIMin = -1;
   float2 UIMax = 1;
> = float2( 0.1, 0 );
//雲全体の量（厚み？） 0～1
float CloudVolume
<
   string UIName = "CloudVolume";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 1;
> = float( 0.5 );
//雲の色
float3 CloudColor
<
   string UIName = "CloudColor";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float3 UIMin = 0;
   float3 UIMax = 1;
> = float4( 1.00, 1.00, 1.00, 1.0 );
//初期サイズ
float Scale
<
   string UIName = "Scale";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 100000;
> = float( 30000 );

//テクスチャループ数
int TexLoop
<
   string UIName = "TexLoop";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 0;
   int UIMax = 50;
> = int( 30 );

//初期スクロール値
float FirstScroll
<
   string UIName = "FirstScroll";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 1;
> = float( 0 );

#define BLENDMODE_SRC SRCALPHA
#define BLENDMODE_DEST INVSRCALPHA

//--よくわからない人はここから下はさわっちゃだめ--//

float time_0_X : Time;
float4x4 wvpmat : WorldViewProjection;

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);

texture SkyTex_s
<
   string ResourceName = "CloudMain.png";
>;
sampler SkyTex_s_Sampler = sampler_state
{
   Texture = (SkyTex_s);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   Filter = LINEAR;
};
texture SkyTex_m
<
   string ResourceName = "CloudSub1.png";
>;
sampler SkyTex_m_Sampler = sampler_state
{
   Texture = (SkyTex_m);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   Filter = LINEAR;
};
texture SkyTex_l
<
   string ResourceName = "CloudSub2.png";
>;
sampler SkyTex_l_Sampler = sampler_state
{
   Texture = (SkyTex_l);
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   Filter = LINEAR;
};

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
};

VS_OUTPUT SkyDome_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;

   Out.texCoord = (Pos.xz*0.5 + 0.5) * (TexLoop+1);

   //変換済みフラグをオフ
   Pos.w = 0;
   //初期サイズに拡大
   Pos *= Scale;
   //変換済みフラグをオン
   Pos.w = 1;
   Out.Pos = mul(Pos, wvpmat);

   return Out;
}
//ピクセルシェーダ
float4 SkyDome_Pixel_Shader_main(float2 texCoord: TEXCOORD0,float color: TEXCOORD1) : COLOR {
   
   float2 add = ScrollSpd * (time_0_X + FirstScroll);
   
   float4 col_s = tex2D(SkyTex_s_Sampler,texCoord + add);
   float4 col_m = tex2D(SkyTex_m_Sampler,texCoord + add*0.75);
   float4 col_l = tex2D(SkyTex_l_Sampler,texCoord + add*0.5);
   
   float4 col = col_s + col_m + col_l;
   float a = col.r*(1-CloudVolume);
   col.a = min(1,((1-a)));
   if(CloudVolume < 0.1)
   {
   		col.a *= (CloudVolume * 10);
   }
   col.rgb = CloudColor;
   
   
   return col;
}

//テクニックの定義
technique lineSystem <
    string Script = 
		//描画対象をメイン画面に
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    //パスの選択
	    "Pass=lineSystem;"
    ;
> {
   //メインパス
   pass lineSystem
   {
      //Z値の考慮：する
      ZENABLE = TRUE;
      //Z値の描画：しない
      ZWRITEENABLE = FALSE;
      //カリングオフ（両面描画
      CULLMODE = NONE;
      //αブレンドを使用する
      ALPHABLENDENABLE = TRUE;
      //αブレンドの設定（詳しくは最初の定数を参照）
      SRCBLEND=BLENDMODE_SRC;
      DESTBLEND=BLENDMODE_DEST;
      //使用するシェーダを設定
      VertexShader = compile vs_2_0 SkyDome_Vertex_Shader_main();
      PixelShader = compile ps_2_0 SkyDome_Pixel_Shader_main();
   }
}

