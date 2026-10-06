
texture MovieTex : ANIMATEDTEXTURE <
    // 使用するAPNG(or AGIF)ファイルを指定する。
    //string ResourceName = "movie4.png";
    string ResourceName = "movie7.png";
>;


// セルフシャドウOFF用
technique MainTec < string MMDPass = "object"; > {
    pass DrawObject {
        // アクセサリ描画時に、本来のテクスチャの代わりに、
        // 上記のアニメーションテクスチャを使用するように設定
        Texture[0] = MovieTex;
    }
}

// セルフシャドウON用
technique MainTec < string MMDPass = "object_ss"; > {
    pass DrawObject {
        Texture[1] = MovieTex;
    }
}
