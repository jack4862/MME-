
/**********************************************************************************
 * VMDFormatクラス
 * 製作：そぼろ
 * Ver.1.04
 * 2010/01/13
 * 
 * MikuMikuDanceのモーションファイルであるVMDフォーマットファイルへの
 * ほぼ完全なアクセスとデータ管理を提供します
 * Cloneメソッドによるコピーに対応しています
 * 現状での未解決は、カメラレコードデータの末尾の4バイトが不明です（とりあえず0埋め）
 * 補助機能にはいろいろ未実装の部分も多いです
 * エラー処理は十分とはいえませんので、利用の際はご注意ください
 * また、MMDが受け入れ可能な値の範囲のチェックは行っていません
 * 
 * 
 * 使用例：
 
   VMDFormat vmd = new VMDFormat();
   if(vmd.Read(@"C:\test.vmd")){
     if(vmd.MotionRecords.Count > 0) Debug.WriteLine(vmd.MotionRecords[0].BoneName);
   }
 
 ***********************************************************************************/


using System;
using System.Collections.Generic;
using System.Text;
using System.IO;


/// <summary>
/// VMDフォーマットファイルへのアクセスとデータ管理を提供する
/// </summary>
public class VMDFormat : ICloneable
{
    private const string DefaultHeaderScript = "Vocaloid Motion Data 0002";
    private string hdscr;
    private string actor;

    /// <summary>
    /// ヘッダ文字列
    /// </summary>
    public string HeaderScript
    {
        get { return hdscr; }
        set { hdscr = value; }
    }
    /// <summary>
    /// モデル名称
    /// </summary>
    public string Actor
    {
        get { return actor; }
        set { actor = value; }
    }

    /// <summary>
    /// モーションレコードのリスト
    /// </summary>
    public List<VMDFormat.MotionRecord> MotionRecords = new List<MotionRecord>();
    /// <summary>
    /// 表情レコードのリスト
    /// </summary>
    public List<VMDFormat.ExpressionRecord> ExpressionRecords = new List<ExpressionRecord>();
    /// <summary>
    /// カメラレコードのリスト
    /// </summary>
    public List<VMDFormat.CameranRecord> CameranRecords = new List<CameranRecord>();
    /// <summary>
    /// 照明レコードのリスト
    /// </summary>
    public List<VMDFormat.LightRecord> LightRecords = new List<LightRecord>();


    public VMDFormat()
    {
        this.Reset();
    }


    /// <summary>
    /// 格納された情報を初期化する
    /// </summary>
    public void Reset()
    {
        this.HeaderScript = DefaultHeaderScript;
        this.Actor = "初音ミク";

        this.MotionRecords.Clear();
        this.ExpressionRecords.Clear();
        this.CameranRecords.Clear();
        this.LightRecords.Clear();

    }

    /// <summary>
    /// クラスの複製
    /// </summary>
    public object Clone()
    {
        VMDFormat vmd = new VMDFormat();
        int i;

        vmd.HeaderScript = this.HeaderScript;
        vmd.Actor = this.Actor;

        //Listの内容を延々とコピー
        for (i = 0; i < this.MotionRecords.Count; i++)
            vmd.MotionRecords.Add((MotionRecord)this.MotionRecords[i].Clone());
        for (i = 0; i < this.ExpressionRecords.Count; i++)
            vmd.ExpressionRecords.Add((ExpressionRecord)this.ExpressionRecords[i].Clone());
        for (i = 0; i < this.CameranRecords.Count; i++)
            vmd.CameranRecords.Add((CameranRecord)this.CameranRecords[i].Clone());
        for (i = 0; i < this.LightRecords.Count; i++)
            vmd.LightRecords.Add((LightRecord)this.LightRecords[i].Clone());

        return vmd;
    }

