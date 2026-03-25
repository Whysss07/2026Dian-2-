package midi

import std.fs.*

// ============================================================
// MIDI 音乐生成器 — 入口
// ============================================================

// 处理单个 midi 源文件，生成同目录下的 .mid 文件
func processFile(srcPath: Path): Unit {
    let bytes = File.readFrom(srcPath)
    let input = String.fromUtf8(bytes)
    let data = generate(input)
    let parent = srcPath.parent.toString()
    let baseName = srcPath.fileNameWithoutExtension
    let outPath = Path(parent).join("${baseName}.mid")
    saveMidiFile(outPath.toString(), data)
    println("  ✓ ${srcPath} -> ${outPath}")
}

// 处理路径：文件则生成单个 .mid，目录则生成目录下所有 .txt 对应的 .mid
func process(path: String): Unit {
    let p = Path(path)
    if (!exists(p)) {
        println("错误: 路径不存在: ${path}")
        return
    }
    let info = FileInfo(p)
    if (info.isDirectory()) {
        println("处理目录: ${path}")
        let entries = Directory.readFrom(p)
        var count: Int64 = 0
        for (entry in entries) {
            if (entry.name.endsWith(".txt")) {
                try {
                    processFile(p.join(entry.name))
                    count++
                } catch (e: Exception) {
                    println("  ✗ ${entry.name}: ${e}")
                }
            }
        }
        println("完成: ${count} 个文件已生成")
    } else {
        println("处理文件: ${path}")
        try {
            processFile(p)
        } catch (e: Exception) {
            println("  ✗ ${path}: ${e}")
        }
    }
}

// 主入口
main(args: Array<String>) {
    if (args.size > 0) {
        for (arg in args) {
            process(arg)
        }
    }
}
