// sample.swift — comprehensive Swift syntax fixture for parser testing.
// Covers: structs, classes, protocols, extensions, generics, opaque types,
// property wrappers, async/await, actors, result builders, pattern matching,
// keyPaths, error handling, closures, @discardableResult, sendable.

import Foundation

// -------------------------------------------------------------------------- //
// Constants & type aliases
// -------------------------------------------------------------------------- //

let maxRetries = 3
let defaultTimeout: TimeInterval = 30
typealias UUID = Foundation.UUID
typealias Handler<T> = (Result<T, Error>) -> Void

// -------------------------------------------------------------------------- //
// Enums with associated values
// -------------------------------------------------------------------------- //

enum Status: String, CaseIterable, Sendable {
    case pending = "pending"
    case running = "running"
    case done    = "done"
    case failed  = "failed"

    var isTerminal: Bool { self == .done || self == .failed }
}

enum AppError: LocalizedError {
    case notFound(resource: String, id: String)
    case validation(field: String, detail: String)
    case network(statusCode: Int, url: URL)
    case wrapped(Error)

    var errorDescription: String? {
        switch self {
        case .notFound(let r, let id):         return "\(r) with id='\(id)' not found"
        case .validation(let f, let d):        return "\(f): \(d)"
        case .network(let code, let url):      return "HTTP \(code) from \(url)"
        case .wrapped(let e):                  return e.localizedDescription
        }
    }
}

// -------------------------------------------------------------------------- //
// Protocols
// -------------------------------------------------------------------------- //

protocol Entity {
    var id: UUID { get }
    var createdAt: Date { get }
}

protocol Repository<Element>: Actor where Element: Entity {
    associatedtype Element
    func findById(_ id: UUID) async throws -> Element
    func list() async throws -> [Element]
    func save(_ entity: Element) async throws -> Element
    func delete(_ id: UUID) async throws
}

protocol Validatable {
    var validationErrors: [String] { get }
    var isValid: Bool { get }
}

extension Validatable {
    var isValid: Bool { validationErrors.isEmpty }
}

// -------------------------------------------------------------------------- //
// Structs
// -------------------------------------------------------------------------- //

struct Point: Hashable, Sendable, CustomStringConvertible {
    let x: Double
    let y: Double

    static let origin = Point(x: 0, y: 0)

    func distance(to other: Point) -> Double {
        sqrt(pow(x - other.x, 2) + pow(y - other.y, 2))
    }

    static func + (lhs: Point, rhs: Point) -> Point {
        Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func * (lhs: Point, rhs: Double) -> Point {
        Point(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    var description: String { "(\(x), \(y))" }
}

struct User: Entity, Validatable, Sendable {
    let id: UUID
    let createdAt: Date
    var name: String
    var email: String
    var role: String

    init(name: String, email: String, role: String = "member") {
        self.id = UUID()
        self.createdAt = Date()
        self.name = name
        self.email = email
        self.role = role
    }

    var validationErrors: [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("name is required") }
        if !email.contains("@") { errors.append("email '\(email)' is invalid") }
        return errors
    }
}

// -------------------------------------------------------------------------- //
// Property wrappers
// -------------------------------------------------------------------------- //

@propertyWrapper
struct Clamped<T: Comparable> {
    private var value: T
    let range: ClosedRange<T>

    init(wrappedValue: T, _ range: ClosedRange<T>) {
        self.range = range
        self.value = min(max(wrappedValue, range.lowerBound), range.upperBound)
    }

    var wrappedValue: T {
        get { value }
        set { value = min(max(newValue, range.lowerBound), range.upperBound) }
    }
}

@propertyWrapper
struct Trimmed {
    private var value: String = ""

    var wrappedValue: String {
        get { value }
        set { value = newValue.trimmingCharacters(in: .whitespaces) }
    }

    init(wrappedValue: String) { self.wrappedValue = wrappedValue }
}

struct Config {
    @Clamped(0...65535) var port: Int = 8080
    @Trimmed var host: String = "localhost"

    var baseURL: String { "http://\(host):\(port)" }
}

// -------------------------------------------------------------------------- //
// Generics & opaque types
// -------------------------------------------------------------------------- //

func zip<A, B>(_ a: [A], _ b: [B]) -> [(A, B)] {
    zip(a, b).map { ($0, $1) }
}

func reduce<T, U>(_ sequence: [T], initial: U, combine: (U, T) -> U) -> U {
    sequence.reduce(initial, combine)
}

func makeAdder(_ n: Int) -> some Numeric & Sendable { n }

// -------------------------------------------------------------------------- //
// Extensions
// -------------------------------------------------------------------------- //

extension Array where Element: Comparable {
    var median: Element? {
        guard !isEmpty else { return nil }
        return sorted()[count / 2]
    }
}

extension String {
    var isValidEmail: Bool { contains("@") && contains(".") }

    func camelToSnake() -> String {
        let pattern = "([A-Z])"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(startIndex..., in: self)
        return regex?
            .stringByReplacingMatches(in: self, range: range, withTemplate: "_$1")
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "_")) ?? self
    }
}

