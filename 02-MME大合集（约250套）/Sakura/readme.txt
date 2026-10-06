--桜吹雪エフェクト--
作った人：ビームマンP(ロベリア）
改変元：TexSnow.fx（そぼろ様）

-基本的な使い方-
1:Sakura.xを読み込みます。とりあえずこれで降る筈です。
2:Controller_0.pmdを読み込みます。
3:コントローラのX,Z座標で風向きを、表情モーフから各種設定が行えます。
4:Sakura.xの影をオンにすれば影も表示します。が、重いです。ご利用は計画的に。
5:パーティクルの最大数はSakura.fx内の
#define CLONE_NUM 1024
ここを書き変える事で設定します。
最大は初期状態で4096です。

・備考
「速度」モーフ変更時に全体がちらつくのは計算上の仕様です。
場面転換時などで上手くごまかして下さい。


-応用的な使い方-
sakura.pngを書き変える事で他の演出にも使用できます。
その場合、左上、右上、左下、右下の４種類の画像を全て書き換えてください。


・うごかない！という場合
Sakura.fx内の
//乱数テクスチャ
texture2D rndtex <
    //string ResourceName = "random2048.bmp";
    string ResourceName = "random4096.bmp";
>;
これを
texture2D rndtex <
    string ResourceName = "random2048.bmp";
    //string ResourceName = "random4096.bmp";
>;
こうしてください。
もしかしたら　動く、かも？