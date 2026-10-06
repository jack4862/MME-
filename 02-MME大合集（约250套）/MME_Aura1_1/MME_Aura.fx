//MME_Aura ver1.1
//つくったひと：ロベリア（ビームマンP）


//合成方法の設定
//
//半透明合成：
//BLENDMODE_SRC SRCALPHA
//BLENDMODE_DEST INVSRCALPHA
//
//加算合成：
//
//BLENDMODE_SRC SRCALPHA
//BLENDMODE_DEST ONE

#define BLENDMODE_SRC SRCALPHA
#define BLENDMODE_DEST ONE

//テクスチャ名
texture Aura_Tex1
<
   string ResourceName = "MME_Aura_tex1.png";
>;
texture Aura_Tex2
<
   string ResourceName = "MME_Aura_tex2.png";
>;

//外周サイズ（MMD上のSi×大きさ＝表示される大きさ）
float OutSize
<
   string UIName = "OutSize";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = -100.0;
   float UIMax = 100.0;
> = float( 1 );
//内周サイズ（外周に対しての割合　0～1）
float InSize
<
   string UIName = "InRatio";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = -100.0;
   float UIMax = 100.0;
> = float( 1 );
//高さ
float Height
<
   string UIName = "Height";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = -100.0;
   float UIMax = 100.0;
> = float( 1 );

//分割角度（360で全周囲）
float SpritRot
<
   string UIName = "SpritRot";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 360.0;
> = float( 360 );

//テクスチャスクロール速度
float ScrollSpd
<
   string UIName = "UScroll";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = -10.00;
> = float( 0.1 );

//テクスチャ繰り返し数
float ScrollNum
<
   string UIName = "UWrapNum";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 0.0;
   int UIMax = 100.0;
> = float( 2 );

//色設定
float4 Color
<
	string UIName = "Color";
	string UIWidget = "Color";
	bool UIVisible = true;
	float UIMin = 0.0;
	float UIMax = 1.0;
> = float4( 0.00, 0.00, 1.00, 1.0 );

//明るさ
float Brightness
<
   string UIName = "Brightness";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 0.0;
   int UIMax = 1.0;
> = float( 1 );

//初期透明度
float DefAlpha
<
   string UIName = "DefAlpha";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 1 );

//エフェクトタイプ
#define AURA_WAVE	0
#define AURA_DISC	1
#define AURA_EX		2
#define AURA_NOTYPE 3
int EffectType
<
   string UIName = "EffectType";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 0;
   int UIMax = 1;
> = int(1);

//--よくわからない人はここから下はさわっちゃだめ--//

float time_0_X : Time;
//πの値
#define PI 3.1415
//角度をラジアン値に変換
#define RAD(x) ((x * PI) / 180.0)

float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
};

VS_OUTPUT lineSystem_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;

   Out.texCoord.y = (Pos.x + 1)/2 - 0.001;
   Out.texCoord.x = Pos.z * ScrollNum;
      
   //Z値（0～１）から角度を計算し、ラジアン値に変換する
   float rad = RAD(Pos.z * SpritRot);
   
   //--xz座標上に配置する
   
   //xがマイナス=外周
   if(Pos.x < 0)
   {
   		Out.Pos.x = cos(rad) * OutSize;	
   		Out.Pos.z = sin(rad) * OutSize;
   		//y値は高さパラメータそのまま
   		//WAVEの場合はTR値によって高さ変化
   		float w = Height;
	    if(EffectType == AURA_WAVE || EffectType == AURA_EX)
		    w = lerp(0,Height,DiffuseColor.a);
   		Out.Pos.y = w;
   }else{
	   //内周
	   //DISCの場合はTR値によって内周変化
	    float w = InSize;
	    if(EffectType == AURA_DISC || EffectType == AURA_EX)
		    w = lerp(OutSize,InSize,DiffuseColor.a);
   		Out.Pos.x = cos(rad) * w;		   
   		Out.Pos.z = sin(rad) * w;
   		Out.Pos.y = 0;
   } 
   
   Out.Pos.w = 1;   
   Out.Pos = mul(Out.Pos, WorldViewProjMatrix);
   Out.color = (time_0_X * ScrollSpd) % 1.0;

   return Out;
}

//テクスチャの設定
sampler AuraTex1Sampler = sampler_state
{
   //使用するテクスチャ
   Texture = (Aura_Tex1);
   //テクスチャ範囲0.0～1.0をオーバーした際の処理
   //WRAP:ループ
   ADDRESSU = WRAP;
   ADDRESSV = CLAMP;
   //テクスチャフィルター
   //LINEAR:線形フィルタ
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
//テクスチャの設定
sampler AuraTex2Sampler = sampler_state
{
   //使用するテクスチャ
   Texture = (Aura_Tex2);
   //テクスチャ範囲0.0～1.0をオーバーした際の処理
   //WRAP:ループ
   ADDRESSU = WRAP;
   ADDRESSV = CLAMP;
   //テクスチャフィルター
   //LINEAR:線形フィルタ
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
//ピクセルシェーダ

//彩度計算用
const float4 calcY = float4( 0.2989f, 0.5866f, 0.1145f, 0.00f );

float4 lineSystem_Pixel_Shader_main(float2 texCoord: TEXCOORD0,float color: TEXCOORD1) : COLOR {
   //入力されたテクスチャ座標に従って色を選択する
   
   float2 add = float2(color,0);
   float4 col = float4(tex2D(AuraTex1Sampler,texCoord + add));
   add.x += 0.1;
   float4 col2 = float4(tex2D(AuraTex2Sampler,texCoord - add));
   
   float4 c = col * col2;
   
   float r = c * calcY;
   r *= Brightness;

   c *= Color + r;

   c.a = max(col.a,col2.a) * DiffuseColor.a * DefAlpha;
   
   return c;
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
      VertexShader = compile vs_2_0 lineSystem_Vertex_Shader_main();
      PixelShader = compile ps_2_0 lineSystem_Pixel_Shader_main();
   }
}

