package midi

import std.collection.*

public class NoteInfo {
    public var pitch: UInt8
    public var durationTicks: UInt32

    public init(pitch: UInt8, durationTicks: UInt32) {
        this.pitch = pitch
        this.durationTicks = durationTicks
    }
}

public class ChordInfo {
    public var pitches: ArrayList<UInt8>
    public var durationTicks: UInt32

    public init(pitches: ArrayList<UInt8>, durationTicks: UInt32) {
        this.pitches = pitches
        this.durationTicks = durationTicks
    }
}

public enum MusicElement {
    | SingleNote(NoteInfo)
    | Chord(ChordInfo)
    | Rest(UInt32)
}

public class TrackData {
    public var name: String
    public var instrument: Int64
    public var elements: ArrayList<MusicElement>

    public init(name: String) {
        this.name = name
        this.instrument = -1
        this.elements = ArrayList<MusicElement>()
    }
}

public class ScoreData {
    public var tempo: Int64
    public var tracks: ArrayList<TrackData>

    public init() {
        this.tempo = 120
        this.tracks = ArrayList<TrackData>()
    }
}

class MusicParser {
    let text: String
    var pos: Int64
    let size: Int64
    let variables: HashMap<String, ArrayList<MusicElement>>

    init(text: String) {
        this.text = text
        this.pos = 0
        this.size = text.size
        this.variables = HashMap<String, ArrayList<MusicElement>>()
    }

    func parse(): ScoreData {
        let score = ScoreData()
        while (true) {
            skipWhitespace()
            if (eof()) { break }
            let ident = parseIdentifier()
            if (ident == "") {
                pos += 1
                continue
            }
            if (ident == "tempo") {
                score.tempo = parseIntValue(120)
                continue
            }
            if (ident == "let") {
                parseLet()
                continue
            }
            if (ident == "track") {
                score.tracks.add(parseTrack())
                continue
            }
        }
        if (score.tracks.size == 0) {
            score.tracks.add(TrackData("default"))
        }
        return score
    }

    func parseLet(): Unit {
        skipWhitespace()
        let name = parseIdentifier()
        skipWhitespace()
        if (!consumeChar(61)) { return }
        skipWhitespace()
        let elements = parseBlockElements()
        variables[name] = elements
    }

    func parseTrack(): TrackData {
        skipWhitespace()
        let name = parseIdentifier()
        let track = TrackData(if (name == "") { "track" } else { name })
        skipWhitespace()
        if (!consumeChar(123)) { return track }
        while (true) {
            skipWhitespace()
            if (eof()) { break }
            if (peekChar() == 125) {
                pos += 1
                break
            }
            let ident = tryPeekIdentifier()
            if (ident == "instrument") {
                let _ = parseIdentifier()
                skipWhitespace()
                track.instrument = instrumentNumber(parseInstrumentName())
                continue
            }
            if (ident == "tempo") {
                let _ = parseIdentifier()
                let _ = parseIntValue(120)
                continue
            }
            if (ident == "velocity" || ident == "channel" || ident == "cc" || ident == "pitch_bend") {
                let cmd = parseIdentifier()
                skipUnknownTrackCommand(cmd)
                continue
            }
            parseOneElementInto(track.elements)
        }
        return track
    }

    func parseBlockElements(): ArrayList<MusicElement> {
        let result = ArrayList<MusicElement>()
        if (!consumeChar(123)) { return result }
        while (true) {
            skipWhitespace()
            if (eof()) { break }
            if (peekChar() == 125) {
                pos += 1
                break
            }
            parseOneElementInto(result)
        }
        return result
    }

    func parseOneElementInto(out: ArrayList<MusicElement>): Unit {
        skipWhitespace()
        if (eof()) { return }
        let ch = peekChar()
        if (ch == 91) {
            out.add(MusicElement.Chord(parseChord()))
            return
        }
        if (ch == 95) {
            out.add(MusicElement.Rest(parseRestTicks()))
            return
        }
        if (isNoteLetter(ch)) {
            let note = parseNoteWithDuration()
            if (note.pitch <= 127) {
                out.add(MusicElement.SingleNote(note))
            }
            return
        }
        if (isIdentStart(ch)) {
            let name = parseIdentifier()
            if (variables.contains(name)) {
                appendElements(out, variables[name])
            }
            return
        }
        pos += 1
    }

    func appendElements(dst: ArrayList<MusicElement>, src: ArrayList<MusicElement>): Unit {
        for (element in src) {
            dst.add(element)
        }
    }

    func parseChord(): ChordInfo {
        let pitches = ArrayList<UInt8>()
        let _ = consumeChar(91)
        while (true) {
            skipWhitespace()
            if (eof()) { break }
            if (peekChar() == 93) {
                pos += 1
                break
            }
            let pitch = parsePitchOnly()
            if (pitch >= 0 && pitch <= 127) {
                pitches.add(UInt8(pitch))
            } else {
                if (!eof()) { pos += 1 }
            }
        }
        let ticks = parseDurationSpec()
        return ChordInfo(pitches, ticks)
    }

    func parseRestTicks(): UInt32 {
        let _ = consumeChar(95)
        return parseDurationSpec()
    }

    func parseNoteWithDuration(): NoteInfo {
        let pitch = parsePitchOnly()
        let ticks = parseDurationSpec()
        if (pitch < 0) {
            return NoteInfo(60, ticks)
        }
        return NoteInfo(UInt8(pitch), ticks)
    }

