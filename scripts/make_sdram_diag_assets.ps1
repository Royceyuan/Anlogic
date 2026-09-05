param(
    [Parameter(Mandatory = $true)] [ValidateSet(960, 1280)] [int] $Width,
    [Parameter(Mandatory = $true)] [ValidateSet(540, 720)] [int] $Height,
    [Parameter(Mandatory = $true)] [string] $OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# The RTL checker uses this exact, address-derived RGB565 pattern.  It makes
# every 64-pixel tile obvious, keeps one/two-pixel features in the raster, and
# does not require storing a full golden frame in FPGA block RAM.
$source = @'
using System;
using System.IO;
using System.Security.Cryptography;

public static class SdramDiagAsset
{
    static ushort Pixel(int x, int y)
    {
        if ((x & 63) == 0 || (y & 63) == 0) return 0xffff;
        if ((x & 15) == 1 || (y & 15) == 1) return 0x0000;
        int r = (x ^ (y << 1)) & 31;
        int g = (y ^ (x >> 2)) & 63;
        int b = (x ^ y) & 31;
        return (ushort)((r << 11) | (g << 5) | b);
    }

    static uint[] CrcTable()
    {
        uint[] t = new uint[256];
        for (uint i = 0; i < 256; ++i) {
            uint c = i;
            for (int b = 0; b < 8; ++b) c = (c & 1) != 0 ? 0xedb88320u ^ (c >> 1) : c >> 1;
            t[i] = c;
        }
        return t;
    }

    static uint Crc32(byte[] data)
    {
        uint c = 0xffffffffu; uint[] t = CrcTable();
        foreach (byte b in data) c = t[(c ^ b) & 255] ^ (c >> 8);
        return c ^ 0xffffffffu;
    }

    static void U16(byte[] a, int o, ushort v) { a[o] = (byte)v; a[o + 1] = (byte)(v >> 8); }
    static void U32(byte[] a, int o, uint v) { for (int i = 0; i < 4; ++i) a[o + i] = (byte)(v >> (8 * i)); }

    public static string Create(int width, int height, string directory)
    {
        Directory.CreateDirectory(directory);
        int stride = ((width * 3) + 3) & ~3;
        byte[] bmp = new byte[54 + stride * height];
        bmp[0] = (byte)'B'; bmp[1] = (byte)'M';
        U32(bmp, 2, (uint)bmp.Length); U32(bmp, 10, 54); U32(bmp, 14, 40);
        U32(bmp, 18, (uint)width); U32(bmp, 22, unchecked((uint)-height));
        U16(bmp, 26, 1); U16(bmp, 28, 24); U32(bmp, 34, (uint)(stride * height));

        byte[] rgb565 = new byte[width * height * 2];
        byte[] words = new byte[width * height * 2];
        for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
            ushort p = Pixel(x, y);
            int bo = 54 + y * stride + x * 3;
            bmp[bo] = (byte)((p & 31) << 3);
            bmp[bo + 1] = (byte)(((p >> 5) & 63) << 2);
            bmp[bo + 2] = (byte)(((p >> 11) & 31) << 3);
            int po = (y * width + x) * 2;
            rgb565[po] = (byte)(p >> 8); rgb565[po + 1] = (byte)p;
        }
        for (int word = 0; word < width * height / 2; ++word) {
            Buffer.BlockCopy(rgb565, word * 4, words, word * 4, 4);
        }
        string stem = "sdram_diag_" + width + "x" + height;
        File.WriteAllBytes(Path.Combine(directory, stem + ".bmp"), bmp);
        using (StreamWriter w = new StreamWriter(Path.Combine(directory, stem + ".rgb565_words.hex")))
            for (int i = 0; i < words.Length; i += 4)
                w.WriteLine("{0:X2}{1:X2}{2:X2}{3:X2}", words[i], words[i + 1], words[i + 2], words[i + 3]);
        string bmpHash;
        using (SHA256 sha = SHA256.Create()) bmpHash = BitConverter.ToString(sha.ComputeHash(bmp)).Replace("-", "");
        string wordHash;
        using (SHA256 sha = SHA256.Create()) wordHash = BitConverter.ToString(sha.ComputeHash(words)).Replace("-", "");
        return String.Format("{{\"width\":{0},\"height\":{1},\"top_down\":true,\"bpp\":24,\"words\":{2},\"blocks128\":{3},\"bmp_sha256\":\"{4}\",\"rgb565_words_sha256\":\"{5}\",\"rgb565_crc32\":\"{6:X8}\"}}", width, height, width * height / 2, width * height / 256, bmpHash, wordHash, Crc32(words));
    }
}
'@

Add-Type -TypeDefinition $source -Language CSharp
$out = [System.IO.Path]::GetFullPath($OutputDirectory)
$manifest = [SdramDiagAsset]::Create($Width, $Height, $out)
$stem = "sdram_diag_${Width}x${Height}"
[System.IO.File]::WriteAllText((Join-Path $out "$stem.manifest.json"), $manifest + [Environment]::NewLine)
Write-Host "Created $stem BMP, RGB565 word golden, and manifest in $out"
