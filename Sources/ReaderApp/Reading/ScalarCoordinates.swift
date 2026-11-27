import Foundation

/// Maps exact UTF-16 boundaries to the Core chapter's Unicode scalar space.
struct ScalarCoordinates: Sendable {
    let text: String
    private let boundaries: [Int]

    init(_ text: String) {
        self.text = text
        var offsets = [0]
        offsets.reserveCapacity(text.unicodeScalars.count + 1)
        for scalar in text.unicodeScalars {
            offsets.append(offsets[offsets.count - 1] + (scalar.value > 0xFFFF ? 2 : 1))
        }
        boundaries = offsets
    }

    var scalarCount: Int { boundaries.count - 1 }
    var utf16Count: Int { boundaries[boundaries.count - 1] }

    func utf16(at scalar: Int) -> Int? {
        guard boundaries.indices.contains(scalar) else { return nil }
        return boundaries[scalar]
    }

    func scalar(at utf16: Int) -> Int? {
        let found = precedingScalar(utf16: utf16)
        return boundaries[found] == utf16 ? found : nil
    }

    func precedingScalar(utf16: Int) -> Int {
        var lower = 0
        var upper = boundaries.count
        while lower + 1 < upper {
            let middle = lower + (upper - lower) / 2
            if boundaries[middle] <= utf16 { lower = middle }
            else { upper = middle }
        }
        return lower
    }

    func string(_ range: Range<Int>) -> String? {
        guard let start = utf16(at: range.lowerBound), let end = utf16(at: range.upperBound) else { return nil }
        return (text as NSString).substring(with: NSRange(location: start, length: end - start))
    }
}
