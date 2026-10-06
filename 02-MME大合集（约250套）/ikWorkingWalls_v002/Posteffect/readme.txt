合わせ鏡エフェクト ポストエフェクト版

2つの鏡を斜めに配置して万華鏡っぽくするエフェクト。
AutoLuminous と ikBokehに対応しています。

■ 使い方

1. ikWWController.pmx と ikWorkingWalls.x、WW_Posteffect.x の3つをMMDに入れる。
※ 簡易版の2に加えて、WW_Posteffect.x が必要です。

2. ikWWController のセンター位置を鏡の起点になる床に設定する。

3. ikWWController の表情モーフで鏡の開く角度と、色を設定する。

鏡(というかガラス?)は緑色になることが多いようなので、
H = 0.5付近。S = 0.2付近にするとそれらしく見えるかも？

4. 表示順番を調整。
 - ikWWController.pmx : 順番はどこでもいいです。
 - ikWorkingWalls.x : 表示するモデル、アクセサリの最後に配置したほうがいい。
 - WW_Posteffect.x :  可能な限り一番最後に配置する。

5. ikWorkingWalls.x の Si で大きさを変更できます。


■ AutoLuminous と ikBokeh の エフェクト割り当て。

AutoLuminousを使用する場合、MMEの AL_EmitterRTタブで、
ikWorkingWalls.xに対して WW_For_AL.fx を割り当ててください。

ikBokheを使用する場合、MMEの LinearDepthMapRTタブで、
ikWorkingWalls.xに対して WW_For_ikBokeh.fx を割り当ててください。



■ ポリゴンが欠ける場合の対策

背景モデルなどポリゴンが大きいモデルでは、
鏡との境界付近でポリゴン欠けが発生する場合があります。

WorkingWallRT にはWW_Object.fx が割り当てられます。
ポリゴン欠けが発生するモデルには WW_Object_noCheck.fx を割り当てることで、
症状を抑えることができます。

逆に、WW_Object_noCheck.fx を割り当てると、鏡を裏から見た場合に、
本来表示されないはずの側のモデルがレンダリングされる場合があります。



■ 設定ファイル

WW_Settings.fxsub に設定項目があります。

- 鏡表面に貼るテクスチャを指定可能です。
- 鏡の初期サイズを指定可能です。
- 鏡の開く角度を設定できます。
    通常はコントローラの表情モーフで角度を調整してください。
- 鏡面内のエッジ描画を指定できます。(デフォルトはオフ)
- AutoLuminous と ikBokeh 用の出力をオン/オフできます。
    それぞれのポストエフェクトを使わない場合、
    オフにすることで高速になります。


■ 使用、再配布に関して

エフェクトの利用、改造、再配布などについては自由に行ってもらってかまいません、
連絡も不要です。
このエフェクトを使用したことによって起きたすべての損害等について、
作者及び関係者は一切責任を負わないものとします。


ikeno
twitter: @ikeno_mmd
