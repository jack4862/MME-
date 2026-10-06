// fxSlider.exe で認識できるパラメータ例

//DEFINE HOGE1; UIName="ファイル"; UIWidget="File"; UIHelp="1行で頼む!";
//DEFINE HOGE2; type=int;UIName="選択"; UIWidget="Selector";UISelector="a,b,c";
//DEFINE HOGE3; type=float;UIName="test"; UIWidget="Slider";UIMax=1;UIMin=0;
//DEFINE HOGE4; type=float;UIName="test"; UIWidget="Slider";UIMax=float3(1,1,1);UIMin=float3(0,0,0);


#define	HOGE1	"sample.fx"
#define	HOGE2	2
#define	HOGE3	0.4
#define	HOGE4	float3( 0.13 , 0.9 , 0.34 )

int sample1
<
   string UIName = "sample 1";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   int UIMin = int(1);
   int UIMax = int(2000);
   int UIDefault = int(100);
   string UIHelp = "UIDefaultがあると、初期値に戻すボタンが有効になります。";
> = 100;

float sample2
<
   string UIName = "sample 2";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIStep = 10;
> = 79.4;

float2 sample3
<
   string UIName = "sample 3";
   string UIWidget = "Numeric";
   bool UIVisible =  false;
   float2 UIStep = float2(10,10);
> = float2( 200 , 400 );

int sample4
<
   string UIName = "sample 4";
   string UIWidget = "Selector";
   string UISelector = "選択肢１,選択肢２,選択肢３,選択肢４";
> = 3;

float4 sample5
<
   string UIName = "sample 5";
   string UIWidget = "Color";
> = float4( 0.8 , 0.34 , 0.1 , 1 );

float3 sample6
<
   string UIName = "sample 6";
   string UIWidget = "Slider";
   float3 UIMax = float3(2,3,4);
   float3 UIMin = float3(-2,-3,-4);
   float3 UIDefault = float3(1,1,1);
> = float3( 1.57 , 1 , 1 );

