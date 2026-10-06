///////////////////////////////////////////////////////////////////////////////////////
//
//	名前	視点移動エフェクト ver0.2
//	対応	MikuMikuEffect ver0.2x用
//	作成者	kion
//	更新日	2011.01.02
//
///////////////////////////////////////////////////////////////////////////////////////
MikuMikuEffect ver0.2x で使用可能なエフェクトファイル(*.fx)です。
MMDver7.25 + MMEver0.23で動作確認済み

視点を移動するエフェクト。
平滑化機能付き。


●MikuMikuEffectについて
舞力介入Pにより作られたMikuMikuDanceでエフェクトファイルを使用可能にするツールです。
詳しくは→http://www.nicovideo.jp/watch/sm12149815


●ファイル内容
Readme.txt	／このファイル
CameraFull.x	／CameraFull.fx読み込み用アクセサリ
CameraFull.fx	／エフェクトファイル本体
CameraSmooth.x	／CameraSmooth.fx読み込み用アクセサリ
CameraSmooth.fx	／視点の行列を計算、および平滑化
CameraMove.x	／CameraMove.fx読み込み用アクセサリ
CameraMove.fx	／移動用座標と姿勢を計算
Camera1.fx	／視点を変更してオブジェクトを描画する
Cam1Pos.x	／カメラ位置とを設定するアクセサリ

CenterControl.x	／前進後退コントロール
LeftControl.x	／左旋回と上昇下降
RightControl.x	／右旋回と上昇下降

non.fx		／GPU負荷低減参照

CameraMove.fxによって判定と移動。
Camera1.fxによってオブジェクトを別の視点に変更して描画します。
Cam1Pos.xの名前を変更するとCameraSmooth.fxとCamera1.fxで情報が取得できなくなるので変更しないでください。


●仕組み
コントロール用アクセサリをボーンに付けて、そのアクセサリ位置で判定を行います。
CameraMove.fxでアクセサリ位置を取得、判定を行い、位置と姿勢を更新。テクスチャに書き込み。
さらに、CameraSmooth.fxでビュー行列を計算、平滑化処理をしてテクスチャに書き出す。
Camera1.fx内で上のテクスチャを読み込み、視点を変更して描画。
CameraFull.fxでCamera1.fxを使ってオフスクリーンバッファに描画した内容を出力しています。
平滑化は平均をとる方法になっているため、少し遅延があります。


●使い方
以下のファイルを読み込む。
・CameraFull.x
・CameraMove.x
・CameraSmooth.x
・Cam1Pos.x
Cam1Pos.xがカメラ位置、青い面の向いてる方向がカメラの視線方向になります。
Cam1Pos.xのサイズ(Si)に視野角を度数で指定します。初期状態は1なので、45や60など適当に変更してください。

鏡音レン.pmdで判定を調整しています。
例：鏡音レン.pmdでFPS視点
Cam1Pos.x 頭ボーンに設置
(x,y,z)=(0,2,-2) (Rx,Ry,Rz)=(0,180,0) Si=90
操作用アクセサリを読み込んで設置
(アクセサリ	／ボーン名)
CenterControl.x	／上半身
LeftControl.x	／左中指3
RightControl.x	／右中指3

CameraMove.xのSiに0.1を設定

※視点データと移動データの初期化用に[再生ボタン]を必ず1回は押してください。

・操作方法
前に進むと前進
右手を右に移動させると右旋回
左手を左に移動させると左旋回
※モデルのサイズに合わせて判定を行う必要があります。デフォルトは鏡音レン.pmd。パラメータの項を参照。


●Kinect使用時FPS視点やキャラ後方視点にする場合の設定
(MMDver7.24の場合)
Data/SamplesConfig.xmlの26行目を<Mirror on="false" />に書き換えてください。
(MMDver7.25以降)
メニューの「ﾓｰｼｮﾝｷｬﾌﾟﾁｬ」→「左右反転」のチェックをはずす。

・Kinectキャプチャーの方法
キャプチャー開始と再生が同期してないので、下記のような方法が必要。
CameraMove.xのSi値(サイズ)で移動処理開始時間[s]を設定できます。
キャプチャー時、Siを10秒に設定し、再生ボタンを押した後、すぐキャプチャーを開始します。
再生ボタンを押してから10秒間は動かず、10秒経ってから動いてください。
動画出力時はSiを0秒に設定にして、出力します。


