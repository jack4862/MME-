# 空中に漂う埃.fx 纹理加载错误修复说明

## 原始报错

```
无法加载特效文件: D:\MME合集\02-MME大合集（约250套）\空中に漂う埃\空中に漂う埃.fx
Error: failed to open file: 稲2.png (parameter: Tex1)
Error: failed to open file: 稲1.png (parameter: Tex2)
```

## 原因

`空中に漂う埃.fx` 是日文 MME 特效，纹理名原先使用非 ASCII 的「埃」字：

- 当前 `.fx` 文件为 GBK（cp936）编码，两处 `string ResourceName` 分别为 `埃2.png`、`埃1.png`；
- 原版备份 `空中に漂う埃.fx.备份_原版SJIS` 为 Shift-JIS 编码；
- MikuMikuEffect 在读取字符串后，会按当前 ANSI 代码页把文件名转换成 Windows 路径。代码页与 `.fx` 文件编码不一致时，同一个字节序列可能显示成「稲」等其它字符，于是 MME 去找 `稲1.png` / `稲2.png`，而文件夹里实际存在的是 `埃1.png` / `埃2.png`，加载失败。

## 修复内容

1. 保留原文件 `埃1.png`、`埃2.png` 不动；
2. 新增两份字节完全相同的 ASCII 名副本：
   - `埃1.png` → `dust1.png`
   - `埃2.png` → `dust2.png`
3. 只替换 `空中に漂う埃.fx` 中两处纹理文件名字符串：
   - `ResourceName = "埃2.png"` → `ResourceName = "dust2.png"`
   - `ResourceName = "埃1.png"` → `ResourceName = "dust1.png"`
4. 文件其它字节、GBK 日文注释、CRLF 换行均保持不变。

修复后纹理名为纯 ASCII，不再依赖任何系统代码页，因此不会再出现「稲1.png / 稲2.png」这类编码解析错误。

## 备份与回滚

修复前自动备份：

```
D:\MME合集\02-MME大合集（约250套）\空中に漂う埃\空中に漂う埃.fx.bak_before_ascii_dust_fix_20261006_202130
```

如需回滚，用该备份覆盖 `空中に漂う埃.fx` 即可。新增的 `dust1.png` / `dust2.png` 可以保留，不影响原文件。

## 验证证据

- 修复后 `.fx`：15812 字节，SHA256 `94fc4edf378d1ae53139fca8a88c56684c5bbd7a6d2bddf6887643a6a0925051`
- `dust1.png`：1740 字节，SHA256 `f5f1f19e452a087c94edfc5527d412c7e6dd2d4cedb871f294557ef57b015bf4`（与 `埃1.png` 一致）
- `dust2.png`：3531 字节，SHA256 `0009ea3e4025bd0ba419fbdcb282656a77a21887438aefa20deb23a467d38c9f`（与 `埃2.png` 一致）
- `random256x256.bmp` 仍在原目录，未被改动
- `fxc.exe /T fx_2_0` 编译通过（exit code 0，仅 D3DCompiler_47 的 Effects 弃用警告 X4717）
- 静态解析：修复后所有 `string ResourceName` 均为 ASCII，且 `dust1.png`、`dust2.png`、`random256x256.bmp` 均存在
- 字节级回滚检查：把两处 ASCII 名替换回原 GBK 名后，与修复前备份逐字节一致

## 说明

对 `02-MME大合集（约250套）` 做了只读扫描：1328 个 `.fx` 中，修复后已经没有非 ASCII 图片资源名引用。另有 12 处 ASCII 图片名引用在当前目录中不存在（例如 `Movies\movie1-8.fx` 的 `movie*.png`、`WaterMain.fx` 的 `height.png`/`choppy.png`、`RainLite.fx` 的 `rain5.png` 等），它们通常是示例模板或需要用户自备的贴图，不是本次的编码型错误，未做改动。
