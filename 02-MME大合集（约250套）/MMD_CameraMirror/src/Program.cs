using System;
using System.Collections.Generic;
using System.Text;
using System.IO;
using System.Threading;

namespace MMD_CameraMirror
{
    class Program
    {
        static void Main(string[] args)
        {

            VMDFormat vmd = new VMDFormat();
            int endmode = 0;

            foreach (string path in args)
            {
                if (path.EndsWith(".vmd"))
                {
                    if (File.Exists(path))
                    {
                        Console.WriteLine("File: " + path);
                        endmode = 1;


                        if (vmd.Read(path))
                        {
                            if (vmd.CameranRecords.Count > 0)
                            {
                                foreach (VMDFormat.CameranRecord cr in vmd.CameranRecords)
                                {
                                    cr.Trans.y = -cr.Trans.y;
                                    cr.Ang.x = -cr.Ang.x;
                                    cr.Ang.z = -cr.Ang.z;
                                }

                                string newpath = Path.Combine(Path.GetDirectoryName(path), Path.GetFileNameWithoutExtension(path) + "_M.vmd");
                                if (vmd.Write(newpath))
                                {
                                    endmode = 2;
                                }

                            }
                        }
                        

                    }
                }

            }


            if (endmode == 0)
            {
                Console.WriteLine("ファイルが指定されていません");
            }
            else if (endmode == 1)
            {
                Console.WriteLine("変換失敗...");
            }
            else
            {
                Console.WriteLine("変換成功！");
            }

            Thread.Sleep(600);

        }
    }
}