    /// <summary>
    /// VMDファイルを開いて情報を読み出す
    /// </summary>
    /// <param name="path">VMDファイルのフルパス</param>
    /// <returns>成功すればtrue、失敗すればfalseを返す</returns>
    public bool Read(string path)
    {
        bool ret;
        FileStream fs;

        if (!File.Exists(path)) return false;

        try
        {
            fs = new FileStream(path, FileMode.Open, FileAccess.Read);
        }
        catch
        {
            return false;
        }

        //Stream版Readへとリダイレクト
        ret = this.Read(fs);

        fs.Close();

        return ret;
    }

    /// <summary>
    /// VMDファイルのストリームから情報を読み出す
    /// </summary>
    /// <param name="path">使用するストリーム</param>
    /// <returns>成功すればtrue、失敗すればfalseを返す</returns>
    public bool Read(Stream stream)
    {
        int i, RecordCount;
        BinaryReader br = new BinaryReader(stream);

        this.Reset();

        try
        {
            this.HeaderScript = StreamRead_ShiftJIS(stream, 30);
            if (this.HeaderScript.CompareTo(DefaultHeaderScript) != 0) return false;
            this.Actor = StreamRead_ShiftJIS(stream, 20);

            RecordCount = br.ReadInt32(); //モーションレコードの数を読み出し
            //データを読み出してリストに追加
            for (i = 0; i < RecordCount; i++)
                MotionRecords.Add(new MotionRecord(stream));

            RecordCount = br.ReadInt32(); //表情レコードの数を読み出し
            //データを読み出してリストに追加
            for (i = 0; i < RecordCount; i++)
                ExpressionRecords.Add(new ExpressionRecord(stream));

            RecordCount = br.ReadInt32(); //カメラレコードの数を読み出し
            //データを読み出してリストに追加
            for (i = 0; i < RecordCount; i++)
                CameranRecords.Add(new CameranRecord(stream));

            RecordCount = br.ReadInt32(); //照明レコードの数を読み出し
            //データを読み出してリストに追加
            for (i = 0; i < RecordCount; i++)
                LightRecords.Add(new LightRecord(stream));

        }
        catch
        {
            return false;
        }


        return true;
    }


    /// <summary>
    /// VMDファイルを開いて情報を書き出す
    /// </summary>
    /// <param name="path">VMDファイルのフルパス</param>
    /// <returns>成功すればtrue、失敗すればfalseを返す</returns>
    public bool Write(string path)
    {
        bool ret;
        FileStream fs;

        //ディレクトリが無ければエラー
        if (!Directory.Exists(Path.GetDirectoryName(path))) return false;

        try
        {
            fs = new FileStream(path, FileMode.Create, FileAccess.Write);
        }
        catch
        {
            return false;
        }

        //Stream版Writeへとリダイレクト
        ret = this.Write(fs);

        fs.Close();

        return ret;
    }

    /// <summary>
    /// VMDファイルのストリームへ情報を書き出す
    /// </summary>
    /// <param name="path">使用するストリーム</param>
    /// <returns>成功すればtrue、失敗すればfalseを返す</returns>
    public bool Write(Stream stream)
    {
        BinaryWriter bw = new BinaryWriter(stream);

        try
        {

            StreamWrite_ShiftJIS(stream, this.HeaderScript, 30);
            StreamWrite_ShiftJIS(stream, this.Actor, 20);

            bw.Write(this.MotionRecords.Count);
            foreach (Record rec in MotionRecords) rec.Write(stream);

            bw.Write(this.ExpressionRecords.Count);
            foreach (Record rec in ExpressionRecords) rec.Write(stream);

            bw.Write(this.CameranRecords.Count);
            foreach (Record rec in CameranRecords) rec.Write(stream);

            bw.Write(this.LightRecords.Count);
            foreach (Record rec in LightRecords) rec.Write(stream);

        }
        catch
        {
            return false;
        }

        return true;
    }





    //　基礎的な構造体の定義　///////////////////////////////////////////////////////////////////////



