ATステージver2.5専用 WorkingFloor2 & SoftShadow

ATステージ(アンティーク調ステージ)はカブッＰ様作のMikuMikuDance専用の背景ステージモデルです．
http://www.nicovideo.jp/watch/sm13235882

WorkingFloor2.x，SoftShadow.xの描画順序は基本的にステージ描画の後に行いますが
ATステージはフロア部がPMDになっているため，正しく描画させるための設定がやや面倒です．
そこで，所定のPMDをロードするだけで両エフェクトが正常に描画されATステージで最適化に
なるようにチューニングしてみました．(エフェクト描画はフロア内でクリップされます)


・使用方法
(1)解凍したフォルダ内に本家のATステージver2.5のファイル一式をコピーしてください．

(2)ATステージxファイル一式,ステージで踊らせたいPMDをMMDにロードします．

(3)ATS半透明ver2.pmdの代わりに,かけたいエフェクトに応じて以下のPMDをMMDにロードします．
     ATS半透明ver2[WorkingFloor2.fx].pmd  : WorkingFloor2のみ使用する場合
     ATS半透明ver2[SoftShadow.fx].pmd     : SoftShadowのみ使用する場合
     ATS半透明ver2[WF2_and_SoftS.fx].pmd  : WorkingFloor2とSoftShadowの両方を使用する場合

(4)ATS半透明ver2[*.fx].pmdの表情スライダのそれぞれの項目で以下の制御が可能です．
    目  ：影透過 → SoftShadowの影の透過度を変更します．
          影濃度 → SoftShadowの影色の濃さ変更します．
    ﾘｯﾌﾟ：影ぼかし → SoftShadowの影のぼかし度合いを調整します．
    その他：鏡像透過 → WorkingFloor2の鏡像の透過度を変更します．


・注意点
ATステージ本体の取り扱いについてはステージデータに同梱されている取説.txtに従ってください．


・免責事項
ご利用はすべて自己責任でお願いします．


by 針金P


