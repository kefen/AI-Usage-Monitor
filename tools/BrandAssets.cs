using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Collections.Generic;

internal static class BrandAssets {
    static GraphicsPath Round(float x,float y,float w,float h,float r){var p=new GraphicsPath();p.AddArc(x,y,r,r,180,90);p.AddArc(x+w-r,y,r,r,270,90);p.AddArc(x+w-r,y+h-r,r,r,0,90);p.AddArc(x,y+h-r,r,r,90,90);p.CloseFigure();return p;}
    static byte[] Png(int size,bool template,bool white){
        using(var hi=new Bitmap(1024,1024)){
            using(var g=Graphics.FromImage(hi)){
                g.SmoothingMode=SmoothingMode.AntiAlias;g.Clear(Color.Transparent);
                if(!template)using(var p=Round(32,32,960,960,464))using(var b=new SolidBrush(Color.FromArgb(40,100,215)))g.FillPath(b,p);
                Color ink=template?(white?Color.White:Color.Black):Color.FromArgb(239,248,243);
                using(var pen=new Pen(ink,88)){pen.StartCap=pen.EndCap=LineCap.Round;pen.LineJoin=LineJoin.Round;g.DrawLines(pen,new[]{new PointF(256,272),new PointF(400,400),new PointF(256,528)});g.DrawLine(pen,576,464,752,464);}
                using(var b=new SolidBrush(template?ink:Color.FromArgb(23,71,159)))using(var p=Round(224,712,576,72,72))g.FillPath(b,p);
                if(!template)using(var b=new SolidBrush(Color.FromArgb(163,230,206)))using(var p=Round(224,712,392,72,72))g.FillPath(b,p);
            }
            using(var small=new Bitmap(size,size)){
                using(var g=Graphics.FromImage(small)){g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.DrawImage(hi,0,0,size,size);}
                using(var stream=new MemoryStream()){small.Save(stream,ImageFormat.Png);return stream.ToArray();}
            }
        }
    }
    static void Ico(string file,bool template,bool white){
        int[] sizes={16,20,24,32,48,64,128,256};var data=new List<byte[]>();foreach(int n in sizes)data.Add(Png(n,template,white));
        using(var w=new BinaryWriter(File.Create(file))){w.Write((ushort)0);w.Write((ushort)1);w.Write((ushort)sizes.Length);int offset=6+16*sizes.Length;
            for(int i=0;i<sizes.Length;i++){w.Write((byte)(sizes[i]==256?0:sizes[i]));w.Write((byte)(sizes[i]==256?0:sizes[i]));w.Write((byte)0);w.Write((byte)0);w.Write((ushort)1);w.Write((ushort)32);w.Write(data[i].Length);w.Write(offset);offset+=data[i].Length;}
            foreach(var bytes in data)w.Write(bytes);
        }
    }
    static void Big(Stream stream,int n){stream.WriteByte((byte)(n>>24));stream.WriteByte((byte)(n>>16));stream.WriteByte((byte)(n>>8));stream.WriteByte((byte)n);}
    static void Tag(Stream stream,string s){foreach(char c in s)stream.WriteByte((byte)c);}
    static void Main(string[] args){
        string dir=args[0];Directory.CreateDirectory(dir);
        foreach(int size in new[]{32,48,64,128,256,512,1024})File.WriteAllBytes(Path.Combine(dir,"cqs-"+size+".png"),Png(size,false,false));
        File.WriteAllBytes(Path.Combine(dir,"tray-template.png"),Png(32,true,false));
        Ico(Path.Combine(dir,"cqs.ico"),false,false);Ico(Path.Combine(dir,"tray-light.ico"),true,false);Ico(Path.Combine(dir,"tray-dark.ico"),true,true);
        using(var body=new MemoryStream()){
            string[] tags={"icp4","icp5","icp6","ic07","ic08","ic09","ic10"};int[] sizes={16,32,64,128,256,512,1024};
            for(int i=0;i<sizes.Length;i++){var bytes=Png(sizes[i],false,false);Tag(body,tags[i]);Big(body,bytes.Length+8);body.Write(bytes,0,bytes.Length);}
            using(var file=File.Create(Path.Combine(dir,"cqs.icns"))){Tag(file,"icns");Big(file,(int)body.Length+8);body.Position=0;body.CopyTo(file);}
        }
        Console.WriteLine("Brand PNG/ICO/ICNS and monochrome tray assets generated.");
    }
}