    /// <summary>
    /// 補完スプライン曲線の情報を格納する構造体の定義
    /// </summary>
    public struct ComplementBezier
    {
        public int p1x;
        public int p1y;

        public int p2x;
        public int p2y;

        public static ComplementBezier GetDefault()
        {
            ComplementBezier def;
            def.p1x = 20;
            def.p1y = 20;
            def.p2x = 107;
            def.p2y = 107;
            return def;
        }

        /// <summary>
        /// 4つの要素をカンマで結合して文字列に
        /// </summary>
        public override string ToString()
        {
            return p1x.ToString() + "," + p1y.ToString() + "," + p2x.ToString() + "," + p2y.ToString();
        }

        /// <summary>
        /// カンマ区切りの4つの数字の文字列から値の受け入れ
        /// </summary>
        public bool FromString(string str)
        {
            string[] strs = str.Split(',');

            if (strs.Length != 4) throw new Exception("Can't convert to ComplementSpline.");

            this.p1x = int.Parse(strs[0]);
            this.p1y = int.Parse(strs[1]);
            this.p2x = int.Parse(strs[2]);
            this.p2y = int.Parse(strs[3]);

            return true;
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="x">0から1.0の値</param>
        float GetComplementValue(float x)
        {
            //未実装
            return 0;
        }
    }

    /// <summary>
    /// 平行移動の情報を格納する構造体の定義
    /// </summary>
    public struct Transfer
    {
        public float x;
        public float y;
        public float z;

        public static Transfer GetDefault()
        {
            Transfer def;
            def.x = def.y = def.z = 0;
            return def;
        }
    }

    /// <summary>
    /// ボーンの回転の情報を格納する構造体の定義 (クオータニオン)
    /// </summary>
    public struct Quaternion
    {
        public float x;
        public float y;
        public float z;
        public float w;

        public static Quaternion GetDefault()
        {
            Quaternion def;
            def.x = 0;
            def.y = 0;
            def.z = 0;
            def.w = 1;
            return def;
        }

        /// <summary>
        /// クオータニオンどうしの掛け算を行う
        /// </summary>
        public static Quaternion Multiply(Quaternion Qt1, Quaternion Qt2)
        {
            Quaternion Qret = new Quaternion();

            Qret.w = (Qt1.w * Qt2.w) - (Qt1.x * Qt2.x + Qt1.y * Qt2.y + Qt1.z * Qt2.z);
            Qret.x = (Qt1.w * Qt2.x) + (Qt2.w * Qt1.x) - (Qt1.y * Qt2.z - Qt1.z * Qt2.y);
            Qret.y = (Qt1.w * Qt2.y) + (Qt2.w * Qt1.y) - (Qt1.z * Qt2.x - Qt1.x * Qt2.z);
            Qret.z = (Qt1.w * Qt2.z) + (Qt2.w * Qt1.z) - (Qt1.x * Qt2.y - Qt1.y * Qt2.z);

            return Qret;
        }

        /// <summary>
        /// クオータニオンどうしの掛け算を行う
        /// </summary>
        public Quaternion Multiply(Quaternion Qt)
        {
            return Multiply(this, Qt);
        }

        /// <summary>
        /// 共役なクオータニオンを返す
        /// </summary>
        public static Quaternion Conjugate(Quaternion Qt)
        {
            Quaternion Qret = new Quaternion();

            Qret.w = Qt.w;
            Qret.x = -Qt.x;
            Qret.y = -Qt.y;
            Qret.z = -Qt.z;

            return Qret;
        }

        /// <summary>
        /// 共役なクオータニオンを返す
        /// </summary>
        public Quaternion Conjugate()
        {
            return Conjugate(this);
        }



        /// <summary>
        /// クオータニオンどうしの掛け算の演算子のオーバーロード
        /// </summary>
        public static Quaternion operator *(Quaternion z, Quaternion w)
        {
            return Multiply(z, w);
        }


    }

