//--------------------------------------------------------------//
// lineSystem
// つくったひと：ロベリア
// ベースにしたシェーダ―：LineSystem
// つくった日：2010/10/9
// こうしんりれき
// 10/10/9:つくった
//--------------------------------------------------------------//

//ラインの長さ（0～100の範囲で指定）
#define LINE_LENGTH 100

//ビルボードフラグ（ワールド回転追随との併用不可。ビルボードが優先される）
#define BILLBORAD true
//ワールド回転追随フラグ（追随するオブジェの回転に合わせる。サイズが大きい、オブジェの回転角度が急だと非常によくない感じになる)
#define WORLD_ROTATE true
//角度（0～360推奨）
#define ROTATE 0

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
texture Line_Tex
<
   string ResourceName = "Line.png";
>;
//速度
float Spd
<
   string UIName = "Spd";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1000.00;
> = float( 2.0 );
//回転速度(0.0:まがらない 1.0:常に目標の方を向く）
float RotSpec
<
   string UIName = "RotSpec";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 100.00;
> = float( 0.01 );

//ラインの太さ（MMD上で設定した太さ×ここで設定した太さ＝表示される太さ）
float lineSize
<
   string UIName = "lineSize";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 20.00;
> = float( 5 );
//UVスクロール速度
float UScroll
<
   string UIName = "UScroll";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 10.00;
> = float(0);
float VScroll
<
   string UIName = "VScroll";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 10.00;
> = float(0);

//UV繰り返し数
float UWrapNum
<
   string UIName = "UWrapNum";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 0.0;
   int UIMax = 100.0;
> = float(1);
float VWrapNum
<
   string UIName = "VWrapNum";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 0.0;
   int UIMax = 100.0;
> = float(1);

//--よくわからない人はここから下はさわっちゃだめ--//
float3 TgtPos : CONTROLOBJECT < string name = "tgt.x"; >;

float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);

float time_0_X : TIME <bool SyncInEditMode=true;>;
// Xファイルと連動しているので、変更不可
#define PARTICLE_COUNT  100
// 位置記録用テクスチャのサイズ  (TEX_WIDTH*TEX_HEIGHT==PARTICLE_COUNT)
#define TEX_WIDTH  10
#define TEX_HEIGHT  10
//πの値
#define PI 3.1415
//角度をラジアン値に変換
#define RAD ((ROTATE * PI) / 180.0)

float4x4 world_matrix : World;
float4x4 view_proj_matrix : ViewProjection;
float4x4 view_trans_matrix : ViewTranspose;
texture DepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
    string Format = "D24S8";
