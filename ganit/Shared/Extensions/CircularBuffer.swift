import Foundation

// MARK: - Circular Buffer

/// Fixed-size ring buffer for signal data. Prevents unbounded memory growth
/// when signal providers emit faster than the aggregator consumes.
///
/// ```
/// [_, _, _, _, _]  capacity=5
///        ^write
///
/// After 7 inserts: oldest 2 overwritten
/// [6, 7, 3, 4, 5]
///     ^write
/// ```
struct CircularBuffer<Element> {
    private var storage: [Element?]
    private var writeIndex: Int = 0
    private(set) var count: Int = 0
    let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    /// Append an element. Overwrites oldest if full.
    mutating func append(_ element: Element) {
        storage[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        count = min(count + 1, capacity)
    }

    /// All elements in insertion order (oldest first).
    var elements: [Element] {
        guard count > 0 else { return [] }
        if count < capacity {
            return storage.prefix(count).compactMap { $0 }
        }
        // Full buffer: read from writeIndex (oldest) to writeIndex-1 (newest)
        let tail = storage[writeIndex...].compactMap { $0 }
        let head = storage[..<writeIndex].compactMap { $0 }
        return tail + head
    }

    /// Most recent element.
    var last: Element? {
        guard count > 0 else { return nil }
        let lastIndex = (writeIndex - 1 + capacity) % capacity
        return storage[lastIndex]
    }

    /// Remove all elements.
    mutating func removeAll() {
        storage = Array(repeating: nil, count: capacity)
        writeIndex = 0
        count = 0
    }

    var isEmpty: Bool { count == 0 }
}

// MARK: - Codable Conformance (when Element is Codable)

extension CircularBuffer: Codable where Element: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let items = try container.decode([Element].self)
        self.capacity = max(items.count, 60)
        self.storage = items.map { Optional($0) } + Array(repeating: nil, count: max(0, capacity - items.count))
        self.writeIndex = items.count % capacity
        self.count = items.count
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(elements)
    }
}