extension Sequence {
    func groupBy<Key: Hashable>(_ keyFn: (Element) -> Key) -> [Key: [Element]] {
        reduce(into: [:]) { $0[keyFn($1), default: []].append($1) }
    }
}

// -------------------------------------------------------------------------- //
// Actors
// -------------------------------------------------------------------------- //

actor MemoryStore<T: Entity & Sendable>: Repository {
    private var store: [UUID: T] = [:]

    func findById(_ id: UUID) async throws -> T {
        guard let entity = store[id] else { throw AppError.notFound(resource: "Entity", id: id.uuidString) }
        return entity
    }

    func list() async throws -> [T] { Array(store.values) }

    func save(_ entity: T) async throws -> T {
        store[entity.id] = entity
        return entity
    }

    func delete(_ id: UUID) async throws { store.removeValue(forKey: id) }
}

// -------------------------------------------------------------------------- //
// Async / await
// -------------------------------------------------------------------------- //

func fetchJSON<T: Decodable>(url: URL) async throws -> T {
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        throw AppError.network(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, url: url)
    }
    return try JSONDecoder().decode(T.self, from: data)
}

func withRetry<T>(
    attempts: Int = maxRetries,
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?
    for attempt in 0..<attempts {
        do { return try await operation() }
        catch { lastError = error; try await Task.sleep(nanoseconds: UInt64(100_000_000) << attempt) }
    }
    throw lastError!
}

// -------------------------------------------------------------------------- //
// Result builders
// -------------------------------------------------------------------------- //

@resultBuilder
struct ArrayBuilder<T> {
    static func buildBlock(_ components: T...) -> [T] { components }
    static func buildOptional(_ component: [T]?) -> [T] { component ?? [] }
    static func buildEither(first: [T]) -> [T] { first }
    static func buildEither(second: [T]) -> [T] { second }
}

func makeList<T>(@ArrayBuilder<T> build: () -> [T]) -> [T] { build() }

// -------------------------------------------------------------------------- //
// Pattern matching
// -------------------------------------------------------------------------- //

func classify(_ value: Any) -> String {
    switch value {
    case let n as Int where n < 0:     return "negative int"
    case let n as Int:                 return "non-negative int \(n)"
    case let s as String where s.isEmpty: return "empty string"
    case let s as String:              return "string(\(s))"
    case let p as Point where p == .origin: return "origin"
    case let p as Point:               return "point\(p)"
    case is [Any]:                     return "array"
    default:                           return "unknown(\(type(of: value)))"
    }
}

// -------------------------------------------------------------------------- //
// KeyPaths
// -------------------------------------------------------------------------- //

func pluck<T, V>(_ keyPath: KeyPath<T, V>) -> (T) -> V {
    { $0[keyPath: keyPath] }
}

// -------------------------------------------------------------------------- //
// Fibonacci using sequence
// -------------------------------------------------------------------------- //

let fibonacci = sequence(state: (0, 1)) { state -> Int in
    let value = state.0
    state = (state.1, state.0 + state.1)
    return value
}

// -------------------------------------------------------------------------- //
// Entry point
// -------------------------------------------------------------------------- //

let user = User(name: "Alice", email: "alice@example.com")
print(user.isValid)

let fibs = Array(fibonacci.prefix(10))
print(fibs)

let p = Point(x: 3, y: 4)
print(p.distance(to: .origin))

var cfg = Config()
cfg.port = 70000  // clamped to 65535
print(cfg.baseURL)

let items = makeList { 1; 2; 3 }
print(items)
