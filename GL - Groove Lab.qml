import MuseScore 3.0
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

MuseScore {
    menuPath: "Plugins.GL: Groove Lab"
    description: "GL: Groove Lab. Cria acordes a partir da nota ou cifra selecionada e aplica levadas/viradas editadas no GL Maker. Desenvolvido pelo professor Glauber Santiago - UFSCar."
    version: "3.0"
    requiresScore: true
    pluginType: "dialog"

    width: 430
    height: 760

    property string statusText: "Selecione uma cabeça de nota, escolha sua função e clique em um acorde ou levada."
    property int referenceDegreeIndex: 0
    property bool autoVoicingEnabled: false
    property int autoVoicingLowPitch: 55
    property int autoVoicingHighPitch: 71

    property var naturalPc: [0, 2, 4, 5, 7, 9, 11]
    property var naturalTpc: [14, 16, 18, 13, 15, 17, 19]
    property var degreeSteps: [0, 2, 4, 6]
    property var degreeNames: ["fundamental", "terça", "quinta", "sétima"]

    function isNote(e) { return e && e.type === Element.NOTE; }
    function isChord(e) { return e && e.type === Element.CHORD; }
    function mod(n, m) { return ((n % m) + m) % m; }
    function normalizeAccidental(diff) { diff = mod(diff, 12); if (diff > 6) diff -= 12; return diff; }

    function tpcInfo(tpc) {
        for (var letter = 0; letter < 7; letter++) {
            var delta = tpc - naturalTpc[letter];
            if (delta % 7 === 0) return { letter: letter, accidental: delta / 7 };
        }
        return { letter: 0, accidental: 0 };
    }

    function pcFromTpc(tpc) {
        var info = tpcInfo(tpc);
        return mod(naturalPc[info.letter] + info.accidental, 12);
    }

    function tpcMatchesPitch(tpc, pitch) {
        if (tpc === undefined || tpc === null) return false;
        return pcFromTpc(tpc) === mod(pitch, 12);
    }

    function displayedTpc(note) {
        if (note && note.tpc !== undefined && tpcMatchesPitch(note.tpc, note.pitch)) return note.tpc;
        if (note && note.tpc1 !== undefined && tpcMatchesPitch(note.tpc1, note.pitch)) return note.tpc1;
        if (note && note.tpc2 !== undefined && tpcMatchesPitch(note.tpc2, note.pitch)) return note.tpc2;
        return spellPcAsLetter(note.pitch, 0);
    }

    function spellPcAsLetter(pc, letter) {
        pc = mod(pc, 12);
        letter = mod(letter, 7);
        var accidental = normalizeAccidental(pc - naturalPc[letter]);
        return naturalTpc[letter] + accidental * 7;
    }

    function forceNoteSpelling(note, tpc) {
        note.tpc1 = tpc;
        note.tpc2 = tpc;
        if (note.tpc !== undefined) note.tpc = tpc;
    }

    function fitPitchToAutoVoicingRange(pitch) {
        if (!autoVoicingEnabled) return pitch;
        while (pitch < autoVoicingLowPitch) pitch += 12;
        while (pitch > autoVoicingHighPitch) pitch -= 12;
        return pitch;
    }

    function applyAutoVoicingToChord(chord) {
        if (!autoVoicingEnabled || !chord) return 0;
        var changed = 0;
        for (var i = 0; i < chord.notes.length; i++) {
            var note = chord.notes[i];
            var originalPitch = note.pitch;
            var originalTpc = displayedTpc(note);
            var adjustedPitch = fitPitchToAutoVoicingRange(originalPitch);
            if (adjustedPitch !== originalPitch) {
                note.pitch = adjustedPitch;
                forceNoteSpelling(note, originalTpc);
                changed++;
            }
        }
        return changed;
    }

    function makeNote(pitch, tpc) {
        var note = newElement(Element.NOTE);
        note.pitch = pitch;
        forceNoteSpelling(note, tpc);
        return note;
    }

    function chordHasPitch(chord, pitch) {
        for (var i = 0; i < chord.notes.length; i++) if (chord.notes[i].pitch === pitch) return true;
        return false;
    }

    function highestNote(chord) {
        if (!chord || chord.notes.length === 0) return null;
        var best = chord.notes[0];
        for (var i = 1; i < chord.notes.length; i++) if (chord.notes[i].pitch > best.pitch) best = chord.notes[i];
        return best;
    }

    function selectedReferenceNotes() {
        var refs = [];
        var elements = curScore.selection.elements;
        for (var i = 0; i < elements.length; i++) {
            var e = elements[i];
            if (isNote(e)) refs.push(e);
            else if (isChord(e)) {
                var n = highestNote(e);
                if (n) refs.push(n);
            }
        }
        if (refs.length === 0) {
            var cursor = curScore.newCursor();
            cursor.rewind(1);
            if (cursor.element) {
                if (isNote(cursor.element)) refs.push(cursor.element);
                else if (isChord(cursor.element)) {
                    var fallback = highestNote(cursor.element);
                    if (fallback) refs.push(fallback);
                }
            }
        }
        return refs;
    }

    function buildChord(label, intervals) {
        if (!curScore) { statusText = "Nenhuma partitura aberta."; return; }
        if (referenceDegreeIndex >= intervals.length) {
            statusText = "Para " + label + ", a nota selecionada não pode ser a " + degreeNames[referenceDegreeIndex] + ".";
            return;
        }
        var refs = selectedReferenceNotes();
        if (refs.length === 0) { statusText = "Nenhuma nota selecionada. Selecione uma cabeça de nota."; return; }
        curScore.startCmd();
        var added = 0;
        for (var r = 0; r < refs.length; r++) {
            var refNote = refs[r];
            var chord = refNote.parent;
            if (!chord) continue;
            var refTpc = displayedTpc(refNote);
            var refInfo = tpcInfo(refTpc);
            var rootPitch = refNote.pitch - intervals[referenceDegreeIndex];
            var rootLetter = mod(refInfo.letter - degreeSteps[referenceDegreeIndex], 7);
            for (var i = 0; i < intervals.length; i++) {
                var rawTargetPitch = rootPitch + intervals[i];
                var finalTargetPitch = fitPitchToAutoVoicingRange(rawTargetPitch);
                if (chordHasPitch(chord, rawTargetPitch) || chordHasPitch(chord, finalTargetPitch)) continue;
                var targetLetter = mod(rootLetter + degreeSteps[i], 7);
                var targetTpc = spellPcAsLetter(rawTargetPitch, targetLetter);
                var newNote = makeNote(finalTargetPitch, targetTpc);
                chord.add(newNote);
                forceNoteSpelling(newNote, targetTpc);
                added++;
            }
            applyAutoVoicingToChord(chord);
        }
        curScore.endCmd();
        statusText = added > 0 ? label + " criado/adaptado. Notas adicionadas: " + added + (autoVoicingEnabled ? ". Auto voicing: sol3-si4." : ".") : "Nada foi adicionado; as notas do acorde já existiam" + (autoVoicingEnabled ? ". Auto voicing aplicado: sol3-si4." : ".");
    }

    function noteSortAscending(a, b) { return a.pitch - b.pitch; }

    function getSegmentHarmony(segment) {
        if (!segment || !segment.annotations) return null;
        var aCount = 0;
        var annotation = segment.annotations[aCount];
        while (annotation) {
            if (annotation.type === Element.HARMONY) return annotation;
            annotation = segment.annotations[++aCount];
        }
        return null;
    }

    function selectedHarmonyElement() {
        var elements = curScore.selection.elements;
        for (var i = 0; i < elements.length; i++) {
            var e = elements[i];
            if (e && e.type === Element.HARMONY) return e;
            if (e && e.segment) {
                var hFromElementSegment = getSegmentHarmony(e.segment);
                if (hFromElementSegment) return hFromElementSegment;
            }
            if (e && e.parent && e.parent.segment) {
                var hFromParentSegment = getSegmentHarmony(e.parent.segment);
                if (hFromParentSegment) return hFromParentSegment;
            }
        }

        var cursor = curScore.newCursor();
        cursor.rewind(1);
        if (cursor.segment) {
            var hFromCursor = getSegmentHarmony(cursor.segment);
            if (hFromCursor) return hFromCursor;
        }

        return null;
    }

    function textFromHarmony(harmony) {
        if (!harmony) return "";
        if (harmony.text !== undefined && harmony.text !== null) return "" + harmony.text;
        if (harmony.plainText !== undefined && harmony.plainText !== null) return "" + harmony.plainText;
        return "";
    }

    function pitchClassFromLetterName(name) {
        var s = ("" + name).toUpperCase();
        if (s === "C") return 0;
        if (s === "D") return 2;
        if (s === "E") return 4;
        if (s === "F") return 5;
        if (s === "G") return 7;
        if (s === "A") return 9;
        if (s === "B" || s === "H") return 11;
        return 0;
    }

    function normalizeHarmonyText(text) {
        return ("" + text).replace("♯", "#").replace("♭", "b").replace("Δ", "maj").replace("ø", "m7b5").replace("º", "dim").replace("°", "dim");
    }

    function parseRootFromHarmonyText(text) {
        text = normalizeHarmonyText(text);
        var i = 0;
        while (i < text.length && text.charAt(i) === " ") i++;
        if (i >= text.length) return null;
        var letterName = text.charAt(i).toUpperCase();
        if (letterName === "H") letterName = "B";
        var letter = "CDEFGAB".indexOf(letterName);
        if (letter < 0) return null;
        i++;
        var accidental = "";
        if (i < text.length) {
            var a = text.charAt(i);
            if (a === "#" || a === "b" || a === "x") {
                accidental = a;
                i++;
                if (i < text.length && text.charAt(i) === a && a !== "x") { accidental += a; i++; }
            }
        }
        var pc = pitchClassFromLetterName(letterName);
        if (accidental === "#") pc += 1;
        else if (accidental === "##" || accidental === "x") pc += 2;
        else if (accidental === "b") pc -= 1;
        else if (accidental === "bb") pc -= 2;
        return { pc: mod(pc, 12), letter: letter, suffix: text.substring(i) };
    }

    function stripParentheses(text) {
        var out = "";
        var depth = 0;
        for (var i = 0; i < text.length; i++) {
            var ch = text.charAt(i);
            if (ch === "(") { depth++; continue; }
            if (ch === ")") { if (depth > 0) depth--; continue; }
            if (depth === 0) out += ch;
        }
        return out;
    }

    function intervalsFromHarmonySuffix(suffix) {
        suffix = normalizeHarmonyText(suffix);
        var slash = suffix.indexOf("/");
        if (slash >= 0) suffix = suffix.substring(0, slash);
        suffix = stripParentheses(suffix).split(" ").join("");
        var lower = suffix.toLowerCase();
        var isMinor = lower.indexOf("min") >= 0 || lower.indexOf("-") >= 0 || (lower.charAt(0) === "m" && lower.indexOf("maj") !== 0);
        var isHalfDim = lower.indexOf("m7b5") >= 0 || lower.indexOf("0") >= 0;
        var isDim = lower.indexOf("dim") >= 0 || lower.indexOf("o") >= 0;
        var isAug = lower.indexOf("aug") >= 0 || lower.indexOf("+") >= 0;
        var isSus2 = lower.indexOf("sus2") >= 0;
        var isSus4 = lower.indexOf("sus") >= 0 && !isSus2;
        var hasMaj7 = lower.indexOf("maj7") >= 0 || lower.indexOf("ma7") >= 0 || lower.indexOf("maj") >= 0;
        var has7 = lower.indexOf("7") >= 0;
        var has6 = lower.indexOf("6") >= 0;
        var hasAdd9 = lower.indexOf("add9") >= 0 || lower.indexOf("9") >= 0;

        var intervals;
        if (isHalfDim) intervals = [0, 3, 6, 10];
        else if (isDim && has7) intervals = [0, 3, 6, 9];
        else if (isDim) intervals = [0, 3, 6];
        else if (isSus2) intervals = [0, 2, 7];
        else if (isSus4) intervals = [0, 5, 7];
        else if (isAug) intervals = [0, 4, 8];
        else if (isMinor) intervals = [0, 3, 7];
        else intervals = [0, 4, 7];

        if (hasMaj7 && intervals.indexOf(11) < 0) intervals.push(11);
        else if (has7 && intervals.indexOf(10) < 0 && !isDim) intervals.push(10);
        else if (has6 && intervals.indexOf(9) < 0) intervals.push(9);
        if (hasAdd9 && intervals.indexOf(14) < 0) intervals.push(14);
        return intervals;
    }

    function notesFromHarmony(harmony) {
        var text = textFromHarmony(harmony);
        var rootData = parseRootFromHarmonyText(text);
        if (!rootData && harmony.rootTpc !== undefined) {
            var info = tpcInfo(harmony.rootTpc);
            rootData = { pc: pcFromTpc(harmony.rootTpc), letter: info.letter, suffix: text };
        }
        if (!rootData) return [];

        var intervals = intervalsFromHarmonySuffix(rootData.suffix);
        var rootPitch = 60 + rootData.pc;
        if (rootPitch > 66) rootPitch -= 12;

        var notes = [];
        var degreeLetters = [0, 2, 4, 6, 1, 3, 5];
        for (var i = 0; i < intervals.length; i++) {
            var rawPitch = rootPitch + intervals[i];
            var finalPitch = fitPitchToAutoVoicingRange(rawPitch);
            var targetLetter = mod(rootData.letter + degreeLetters[i], 7);
            var targetTpc = spellPcAsLetter(rawPitch, targetLetter);
            notes.push({ pitch: finalPitch, tpc: targetTpc });
        }
        notes.sort(noteSortAscending);
        return notes;
    }

    function selectedChordContext() {
        var preferredHarmony = selectedHarmonyElement();
        if (preferredHarmony) {
            var preferredNotes = notesFromHarmony(preferredHarmony);
            if (preferredNotes && preferredNotes.length > 0) {
                var preferredTrack = 0;
                if (preferredHarmony.track !== undefined) preferredTrack = preferredHarmony.track;
                else if (preferredHarmony.staffIdx !== undefined) preferredTrack = preferredHarmony.staffIdx * 4;
                var preferredStaffIdx = Math.floor(preferredTrack / 4);
                var preferredVoice = preferredTrack % 4;
                if (preferredHarmony.staffIdx !== undefined) preferredStaffIdx = preferredHarmony.staffIdx;
                var preferredTick = -1;
                if (preferredHarmony.tick !== undefined && preferredHarmony.tick >= 0) preferredTick = preferredHarmony.tick;
                else if (preferredHarmony.parent && preferredHarmony.parent.tick !== undefined) preferredTick = preferredHarmony.parent.tick;
                if (preferredTick < 0) {
                    var phc = curScore.newCursor();
                    phc.rewind(1);
                    preferredTick = phc.tick;
                    if (phc.track !== undefined) {
                        preferredTrack = phc.track;
                        preferredStaffIdx = Math.floor(preferredTrack / 4);
                        preferredVoice = preferredTrack % 4;
                    }
                }
                if (preferredTick >= 0) return { notes: preferredNotes, tick: preferredTick, track: preferredTrack, staffIdx: preferredStaffIdx, voice: preferredVoice, source: "cifra" };
            }
        }

        var refs = selectedReferenceNotes();
        if (refs.length > 0) {
            var ref = refs[0];
            var chord = ref.parent;
            if (!chord || !chord.notes || chord.notes.length === 0) return null;
            var result = [];
            for (var i = 0; i < chord.notes.length; i++) {
                var n = chord.notes[i];
                result.push({ pitch: n.pitch, tpc: displayedTpc(n) });
            }
            result.sort(noteSortAscending);
            var track = 0;
            if (chord.track !== undefined) track = chord.track;
            else if (ref.track !== undefined) track = ref.track;
            else {
                var staffFallback = chord.staffIdx !== undefined ? chord.staffIdx : 0;
                var voiceFallback = chord.voice !== undefined ? chord.voice : 0;
                track = staffFallback * 4 + voiceFallback;
            }
            var staffIdx = Math.floor(track / 4);
            var voice = track % 4;
            if (chord.staffIdx !== undefined) staffIdx = chord.staffIdx;
            if (chord.voice !== undefined) voice = chord.voice;
            var tick = -1;
            if (chord.tick !== undefined && chord.tick >= 0) tick = chord.tick;
            else if (chord.parent && chord.parent.tick !== undefined) tick = chord.parent.tick;
            else if (ref.tick !== undefined && ref.tick >= 0) tick = ref.tick;
            if (tick < 0) {
                var c = curScore.newCursor();
                c.rewind(1);
                tick = c.tick;
                if (c.track !== undefined) {
                    track = c.track;
                    staffIdx = Math.floor(track / 4);
                    voice = track % 4;
                }
            }
            if (tick < 0) return null;
            return { notes: result, tick: tick, track: track, staffIdx: staffIdx, voice: voice, source: "nota/acorde" };
        }

    }

    function setupCursorAt(cursor, ctx, tick) {
        if (cursor.staffIdx !== undefined) cursor.staffIdx = ctx.staffIdx;
        if (cursor.voice !== undefined) cursor.voice = ctx.voice;
        cursor.track = ctx.track;
        cursor.rewindToTick(tick);
        if (cursor.staffIdx !== undefined) cursor.staffIdx = ctx.staffIdx;
        if (cursor.voice !== undefined) cursor.voice = ctx.voice;
        cursor.track = ctx.track;
    }

    function prepareGrooveCursor(ctx) {
        var cursor = curScore.newCursor();
        setupCursorAt(cursor, ctx, ctx.tick);
        return cursor;
    }

    function forceChordSpellingAt(ctx, tick, notes) {
        var cursor = curScore.newCursor();
        setupCursorAt(cursor, ctx, tick);
        if (!cursor.element || cursor.element.type !== Element.CHORD) return;
        var chord = cursor.element;
        if (!chord.notes) return;
        var used = [];
        for (var i = 0; i < notes.length; i++) used.push(false);
        for (var c = 0; c < chord.notes.length; c++) {
            var cn = chord.notes[c];
            var match = -1;
            for (var j = 0; j < notes.length; j++) {
                if (!used[j] && notes[j].pitch === cn.pitch) { match = j; break; }
            }
            if (match < 0 && c < notes.length) match = c;
            if (match >= 0 && match < notes.length) {
                forceNoteSpelling(cn, notes[match].tpc);
                used[match] = true;
            }
        }
    }

    function insertChordAtCursor(cursor, ctx, notes, z, n) {
        if (!notes || notes.length === 0) return false;
        var startTick = cursor.tick;
        cursor.setDuration(z, n);
        cursor.addNote(notes[0].pitch, false);
        for (var i = 1; i < notes.length; i++) {
            setupCursorAt(cursor, ctx, startTick);
            cursor.setDuration(z, n);
            cursor.addNote(notes[i].pitch, true);
        }
        forceChordSpellingAt(ctx, startTick, notes);
        setupCursorAt(cursor, ctx, startTick);
        cursor.next();
        return true;
    }

    function insertRestAtCursor(cursor, ctx, z, n) {
        cursor.setDuration(z, n);
        cursor.addRest();
    }

    function generateGroove(label, pattern) {
        if (!curScore) { statusText = "Nenhuma partitura aberta."; return; }
        var ctx = selectedChordContext();
        if (!ctx || !ctx.notes || ctx.notes.length === 0) {
            statusText = "Selecione uma nota do acorde já gerado para aplicar a levada.";
            return;
        }
        var cursor = prepareGrooveCursor(ctx);
        if (!cursor) { statusText = "Não consegui criar o cursor da levada."; return; }
        curScore.startCmd();
        var chordsInserted = 0;
        var restsInserted = 0;
        for (var i = 0; i < pattern.length; i++) {
            var ev = pattern[i];
            if (ev.kind === "rest") { insertRestAtCursor(cursor, ctx, ev.z, ev.n); restsInserted++; }
            else { insertChordAtCursor(cursor, ctx, ctx.notes, ev.z, ev.n); chordsInserted++; }
        }
        curScore.endCmd();
        statusText = label + ": " + chordsInserted + " acordes, " + restsInserted + " pausas. Início: nota/acorde selecionado.";
    }

    function generateBossa441Groove0() {
        generateGroove("Bossa 4/4 1", [
            { kind: "chord", z: 1, n: 4 },
            { kind: "chord", z: 1, n: 4 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 4 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 4 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 4 },
            { kind: "chord", z: 1, n: 4 }
        ]);
    }

    function generateBossa442Groove1() {
        generateGroove("Bossa 4/4 2", [
            { kind: "rest", z: 1, n: 4 },
            { kind: "chord", z: 1, n: 4 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 4 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 4 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 2 }
        ]);
    }

    function generateBossa241Groove2() {
        generateGroove("Bossa 2/4 1", [
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 16 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 16 },
            { kind: "rest", z: 1, n: 16 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 16 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 }
        ]);
    }

    function generateBossa242Groove3() {
        generateGroove("Bossa 2/4 2", [
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 16 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 16 },
            { kind: "rest", z: 1, n: 16 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 16 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 }
        ]);
    }

    function generateBossa243Groove4() {
        generateGroove("Bossa 2/4 3", [
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 16 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 16 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 16 },
            { kind: "chord", z: 1, n: 16 },
            { kind: "rest", z: 1, n: 4 }
        ]);
    }

    function generateSwing1Groove5() {
        generateGroove("Swing 1", [
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 4 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 }
        ]);
    }

    function generateSwing2Groove6() {
        generateGroove("Swing 2", [
            { kind: "chord", z: 1, n: 2 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 4 }
        ]);
    }

    function generateSwing3Groove7() {
        generateGroove("Swing 3", [
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 4 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 2 }
        ]);
    }

    function generateSwing4Groove8() {
        generateGroove("Swing 4", [
            { kind: "chord", z: 1, n: 4 },
            { kind: "chord", z: 1, n: 4 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 }
        ]);
    }

    function generateSwing5Groove9() {
        generateGroove("Swing 5", [
            { kind: "rest", z: 1, n: 4 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 2 }
        ]);
    }

    function generateRock1Groove10() {
        generateGroove("Rock 1", [
            { kind: "chord", z: 1, n: 2 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 4 }
        ]);
    }

    function generateRock2Groove11() {
        generateGroove("Rock 2", [
            { kind: "rest", z: 1, n: 4 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 4 },
            { kind: "chord", z: 1, n: 4 }
        ]);
    }

    function generateContratempoGroove12() {
        generateGroove("Contratempo", [
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 }
        ]);
    }

    function generateColcheiasGroove13() {
        generateGroove("Colcheias", [
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 }
        ]);
    }

    function generateMinimaGroove14() {
        generateGroove("Mínima", [
            { kind: "chord", z: 1, n: 2 },
            { kind: "rest", z: 1, n: 2 }
        ]);
    }

    function generateSemibreveGroove15() {
        generateGroove("Semibreve", [
            { kind: "chord", z: 1, n: 1 }
        ]);
    }

    function generateLevadaEm34Groove16() {
        generateGroove("Levada em 3/4", [
            { kind: "chord", z: 3, n: 8 },
            { kind: "chord", z: 3, n: 8 }
        ]);
    }

    function generateLevadaEm68Groove17() {
        generateGroove("Levada em 6/8", [
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 }
        ]);
    }

    function generateLevadaEm98Groove18() {
        generateGroove("Levada em 9/8", [
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 16 },
            { kind: "chord", z: 1, n: 16 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 }
        ]);
    }

    function generateLevadaEm128Groove19() {
        generateGroove("Levada em 12/8", [
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 8 },
            { kind: "chord", z: 1, n: 8 },
            { kind: "rest", z: 1, n: 2 },
            { kind: "rest", z: 1, n: 4 }
        ]);
    }

    Rectangle {
        anchors.fill: parent
        color: "#ECECEC"

        ScrollView {
            id: scrollArea
            anchors.fill: parent
            anchors.margins: 6
            clip: true
            contentWidth: availableWidth
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: scrollArea.availableWidth
                spacing: 5

            Label { text: "GL: Groove Lab"; font.bold: true; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter }
            Label { text: "A nota selecionada é:"; font.bold: true; Layout.fillWidth: true }

            GridLayout {
                columns: 2
                Layout.fillWidth: true
                columnSpacing: 5
                rowSpacing: 5
                Button { text: "Fundamental"; checkable: true; checked: referenceDegreeIndex === 0; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; Layout.preferredHeight: 29; onClicked: referenceDegreeIndex = 0 }
                Button { text: "Terça"; checkable: true; checked: referenceDegreeIndex === 1; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; Layout.preferredHeight: 29; onClicked: referenceDegreeIndex = 1 }
                Button { text: "Quinta"; checkable: true; checked: referenceDegreeIndex === 2; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; Layout.preferredHeight: 29; onClicked: referenceDegreeIndex = 2 }
                Button { text: "Sétima"; checkable: true; checked: referenceDegreeIndex === 3; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; Layout.preferredHeight: 29; onClicked: referenceDegreeIndex = 3 }
            }

            Rectangle { height: 1; color: "#D0D0D0"; Layout.fillWidth: true }
            Button { text: autoVoicingEnabled ? "Auto voicing ON (G3-B4)" : "Auto voicing OFF"; checkable: true; checked: autoVoicingEnabled; font.pixelSize: 9; font.bold: true; Layout.fillWidth: true; Layout.preferredHeight: 30; onClicked: autoVoicingEnabled = checked }
            Label { text: "Move por oitavas para caber em G3-B4."; wrapMode: Text.WordWrap; font.pixelSize: 9; color: "#666"; Layout.fillWidth: true }
            Rectangle { height: 1; color: "#D0D0D0"; Layout.fillWidth: true }

            Button { text: "X"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; Layout.preferredHeight: 29; onClicked: buildChord("X", [0, 4, 7]) }
            Button { text: "Xm"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; Layout.preferredHeight: 29; onClicked: buildChord("Xm", [0, 3, 7]) }
            Button { text: "Xmaj7"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; Layout.preferredHeight: 29; onClicked: buildChord("Xmaj7", [0, 4, 7, 11]) }
            Button { text: "X7"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; Layout.preferredHeight: 29; onClicked: buildChord("X7", [0, 4, 7, 10]) }
            Button { text: "Xm7"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; Layout.preferredHeight: 29; onClicked: buildChord("Xm7", [0, 3, 7, 10]) }
            Button { text: "Xm7(b5)"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; Layout.preferredHeight: 29; onClicked: buildChord("Xm7(b5)", [0, 3, 6, 10]) }
            Button { text: "Xdim7"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; Layout.preferredHeight: 29; onClicked: buildChord("Xdim7", [0, 3, 6, 9]) }

            Rectangle { height: 1; color: "#D0D0D0"; Layout.fillWidth: true }
            Label { text: "Levadas e Viradas"; font.bold: true; Layout.fillWidth: true }
            Label { text: "A lista rola verticalmente; os estilos aparecem em duas colunas para caberem mesmo quando houver muitos."; wrapMode: Text.WordWrap; font.pixelSize: 8; color: "#666"; Layout.fillWidth: true }

            GridLayout {
                columns: 2
                Layout.fillWidth: true
                columnSpacing: 5
                rowSpacing: 5

            Button {
                text: "Bossa 4/4 1"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateBossa441Groove0()
            }

            Button {
                text: "Bossa 4/4 2"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateBossa442Groove1()
            }

            Button {
                text: "Bossa 2/4 1"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateBossa241Groove2()
            }

            Button {
                text: "Bossa 2/4 2"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateBossa242Groove3()
            }

            Button {
                text: "Bossa 2/4 3"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateBossa243Groove4()
            }

            Button {
                text: "Swing 1"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateSwing1Groove5()
            }

            Button {
                text: "Swing 2"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateSwing2Groove6()
            }

            Button {
                text: "Swing 3"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateSwing3Groove7()
            }

            Button {
                text: "Swing 4"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateSwing4Groove8()
            }

            Button {
                text: "Swing 5"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateSwing5Groove9()
            }

            Button {
                text: "Rock 1"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateRock1Groove10()
            }

            Button {
                text: "Rock 2"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateRock2Groove11()
            }

            Button {
                text: "Contratempo"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateContratempoGroove12()
            }

            Button {
                text: "Colcheias"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateColcheiasGroove13()
            }

            Button {
                text: "Mínima"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateMinimaGroove14()
            }

            Button {
                text: "Semibreve"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateSemibreveGroove15()
            }

            Button {
                text: "Levada em 3/4"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateLevadaEm34Groove16()
            }

            Button {
                text: "Levada em 6/8"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateLevadaEm68Groove17()
            }

            Button {
                text: "Levada em 9/8"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateLevadaEm98Groove18()
            }

            Button {
                text: "Levada em 12/8"
                font.pixelSize: 9
                font.bold: true
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                onClicked: generateLevadaEm128Groove19()
            }
            }

            Item { height: 8 }
            Label { text: statusText; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 9; color: "#555"; Layout.fillWidth: true; Layout.alignment: Qt.AlignHCenter }
            Rectangle { height: 1; color: "#D0D0D0"; Layout.fillWidth: true }
            Label { text: "Desenvolvido pelo professor Glauber Santiago - UFSCar\nservidores.ufscar.br/glauber/ • sites.google.com/view/glauberia"; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 8; color: "#666"; Layout.fillWidth: true; Layout.alignment: Qt.AlignHCenter }
            }
        }
    }
}