    func parsePitchOnly(): Int64 {
        if (eof()) { return -1 }
        let letter = peekChar()
        let base = basePitch(letter)
        if (base < 0) { return -1 }
        pos += 1
        var offset: Int64 = 0
        if (!eof()) {
            let ch = peekChar()
            if (ch == 35) {
                offset = 1
                pos += 1
            } else if (ch == 98) {
                offset = -1
                pos += 1
            }
        }
        let octave = parseIntValue(-1000)
        if (octave == -1000) { return -1 }
        return (octave + 1) * 12 + base + offset
    }

    func parseDurationSpec(): UInt32 {
        skipWhitespace()
        if (!consumeChar(58)) { return 480 }
        skipWhitespace()
        if (!eof() && peekChar() == 84) {
            pos += 1
            return UInt32(parseIntValue(480))
        }
        let value = parseIntValue(4)
        var ticks = durationToTicks(value)
        if (!eof() && peekChar() == 46) {
            pos += 1
            ticks = UInt32(Int64(ticks) + Int64(ticks) / 2)
        }
        return ticks
    }

    func parseInstrumentName(): String {
        skipWhitespace()
        if (eof()) { return "piano" }
        if (peekChar() == 34) {
            pos += 1
            let start = pos
            while (!eof() && peekChar() != 34) {
                pos += 1
            }
            let name = text[start..pos]
            if (!eof()) { pos += 1 }
            return name
        }
        return parseIdentifier()
    }

    func skipUnknownTrackCommand(cmd: String): Unit {
        if (cmd == "cc" || cmd == "pitch_bend") {
            let _ = parseIntValue(0)
            let _ = parseIntValue(0)
        } else {
            let _ = parseIntValue(0)
        }
    }

    func parseIntValue(defaultValue: Int64): Int64 {
        skipWhitespace()
        let start = pos
        var sign: Int64 = 1
        if (!eof() && peekChar() == 45) {
            sign = -1
            pos += 1
        }
        var found = false
        var value: Int64 = 0
        while (!eof() && isDigit(peekChar())) {
            value = value * 10 + (peekChar() - 48)
            pos += 1
            found = true
        }
        if (!found) {
            pos = start
            return defaultValue
        }
        return value * sign
    }

    func parseIdentifier(): String {
        skipWhitespace()
        if (eof() || !isIdentStart(peekChar())) { return "" }
        let start = pos
        pos += 1
        while (!eof() && isIdentChar(peekChar())) {
            pos += 1
        }
        return text[start..pos]
    }

    func tryPeekIdentifier(): String {
        let saved = pos
        let value = parseIdentifier()
        pos = saved
        return value
    }

    func skipWhitespace(): Unit {
        while (!eof()) {
            let ch = peekChar()
            if (ch == 32 || ch == 9 || ch == 10 || ch == 13) {
                pos += 1
            } else {
                break
            }
        }
    }

    func consumeChar(ch: Int64): Bool {
        skipWhitespace()
        if (!eof() && peekChar() == ch) {
            pos += 1
            return true
        }
        return false
    }

    func peekChar(): Int64 {
        return Int64(text[pos])
    }

    func eof(): Bool {
        return pos >= size
    }
}

func basePitch(ch: Int64): Int64 {
    if (ch == 67) { return 0 }
    if (ch == 68) { return 2 }
    if (ch == 69) { return 4 }
    if (ch == 70) { return 5 }
    if (ch == 71) { return 7 }
    if (ch == 65) { return 9 }
    if (ch == 66) { return 11 }
    return -1
}

func instrumentNumber(name: String): Int64 {
    let lower = name.toAsciiLower()
    if (lower == "piano") { return 0 }
    if (lower == "bright_piano") { return 1 }
    if (lower == "music_box") { return 10 }
    if (lower == "church_organ") { return 19 }
    if (lower == "guitar") { return 24 }
    if (lower == "steel_guitar") { return 25 }
    if (lower == "bass") { return 33 }
    if (lower == "violin") { return 40 }
    if (lower == "cello") { return 42 }
    if (lower == "strings") { return 48 }
    if (lower == "trumpet") { return 56 }
    if (lower == "tuba") { return 58 }
    if (lower == "french_horn") { return 60 }
    if (lower == "saxophone") { return 65 }
    if (lower == "flute") { return 73 }
    if (lower == "whistle") { return 78 }
    if (lower == "sitar") { return 104 }
    if (lower == "steel_drums") { return 114 }
    if (lower == "woodblock") { return 115 }
    return 0
}

func durationToTicks(duration: Int64): UInt32 {
    if (duration <= 0) { return 480 }
    return UInt32(480 * 4 / duration)
}

func isDigit(ch: Int64): Bool {
    return ch >= 48 && ch <= 57
}

func isNoteLetter(ch: Int64): Bool {
    return ch == 65 || ch == 66 || ch == 67 || ch == 68 || ch == 69 || ch == 70 || ch == 71
}

func isIdentStart(ch: Int64): Bool {
    return (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122) || ch == 95
}

func isIdentChar(ch: Int64): Bool {
    return isIdentStart(ch) || isDigit(ch)
}

func stripComment(line: String): String {
    let runes = line.toRuneArray()
    let size = runes.size
    var i: Int64 = 0
    let sb = StringBuilder()
    while (i < size) {
        if (i + 1 < size && runes[i] == r'/' && runes[i + 1] == r'/') {
            break
        }
        sb.append(runes[i])
        i++
    }
    return sb.toString()
}

func preprocessInput(input: String): String {
    let lines = input.split("\n")
    let sb = StringBuilder()
    for (line in lines) {
        sb.append(stripComment(line))
        sb.append("\n")
    }
    return sb.toString()
}

public func parseScore(input: String): ScoreData {
    let parser = MusicParser(preprocessInput(input))
    return parser.parse()
}


