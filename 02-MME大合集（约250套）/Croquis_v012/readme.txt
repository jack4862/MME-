Croquis.fx v0.12 【シェーダ3以降】
CroquisLite.fx v0.12【シェーダ2対応】

【お約束】
使用・再配布・改造・改造物の再配布を許可します。
一切の保証は致しかねますので、ご自身の責任においてお使いください。

【概要】
輪郭抽出で、線画風の映像を作り出すポストエフェクトです。
Trに依って、原画像と合成できますので、淡い色付を行った線画風にも描画できます。

Croquisは、重いエフェクトです。最後の出力時にだけONにすることをお薦めします。
CroquisLiteは、アンチエイリアスを行わず画質が落ちますが、若干軽めでシェーダ2でも動作します。

【使い方】
Croquis.x、またはCroquisLight.fxを読み込むだけです。
淡い色付を行うときは、Trを0.6-0.8程度にするとよいでしょう。

【カスタマイズ】
gisupeke氏のMME編集ツール、及びsh5氏のfxファイルかきかえまくりんぐツールに対応しました。
線の色、地の色を編集できます。

手動書き換えの場合は、Croquis.fx、及びCroquisLite.fxの12行目～24行目前後

float4 FrontColor <
	string UIName = "線の色";
	string UIWidget = "Color";
	bool UIVisible =  true;
	float3 UIDefault = float4(0, 0, 0, 1);
> = float4( 0 , 0 , 0 , 1 ); ← ここが線の色

float4 BackColor <
	string UIName = "地の色";
	string UIWidget = "Color";
	bool UIVisible =  true;
	float3 UIDefault = float4(1, 1, 1, 1);
> = float4( 1 , 1 , 1 , 1 ); ← ここが地の色


それぞれ、前景色(線の色)と背景色(地の色)です。
デフォルトでは白地に黒となっています。
色の指定は、float4(R,G,B,A)となっており、AはアクセサリのTrと同じ不透明度です。

例えば、以下のように書き換えると、元の画像に緑の線となります。

float4 FrontColor <
	string UIName = "線の色";
	string UIWidget = "Color";
	bool UIVisible =  true;
	float3 UIDefault = float4(0, 0, 0, 1);
> = float4( 0 , 1 , 0 , 1 ); ← 緑の線

float4 BackColor <
	string UIName = "地の色";
	string UIWidget = "Color";
	bool UIVisible =  true;
	float3 UIDefault = float4(1, 1, 1, 1);
> = float4( 0 , 0 , 0 , 0 ); ← 黒の透明


【履歴】
2012.03.27 v0.12 前景色、背景色のαを、原画との合成に使用するよう変更
2011.09.05 v0.11 前景色と背景色を設定可能に
2011.04.30 v0.1 公開

Elle/データP