>;
//座標を保存するテクスチャ
texture WorldTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
//進行ベクトルを保存するテクスチャ
texture VecTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler WorldTex_Samp = sampler_state
{
   Texture = (WorldTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler VecTex_Samp = sampler_state
{
   Texture = (VecTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float color: TEXCOORD1;
};

VS_OUTPUT lineSystem_Vertex_Shader_main(float4 Pos: POSITION){
   VS_OUTPUT Out;

   int idx = round(Pos.z*PARTICLE_COUNT);
   //IDが規定の長さより長かったら最大値に固定
   if(idx >= LINE_LENGTH)
   {
		idx = LINE_LENGTH;
   }
   //現在の座標を取得
   float2 base_tex_coord = float2( float(idx%TEX_WIDTH)/TEX_WIDTH + 0.05, float(idx/TEX_WIDTH)/TEX_HEIGHT + 0.05);
   float4 base_pos = tex2Dlod(WorldTex_Samp, float4(base_tex_coord,0,1));
   float4 base_vec = tex2Dlod(VecTex_Samp, float4(base_tex_coord,0,1));
   float3 pos = Pos;
   pos.z = 0;      

   float4 rspos = 0;
   if(BILLBORAD)
   {
	   //ラインのビルボード化
	   float3 vec = base_vec.xyz;

		//カメラからのベクトル
		float3 eyevec = normalize(view_trans_matrix[2].xyz);

		//進行ベクトルとカメラベクトルの外積で横方向を得る
		float3 side = normalize(cross(vec,eyevec));

		//横幅に合わせて拡大
		side *= lineSize/16;

		//ワールド拡大率に合わせて拡大（横だけ
		side *= length(world_matrix[0]);

		//入力座標のX値でローカルな左右判定
		if(Pos.x > 0)
		{
		    //左側
		    rspos += float4(side,0);
		}else{
		    //右側
		    rspos -= float4(side,0);
		}
	   
	   rspos = mul(rspos,length(world_matrix[0]));
   }else{
	   pos *= lineSize;
       rspos = float4(pos,0);
	   //非ビルボードライン処理
	   //ローカル回転処理
	   //回転行列の作成
	   float4x4 matRot;
	   matRot[0] = float4(cos(RAD),sin(RAD),0,0); 
	   matRot[1] = float4(-sin(RAD),cos(RAD),0,0); 
	   matRot[2] = float4(0,0,1,0); 
	   matRot[3] = float4(0,0,0,1); 
	   rspos = mul(rspos,matRot);
   }
   pos.x = rspos.x;
   pos.y = rspos.y;
   pos.z = rspos.z;
   

   pos += base_pos;
   
   
   Out.Pos = mul(float4(pos, 1), view_proj_matrix);
   
   //頂点UV値の計算
   Out.texCoord.x = (Pos.z * ((float)PARTICLE_COUNT/(float)LINE_LENGTH)) * UWrapNum;
   Out.texCoord.y = ((Pos.x + Pos.y) + 0.5) * -VWrapNum;
   //UVスクロール
   Out.texCoord.x += float2(UScroll,VScroll) * time_0_X;
   Out.color = 1;

   return Out;
}
sampler LineTexSampler = sampler_state
{
   //使用するテクスチャ
   Texture = (Line_Tex);
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
float4 lineSystem_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   return float4(tex2D(LineTexSampler,texCoord));
}

struct VS_OUTPUT2 {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
};

VS_OUTPUT2 WorldBase_Vertex_Shader_main(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex ;
   return Out;
}
//座標をテクスチャに保存
float4 WorldTex_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {

   //Trないしtimeが0（誤差を考えて若干大目に取ってある）の時は常に原点の座標を返す
   if(DiffuseColor.a <= 0.01 || time_0_X <= 0.01)
   {
   		return world_matrix[3];
   }else{
	   float2 texWork = texCoord;
	   int idx = round(texWork.x*TEX_WIDTH)+round(texWork.y*TEX_HEIGHT)*TEX_WIDTH;
	   if(idx == 0)
	   {
	        float2 now_tex_coord = float2(0 + 0.05, 0 + 0.05);
	   		//現在座標
	        float4 now_pos = tex2D(WorldTex_Samp, float4(now_tex_coord,0,1));
	   		//現在ベクトル
	        float3 now_vec = normalize(tex2D(VecTex_Samp, float4(now_tex_coord,0,1)));

	   		now_pos += float4(now_vec,0) * Spd;
	   
	   		return float4(now_pos.xyz,0);
	   }else{
		   idx-=1;
		   float4 prev;
		   float2 base_tex_coord = float2( float(idx%TEX_WIDTH)/(float)TEX_WIDTH + 0.05, float(idx/TEX_WIDTH)/(float)TEX_HEIGHT + 0.05);
	       prev = tex2D(WorldTex_Samp, base_tex_coord);
	   	   return prev;
	   }
	}
}
//ベクトルをテクスチャに保存
float4 VecTex_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {

   //Trないしtimeが0（誤差を考えて若干大目に取ってある）の時は常に原点のベクトルを返す
   if(DiffuseColor.a <= 0.01 || time_0_X <= 0.01)
   {
   		return -normalize(world_matrix[2]);
   }else{
	   float2 texWork = texCoord;
	   int idx = round(texWork.x*TEX_WIDTH)+round(texWork.y*TEX_HEIGHT)*TEX_WIDTH;
	   if(idx == 0)
	   {
	        float2 now_tex_coord = float2(0 + 0.05, 0 + 0.05);
	   		//現在座標
	        float4 now_pos = tex2D(WorldTex_Samp, float4(now_tex_coord,0,1));
	   		//現在ベクトル
	        float3 now_vec = normalize(tex2D(VecTex_Samp, float4(now_tex_coord,0,1)));

			//目標座標へのベクトル
	   		float3 tgt_vec = normalize(TgtPos - now_pos);
	   
	   		//目標ベクトルと現在ベクトルを線形補完で近づける
	   		now_vec = lerp(now_vec,tgt_vec,RotSpec);
	   
	   		return float4(now_vec,0);
	   }else{
		   idx-=1;
		   float4 prev;
		   float2 base_tex_coord = float2( float(idx%TEX_WIDTH)/(float)TEX_WIDTH + 0.05, float(idx/TEX_WIDTH)/(float)TEX_HEIGHT + 0.05);
	       prev = tex2D(VecTex_Samp, base_tex_coord);
	   	   return prev;
	   }
	}
}


technique lineSystem <
    string Script = 
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "RenderColorTarget0=VecTex;"
	    "Pass=VecTex;"
	    "RenderColorTarget0=WorldTex;"
	    "Pass=WorldTex;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=lineSystem;"
    ;
> {
	pass VecTex < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_1_1 WorldBase_Vertex_Shader_main();
	    PixelShader = compile ps_2_0 VecTex_Pixel_Shader_main();
	}
	pass WorldTex < string Script = "Draw=Buffer;";>
	{
	    ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
	    VertexShader = compile vs_1_1 WorldBase_Vertex_Shader_main();
	    PixelShader = compile ps_2_0 WorldTex_Pixel_Shader_main();
	}
   pass lineSystem
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      ALPHABLENDENABLE = TRUE;
      SRCBLEND=BLENDMODE_SRC;
      DESTBLEND=BLENDMODE_DEST;
      VertexShader = compile vs_3_0 lineSystem_Vertex_Shader_main();
      PixelShader = compile ps_3_0 lineSystem_Pixel_Shader_main();
   }
}