    /// <summary>
    /// オイラー角による回転の情報を格納する構造体の定義
    /// </summary>
    public struct EulerAngle
    {
        public float x; //X軸回りの回転
        public float y; //Y軸回りの回転
        public float z; //Z軸回りの回転

        public static EulerAngle GetDefault()
        {
            EulerAngle def;
            def.x = 0;
            def.y = 0;
            def.z = 0;
            return def;
        }

        /// <summary>
        /// オイラー角をクオータニオンに変換します
        /// </summary>
        public Quaternion ToQuaternion()
        {

            Quaternion qx = Quaternion.GetDefault();
            Quaternion qy = Quaternion.GetDefault();
            Quaternion qz = Quaternion.GetDefault();

            qx.x = (float)Math.Sin(this.x / 2);
            qx.w = (float)Math.Cos(this.x / 2);
            qy.y = (float)Math.Sin(this.y / 2);
            qy.w = (float)Math.Cos(this.y / 2);
            qz.z = (float)Math.Sin(this.z / 2);
            qz.w = (float)Math.Cos(this.z / 2);

            return qx * qy * qz;
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////

    /// <summary>
    /// 各レコードの基本クラス
    /// </summary>
    public abstract class Record : IComparable<Record>, ICloneable
    {

        private int _FrameNumber = 0;

        /// <summary>
        /// フレーム番号
        /// </summary>
        public int FrameNumber
        {
            get { return _FrameNumber; }
            set { _FrameNumber = value; }
        }

        //フレーム番号順のソートに対応
        public int CompareTo(Record other)
        {
            return (this.FrameNumber - other.FrameNumber);
        }

        abstract public void Read(Stream stream);
        abstract public void Write(Stream stream);
        abstract public object Clone();





    }

    /////////////////////////////////////////////////////////////////////////////////////////////////

    /// <summary>
    /// モーションレコードの情報を格納するクラス
    /// </summary>
    public class MotionRecord : Record
    {

        public MotionRecord() { }

        /// <summary>
        /// インスタンスの作成と同時にデータを読み出す
        /// </summary>
        public MotionRecord(Stream stream)
        {
            this.Read(stream);
        }

        /// <summary>
        /// クラスの複製
        /// </summary>
        public override object Clone()
        {
            //値型しか持たないのでMemberwiseCloneで済ませる
            return this.MemberwiseClone();
        }


        /// <summary>
        /// ボーン名
        /// </summary>
        public string BoneName = " ";

        /// <summary>
        /// 平行移動の情報
        /// </summary>
        public Transfer Trans = Transfer.GetDefault();

        /// <summary>
        /// 回転の情報 (-180 to 180)
        /// </summary>
        public Quaternion Qt = Quaternion.GetDefault();

        /// <summary>
        /// X軸座標の補完曲線
        /// </summary>
        public ComplementBezier CBX = ComplementBezier.GetDefault();
        /// <summary>
        /// Y軸座標の補完曲線
        /// </summary>
        public ComplementBezier CBY = ComplementBezier.GetDefault();
        /// <summary>
        /// Z軸座標の補完曲線
        /// </summary>
        public ComplementBezier CBZ = ComplementBezier.GetDefault();
        /// <summary>
        /// 回転の補完曲線
        /// </summary>
        public ComplementBezier CBQ = ComplementBezier.GetDefault();

        /// <summary>
        /// ストリームから単独のレコードを読み出す
        /// </summary>
        public override void Read(Stream stream)
        {
            BinaryReader br = new BinaryReader(stream);

            this.BoneName = StreamRead_ShiftJIS(stream, 15);

            this.FrameNumber = br.ReadInt32();
            this.Trans.x = br.ReadSingle();
            this.Trans.y = br.ReadSingle();
            this.Trans.z = br.ReadSingle();
            this.Qt.x = br.ReadSingle();
            this.Qt.y = br.ReadSingle();
            this.Qt.z = br.ReadSingle();
            this.Qt.w = br.ReadSingle();

            read_cb(br, ref CBX);
            read_cb(br, ref CBY);
            read_cb(br, ref CBZ);
            read_cb(br, ref CBQ);
        }

        /// <summary>
        /// ストリームに単独のレコードを書き出す
        /// </summary>
        public override void Write(Stream stream)
        {
            BinaryWriter bw = new BinaryWriter(stream);

            StreamWrite_ShiftJIS(stream, this.BoneName, 15);

            bw.Write(this.FrameNumber);
            bw.Write(this.Trans.x);
            bw.Write(this.Trans.y);
            bw.Write(this.Trans.z);
            bw.Write(this.Qt.x);
            bw.Write(this.Qt.y);
            bw.Write(this.Qt.z);
            bw.Write(this.Qt.w);

            write_cb(bw, ref CBX);
            write_cb(bw, ref CBY);
            write_cb(bw, ref CBZ);
            write_cb(bw, ref CBQ);

        }

        /// <summary>
        /// 補完パターンの読み出し
        /// </summary>
        private void read_cb(BinaryReader br, ref ComplementBezier cb)
        {
            //上位3バイトはダミーデータと思われる
            cb.p1x = (int)(br.ReadUInt32() & 0x7F);
            cb.p1y = (int)(br.ReadUInt32() & 0x7F);
            cb.p2x = (int)(br.ReadUInt32() & 0x7F);
            cb.p2y = (int)(br.ReadUInt32() & 0x7F);
        }

        /// <summary>
        /// 補完パターンの書き出し
        /// </summary>
        private void write_cb(BinaryWriter bw, ref ComplementBezier cb)
        {
            bw.Write(cb.p1x);
            bw.Write(cb.p1y);
            bw.Write(cb.p2x);
            bw.Write(cb.p2y);
        }

    }

    /////////////////////////////////////////////////////////////////////////////////////////////////

    /// <summary>
    /// 表情レコードの情報を格納するクラス
    /// </summary>
    public class ExpressionRecord : Record
    {

        public ExpressionRecord() { }

        /// <summary>
        /// インスタンスの作成と同時にデータを読み出す
        /// </summary>
        public ExpressionRecord(Stream stream)
        {
            this.Read(stream);
        }

        /// <summary>
        /// クラスの複製
        /// </summary>
        public override object Clone()
        {
            //値型しか持たないのでMemberwiseCloneで済ませる
            return this.MemberwiseClone();
        }

        /// <summary>
        /// 表情の名前
        /// </summary>
        public string ExpressionName = " ";

        /// <summary>
        /// 表情パラメータ
        /// </summary>
        public float Factor = 0;

        /// <summary>
        /// ストリームから単独のレコードを読み出す
        /// </summary>
        public override void Read(Stream stream)
        {
            BinaryReader br = new BinaryReader(stream);

            this.ExpressionName = StreamRead_ShiftJIS(stream, 15);

            this.FrameNumber = br.ReadInt32();
            this.Factor = br.ReadSingle();

        }

        /// <summary>
        /// ストリームに単独のレコードを書き出す
        /// </summary>
        public override void Write(Stream stream)
        {
            BinaryWriter bw = new BinaryWriter(stream);

            StreamWrite_ShiftJIS(stream, this.ExpressionName, 15);

            bw.Write(this.FrameNumber);
            bw.Write(this.Factor);
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////

    /// <summary>
    /// カメラレコードの情報を格納するクラス
    /// </summary>
    public class CameranRecord : Record
    {

        public CameranRecord() { }

        /// <summary>
        /// インスタンスの作成と同時にデータを読み出す
        /// </summary>
        public CameranRecord(Stream stream)
        {
            this.Read(stream);
        }

        /// <summary>
        /// クラスの複製
        /// </summary>
        public override object Clone()
        {
            //値型しか持たないのでMemberwiseCloneで済ませる
            return this.MemberwiseClone();
        }

        /// <summary>
        /// カメラ距離
        /// </summary>
        public float Distance = 0;

        /// <summary>
        /// 平行移動の情報
        /// </summary>
        public Transfer Trans = Transfer.GetDefault();

        /// <summary>
        /// 回転の情報 (-1.0 to 1.0)
        /// </summary>
        public EulerAngle Ang = EulerAngle.GetDefault();

        /// <summary>
        /// X軸座標の補完曲線
        /// </summary>
        public ComplementBezier CBX = ComplementBezier.GetDefault();
        /// <summary>
        /// Y軸座標の補完曲線
        /// </summary>
        public ComplementBezier CBY = ComplementBezier.GetDefault();
        /// <summary>
        /// Z軸座標の補完曲線
        /// </summary>
        public ComplementBezier CBZ = ComplementBezier.GetDefault();
        /// <summary>
        /// 回転の補完曲線
        /// </summary>
        public ComplementBezier CBQ = ComplementBezier.GetDefault();
        /// <summary>
        /// 距離の補完曲線
        /// </summary>
        public ComplementBezier CBD = ComplementBezier.GetDefault();
        /// <summary>
        /// 視野角の補完曲線
        /// </summary>
        public ComplementBezier CBV = ComplementBezier.GetDefault();

        /// <summary>
        /// 視野角 (1 to 125)
        /// </summary>
        public int ViewAngle = 45;

        /// <summary>
        /// ストリームから単独のレコードを読み出す
        /// </summary>
        public override void Read(Stream stream)
        {
            BinaryReader br = new BinaryReader(stream);

            this.FrameNumber = br.ReadInt32();
            this.Distance = br.ReadSingle();
            this.Trans.x = br.ReadSingle();
            this.Trans.y = br.ReadSingle();
            this.Trans.z = br.ReadSingle();
            this.Ang.x = br.ReadSingle();
            this.Ang.y = br.ReadSingle();
            this.Ang.z = br.ReadSingle();

            read_cb(br, ref CBX);
            read_cb(br, ref CBY);
            read_cb(br, ref CBZ);
            read_cb(br, ref CBQ);
            read_cb(br, ref CBD);
            read_cb(br, ref CBV);

            this.ViewAngle = br.ReadByte();
            stream.Seek(4, SeekOrigin.Current); //不明

        }

        /// <summary>
        /// ストリームに単独のレコードを書き出す
        /// </summary>
        public override void Write(Stream stream)
        {
            BinaryWriter bw = new BinaryWriter(stream);

            bw.Write(this.FrameNumber);
            bw.Write(this.Distance);
            bw.Write(this.Trans.x);
            bw.Write(this.Trans.y);
            bw.Write(this.Trans.z);
            bw.Write(this.Ang.x);
            bw.Write(this.Ang.y);
            bw.Write(this.Ang.z);

            write_cb(bw, ref CBX);
            write_cb(bw, ref CBY);
            write_cb(bw, ref CBZ);
            write_cb(bw, ref CBQ);
            write_cb(bw, ref CBD);
            write_cb(bw, ref CBV);

            bw.Write((byte)(this.ViewAngle));
            stream.Seek(4, SeekOrigin.Current); //不明
        }

        /// <summary>
        /// 補完パターンの読み出し
        /// </summary>
        private void read_cb(BinaryReader br, ref ComplementBezier cb)
        {
            //モーション補完とはデータ形式が異なる
            cb.p1x = br.ReadByte();
            cb.p2x = br.ReadByte();
            cb.p1y = br.ReadByte();
            cb.p2y = br.ReadByte();
        }

        /// <summary>
        /// 補完パターンの書き出し
        /// </summary>
        private void write_cb(BinaryWriter bw, ref ComplementBezier cb)
        {
            bw.Write((byte)(cb.p1x));
            bw.Write((byte)(cb.p2x));
            bw.Write((byte)(cb.p1y));
            bw.Write((byte)(cb.p2y));
        }

    }

    /////////////////////////////////////////////////////////////////////////////////////////////////

    /// <summary>
    /// 照明レコードの情報を格納するクラス
    /// </summary>
    public class LightRecord : Record
    {

        public LightRecord() { }

        /// <summary>
        /// インスタンスの作成と同時にデータを読み出す
        /// </summary>
        public LightRecord(Stream stream)
        {
            this.Read(stream);
        }

        /// <summary>
        /// クラスの複製
        /// </summary>
        public override object Clone()
        {
            //値型しか持たないのでMemberwiseCloneで済ませる
            return this.MemberwiseClone();
        }

        /// <summary>
        /// 赤色要素 (0.0 to 1.0)
        /// </summary>
        public float R = 154f / 255f;
        /// <summary>
        /// 緑色要素 (0.0 to 1.0)
        /// </summary>
        public float G = 154f / 255f;
        /// <summary>
        /// 青色要素 (0.0 to 1.0)
        /// </summary>
        public float B = 154f / 255f;

        /// <summary>
        /// 照射方向の情報 (-1.0 to 1.0)
        /// </summary>
        public Transfer Dir = Transfer.GetDefault();

        /// <summary>
        /// ストリームから単独のレコードを読み出す
        /// </summary>
        public override void Read(Stream stream)
        {
            BinaryReader br = new BinaryReader(stream);

            this.FrameNumber = br.ReadInt32();
            this.R = br.ReadSingle();
            this.G = br.ReadSingle();
            this.B = br.ReadSingle();
            this.Dir.x = br.ReadSingle();
            this.Dir.y = br.ReadSingle();
            this.Dir.z = br.ReadSingle();


        }

        /// <summary>
        /// ストリームに単独のレコードを書き出す
        /// </summary>
        public override void Write(Stream stream)
        {
            BinaryWriter bw = new BinaryWriter(stream);

            bw.Write(this.FrameNumber);
            bw.Write(this.R);
            bw.Write(this.G);
            bw.Write(this.B);
            bw.Write(this.Dir.x);
            bw.Write(this.Dir.y);
            bw.Write(this.Dir.z);

        }


    }


    /////////////////////////////////////////////////////////////////////////////////////////////////





    // ツール的関数群 ////////////////

    //ストリームからShift-JIS形式の文字列を読み取る
    //ByteSizeを指定すると、その分だけ読み取る
    //ByteSizeにゼロを指定すると、0x00が出現するまで読み取る
    static private string StreamRead_ShiftJIS(Stream stream, int ByteSize)
    {
        Encoding Shift_JIS = Encoding.GetEncoding(932);
        MemoryStream buf1 = new MemoryStream();
        string retstr;

        int i = 0, val;

        while (!(ByteSize > 0 && i >= ByteSize)) //指定バイト数読み取ったら終了
        {
            val = stream.ReadByte();
            i++;

            if (val == 0x00) //終端コードを検出
            {
                if (ByteSize > 0) stream.Seek(ByteSize - i, SeekOrigin.Current);
                break;
            }

            buf1.WriteByte((byte)val);

        }

        buf1.Position = 0;
        StreamReader sr = new StreamReader(buf1, Shift_JIS, false);
        retstr = sr.ReadToEnd();
        sr.Close();

        return retstr;
    }

    static private void StreamWrite_ShiftJIS(Stream stream, string str, int ByteSize)
    {
        Encoding Shift_JIS = Encoding.GetEncoding(932);
        MemoryStream buf1 = new MemoryStream();

        StreamWriter sw = new StreamWriter(buf1, Shift_JIS);
        sw.AutoFlush = true;
        sw.Write(str);

        while (buf1.Length < ByteSize) buf1.WriteByte(0);
        buf1.Position = 0;
        for (int i = 0; i < ByteSize; i++) stream.WriteByte((byte)buf1.ReadByte());

        sw.Close();

    }


}

