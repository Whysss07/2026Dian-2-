package midi

import std.collection.*
import std.fs.*

func hexValue(ch: Int64): Int64 {
    if (ch >= 48 && ch <= 57) { return ch - 48 }
    if (ch >= 65 && ch <= 70) { return ch - 55 }
    if (ch >= 97 && ch <= 102) { return ch - 87 }
    return -1
}

func decodePercentUtf8(text: String): String {
    var bytes = ArrayList<UInt8>()
    var i: Int64 = 0
    while (i < text.size) {
        let ch = Int64(text[i])
        if (ch == 37 && i + 2 < text.size) {
            let h1 = hexValue(Int64(text[i + 1]))
            let h2 = hexValue(Int64(text[i + 2]))
            if (h1 >= 0 && h2 >= 0) {
                bytes.add(UInt8(h1 * 16 + h2))
                i += 3
                continue
            }
        }
        bytes.add(UInt8(ch))
        i += 1
    }
    return String.fromUtf8(bytes.toArray())
}

func normalizeInputArg(arg: String): String {
    if (arg.startsWith("file:///")) {
        let body = decodePercentUtf8(arg[8..arg.size])
        var out = ArrayList<UInt8>()
        for (b in body.toArray()) {
            if (b == 47) {
                out.add(92)
            } else {
                out.add(b)
            }
        }
        return String.fromUtf8(out.toArray())
    }
    return arg
}

func outputPathFor(srcPath: Path): Path {
    let parentText = srcPath.parent.toString()
    let baseName = srcPath.fileNameWithoutExtension
    if (parentText == "") {
        return Path("${baseName}.mid")
    }
    return srcPath.parent.join("${baseName}.mid")
}

func processFile(srcPath: Path): Unit {
    let input = String.fromUtf8(File.readFrom(srcPath))
    let data = generate(input)
    let outPath = outputPathFor(srcPath)
    saveMidiFile(outPath.toString(), data)
    println("done")
}

main(args: Array<String>) {
    if (args.size == 0) {
        println("usage: midi <file.txt>")
        return
    }
    let path = normalizeInputArg(args[0])
    processFile(Path(path))
}