●パラメータ
※判定の調整
CameraMove.fxを開いてください。
デフォルトは鏡音レンで調整してあります。
判定は壁状になっていて、前進判定の場合、前に進んで壁に近づくと前進するようになっています。
また、壁に近いほど速くなるようになっています。
// 距離(位置、範囲)
float2 ForwardDistance	= {-6.0, 4.0};	// Z
float2 BackDistance	= {6.0, 4.0};	// Z
float2 LeftDistance	= {9.0, 5.0};	// X
float2 RightDistance	= {-9.0, 5.0};	// X
float2 DownDistance	= {3.0, 3.0};	// Y
float2 UpDistance	= {20.0, 3.0};	// Y
各行の{}内、最初の数字が判定の壁の位置になります。次の数字が判定の範囲です。
Kinectのキャプチャーの中心の(0,0,0)が原点になっています。
前後用のForwardDistance, BackDistanceはZ軸に垂直な壁の判定。
左、右旋回用のLeftDistance,RightDistanceはX軸に垂直な壁の判定。
上昇、下降用のDownDistance,UpDistanceはY値に垂直な壁の判定。

float Size = 1.0;
Sizeで判定の大きさを変更できます。
体格は同じで、大きさの異なるモデルの場合に便利です。

・移動最大速度
float3 Velocity = float3( 60, 60, 60 );
Velocityで速度を設定。左右(X軸)、上下(Y軸)、前後(Z軸)の移動量。
float3 RotateYPR = float3( radians(120.0), radians(120.0), radians(120.0) );
RotateYPRで旋回速度(度)を設定。Yaw(Y軸),Pitch(X軸),Roll(Z軸)の順に設定。


・平滑化
CameraSmooth.fxの以下のパラメータで平滑化の設定ができます。
// 閾値
float LimitPos = 0.01;
float LimitQuat = 0.02;
LimitPos,LimitQuatで指定した値を超えない限り動かないようになります。
LimitPosは位置、LimitQuatは傾きの調整値。
主に、小さな振動を抑えるための設定値です。大きくすると振動を抑えることができる。
一方で、大きくすると動きがカクつくようにもなるのでなるべく小さい値にするべき。

// 平滑化量(1<)
#define POS_SMOOTH	6
#define QUAT_SMOOTH	6
現在のフレームも含めた過去のフレームの視点情報を保存し、平均値を計算して平滑化しています。
値が大きいほどなめらかになりますが、過去の情報に引っ張られるため遅延が大きくなります。

// 平滑化開始時間
#define WAIT_TIME	0.1
再生ボタンが押されてから初期化しておく時間(秒)。
基本的に変更する必要はない。FPSが極端に小さいとき(1以下)は大きくしたほうがいいかも。

・平滑化を無効にする場合
以下のように値を変更
// 閾値
float LimitPos = 0.0;
float LimitQuat = 0.0;
// 平滑化量(1<)
#define POS_SMOOTH	1
#define QUAT_SMOOTH	1
無効にしても、平滑化の余分な処理があるのでFreeCamera0.1xを使用した方が良い。


●注意点・問題点
エッジ固定処理を行っていないので、MMD本来のカメラの位置と大きく異なると
エッジが太くなりすぎたり、細くなりすぎたりします。
カメラの位置を同じような位置に置くか、エッジをOFFにしてください。
セルフシャドウには、対応していません。


●制限
Camera1.fxを使用してモデルを描画するので、仕組み上他のエフェクトファイルが使用できません。
Clone.fx、Glass.fx、センシティブトゥーンなどは使用できない。
Camera1.fxを改造するしかないです。


●GPU負荷低減
CameraFull.xを有効にしているときはMainRenderTargetへの描画結果は使いません。
MainRenderTargetにnon.fxを使用することで描画を省きます。non.fxを使用すると少し軽くなります。
MMEメニュー「エフェクト割り当て」から各描画モデルにnon.fxを適用してください。


●配布
改造・再配布は自由です。


●更新履歴
2011.01.02 ver0.2
　平滑化機能追加、カメラオフセットを考慮、姿勢計算と移動計算の方法を修正
　判定方法は変更なし。
2010.12.27 ver0.13
　GPU負荷低減non.fxを追加。
2010.12.27 ver0.12
　キャプチャーの方法を記載。スフィアマップを正しく計算。
2010.12.26 ver0.11
　移動量が一定になるようにした。倍率調整できるようにした。
　パラメータを微調整、パラメータ説明文を修正。
2010.12.26 ver0.1公開