import Foundation

/// Core already ran the user's rules. Swift's standard CollectionDifference
/// supplies the edit script; the Host only carries those confirmed text edits
/// into the platform DOM while retaining its original semantic ancestors.
enum ReaderEbookTextEdits {
    struct Edit: Codable, Equatable {
        let startScalar: UInt64
        let endScalar: UInt64
        let text: String
    }

    static func changes(original: String, processed: String) throws -> [Edit] {
        guard original != processed else { return [] }
        let maximumDifferenceScalars = 32_768
        var sourceWindow = original.unicodeScalars[...]
        var targetWindow = processed.unicodeScalars[...]
        var scalarBase = 0
        if sourceWindow.count > maximumDifferenceScalars || targetWindow.count > maximumDifferenceScalars {
            // A long chapter can differ only at a trimmed boundary. Compare
            // the shared text in place before allocating the bounded diff.
            scalarBase = zip(sourceWindow, targetWindow).prefix { $0.0 == $0.1 }.count
            sourceWindow = sourceWindow.dropFirst(scalarBase)
            targetWindow = targetWindow.dropFirst(scalarBase)
            let commonSuffix = zip(sourceWindow.reversed(), targetWindow.reversed()).prefix { $0.0 == $0.1 }.count
            sourceWindow = sourceWindow.dropLast(commonSuffix)
            targetWindow = targetWindow.dropLast(commonSuffix)
        }
        guard sourceWindow.count <= maximumDifferenceScalars, targetWindow.count <= maximumDifferenceScalars else {
            throw ReaderEbookError.resourceLimit
        }
        let source = Array(sourceWindow)
        let target = Array(targetWindow)
        let difference = target.difference(from: source)
        guard difference.count <= 100_000 else { throw ReaderEbookError.resourceLimit }
        var removals: Set<Int> = []
        var insertions: Set<Int> = []
        for change in difference {
            switch change {
            case .remove(let offset, _, _): removals.insert(offset)
            case .insert(let offset, _, _): insertions.insert(offset)
            }
        }
        var edits: [Edit] = []
        var old = 0
        var new = 0
        while old < source.count || new < target.count {
            if removals.contains(old) || insertions.contains(new) {
                let start = old
                let targetStart = new
                while old < source.count, removals.contains(old) { old += 1 }
                while new < target.count, insertions.contains(new) { new += 1 }
                let text = target[targetStart..<new].map(String.init).joined()
                // A new image needs a real Core resource identity. Never show
                // an inserted object-replacement character as a fake picture.
                guard !text.unicodeScalars.contains(where: { $0.value == 0xfffc }) else {
                    throw ReaderEbookError.positionMismatch
                }
                edits.append(Edit(startScalar: UInt64(scalarBase + start), endScalar: UInt64(scalarBase + old), text: text))
            } else {
                guard old < source.count, new < target.count, source[old] == target[new] else {
                    throw ReaderEbookError.positionMismatch
                }
                old += 1
                new += 1
            }
        }
        return edits
    }
}
