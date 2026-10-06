//--------------------------------------------------------------//
// bomb
// つくったひと：ロベリア
// つくった日：2010/10/7
// こうしんりれき
// 10/10/9:MMDでどうやって爆発出していいかわからないから適当につくった
//--------------------------------------------------------------//

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
#define BLENDMODE_DEST INVSRCALPHA

//テクスチャ名
texture bomb_Tex
<
   string ResourceName = "bomb.png";
>;

//XYZの大きさ
float SizeX
<
   string UIName = "SizeX";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 1 );
float SizeY
<
   string UIName = "SizeY";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 1 );
float SizeZ
<
   string UIName = "SizeZ";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 1 );
//UVスクロール速度
float UScroll
<
   string UIName = "UScroll";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 10.00;
> = float(0.5);
float VScroll
<
   string UIName = "VScroll";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 10.00;
> = float(0.5);

//--よくわからない人はここから下はさわっちゃだめ--//

float time_0_X : Time;

//彩度計算用定数
const float4 calcY = float4( 0.2989f, 0.5866f, 0.1145f, 0.00f );

float4x4 world_matrix : World;
float4x4 view_proj_matrix : ViewProjection;
float4x4 view_trans_matrix : ViewTranspose;
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
};

VS_OUTPUT bomb_Vertex_Shader_main(float3 Pos: POSITION,float2 texCoord: TEXCOORD0){
   VS_OUTPUT Out;

   float4 pos = float4(Pos,1);

   //XYZの大きさを設定（0.0~1.0)
   pos.x *= SizeX;
   pos.y *= SizeY;
   pos.z *= SizeZ;
   
   float4x4 mat = world_matrix;
   mat[3] = 0;
   
   pos = mul(pos,mat);
   pos += world_matrix[3];
   pos.w = 1.0;
   Out.Pos = mul(pos, view_proj_matrix);
   
   //頂点UV値の計算
   Out.texCoord = texCoord + float2(UScroll,VScroll) * time_0_X;
   
   //ローカルY座標値を返す
   float a = (Pos.y * 0.5 + 0.5);//0~1
   Out.color = ( a - (1-DiffuseColor.a*2));
   return Out;
}
sampler bombTexSampler = sampler_state
{
   //使用するテクスチャ
   Texture = (bomb_Tex);
   //テクスチャ範囲0.0～1.0をオーバーした際の処理
   //WRAP:ループ
   ADDRESSU = WRAP;
   ADDRESSV = WRAP;
   //テクスチャフィルター
   //LINEAR:線形フィルタ
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};
float4 bomb_Pixel_Shader_main(VS_OUTPUT IN) : COLOR {

   float4 col = tex2D(bombTexSampler,IN.texCoord);
   col.a *= IN.color;
   if(col.a > 0.1)
   {
      col.a *= 2;
   }
   
   return col;
}

technique bomb <
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=bomb;"
    ;
> {
  pass bomb
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = CCW;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND=BLENDMODE_SRC;
      DESTBLEND=BLENDMODE_DEST;
      VertexShader = compile vs_3_0 bomb_Vertex_Shader_main();
      PixelShader = compile ps_3_0 bomb_Pixel_Shader_main();
   }
}

