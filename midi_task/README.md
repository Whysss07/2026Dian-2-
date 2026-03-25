# 🎵 MIDI 简易乐谱语言

这是一个用仓颉实现的文本转 MIDI 小工具。你可以用简洁的文本语法描述旋律、和弦和多轨编配，再生成 `.mid` 文件进行播放。

## 项目结构

```text
Base/
├── cjpm.toml           # 项目配置
├── README.md           # 使用说明
├── src/
│   ├── main.cj         # 程序入口
│   ├── midi_event.cj   # MIDI 事件类型定义
│   ├── parser.cj       # 文本乐谱解析器
│   ├── encoder.cj      # MIDI 二进制编码器
│   └── verifier.cj     # MIDI 文件验证工具
└── test.txt            # 示例乐谱
```

## 构建运行

```bash
cjpm run --run-args ./test.txt
```

执行后会在输入文件同目录下生成同名 `.mid` 文件，例如 `test.txt` 会生成 `test.mid`。

## 当前统一语法说明

下面的语法说明已经和 `src/parser.cj` 当前实现保持一致。

### 1. 关键字

当前解析器识别的关键字为：

- `tempo`
- `let`
- `track`
- `instrument`

> 注意：关键字请使用小写。

### 2. 总体结构

一个乐谱文件通常由以下部分组成：

```text
tempo <bpm>

let <name> = {
    ...片段内容...
}

track <name> {
    instrument <name>
    ...音符 / 和弦 / 休止符 / 变量引用...
}
```

### 3. 音符写法

单音使用下面的格式：

```text
<音名>[升降号]<八度>:<时值>
```

例如：

- `C4:4`：中央 C，四分音符
- `F#4:8`：升 F，八分音符
- `Bb3:2`：降 B，二分音符

说明：

- 音名使用大写：`A B C D E F G`
- 升号使用 `#`
- 降号使用 `b`
- 八度示例：`C4`、`A3`
- 时值写在冒号后面

### 4. 时值写法

当前支持的时值包括：

- `:1` = 全音符
- `:2` = 二分音符
- `:4` = 四分音符
- `:8` = 八分音符
- `:16` = 十六分音符

还支持两种扩展写法：

- 附点：`C4:4.`
- 直接写 ticks：`C4:T720`

其中 `T` 必须是大写。

### 5. 休止符

休止符使用下划线 `_` 表示：

```text
_:4
```

示例：

- `_:4`：四分休止符
- `_:2`：二分休止符
- `_:8`：八分休止符

### 6. 和弦

和弦把多个音高写在方括号里，统一跟一个时值：

```text
[C4 E4 G4]:2
```

示例：

- `[C4 E4 G4]:2`
- `[D4 F#4 A4]:4`
- `[C3 G3 C4]:1`

### 7. 变量片段

可以先用 `let` 定义一个片段，再在轨道中重复引用：

```text
let motif = {
    C4:4 D4:4 E4:4 _:4
}

track melody {
    instrument piano
    motif
    motif
}
```

适合复用前奏、节奏型、固定低音等内容。

### 8. 多轨写法

每个轨道必须写成带花括号的块结构：

```text
track melody {
    instrument piano
    C4:4 D4:4 E4:4 F4:4
}

track harmony {
    instrument strings
    [C3 E3 G3]:2 [F3 A3 C4]:2
}
```

当前实现中：

- 单轨时输出 MIDI Format 0
- 多轨时输出 MIDI Format 1
- 各轨道会自动分配 MIDI channel
- 会跳过鼓组常用的 channel 10（索引 9）

### 9. 注释

支持 `//` 注释：

```text
// 整行注释
C4:4 D4:4 // 行尾注释
```

### 10. 最小可运行示例

```text
tempo 120

let intro = {
    C4:4 D4:4 E4:4 F4:4
}

track melody {
    instrument piano
    intro
    G4:4 A4:4 B4:4 C5:2
}

track bassline {
    instrument bass
    C2:2 G2:2
    A2:2 G2:2
}
```

保存为 `demo.txt` 后执行：

```bash
cjpm run --run-args ./demo.txt
```

程序会生成 `demo.mid`。

## 当前 `test.txt` 示例

仓库中的 `test.txt` 已统一为当前语法，可直接运行。

## 当前内置乐器名

目前内置了以下乐器名映射：

- `piano`
- `bright_piano`
- `music_box`
- `church_organ`
- `guitar`
- `steel_guitar`
- `bass`
- `violin`
- `cello`
- `strings`
- `trumpet`
- `tuba`
- `french_horn`
- `saxophone`
- `flute`
- `whistle`
- `sitar`
- `steel_drums`
- `woodblock`

未命中的乐器名会回退到 `piano`。

## 当前已支持能力

- 文本乐谱转 MIDI 文件
- 单音、和弦、休止符
- 多轨编排
- 全局 `tempo`
- 轨道 `instrument`
- 片段变量 `let`
- 附点时值
- 直接 ticks 时值
- `file:///` 路径输入

## 已知限制

当前版本还有这些限制：

- `velocity`、`channel`、`cc`、`pitch_bend` 会被解析器识别，但暂未真正编码进 MIDI
- `track` 内写 `tempo` 目前不会覆盖全局速度
- 轨道名暂未写入 MIDI Track Name 元事件
- 目前建议关键字使用小写、音名使用大写
- 暂未支持拍号、调号、连音、力度曲线、歌词等更完整的乐谱能力

## 后续可扩展方向

1. 为 parser 和 encoder 补充更多自动化测试
2. 真正支持 `velocity / channel / cc / pitch_bend`
3. 增加 Track Name、Time Signature、Key Signature 等 Meta Event
4. 扩充更多 General MIDI 乐器别名
5. 提供更友好的语法错误提示