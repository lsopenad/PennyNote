import Foundation
import SwiftData

// Lo aprendido de los gastos de los últimos 12 meses para las sugerencias inteligentes del formulario:
// un gasto por título (el más reciente) y en qué categorías y métodos de pago sale cada palabra de los
// títulos. Se calcula una vez al abrir el formulario.
struct ExpenseSuggestionIndex {
    static let historyMonths = 12
    static let minimumQueryLength = 2
    static let maximumSuggestions = 3
    // Una palabra deduce una categoría (o un método de pago) si sale en al menos 2 gastos y más del 60 %
    // de ellos son de esa categoría. Las palabras de menos de 3 letras y los números no cuentan.
    static let minimumWordOccurrences = 2
    static let minimumWordShare = 0.6
    static let minimumWordLength = 3
    // Peso de cada gasto en el orden de las sugerencias: se reduce a la mitad cada 60 días, para que
    // ganen los títulos frecuentes y recientes.
    static let recencyHalfLife: TimeInterval = 60 * 86_400

    private struct Entry {
        let suggestion: ExpenseSuggestion
        let key: String
        let wordStarts: [String.Index]

        // Alguna palabra del título empieza por lo escrito.
        func matches(_ query: String) -> Bool {
            wordStarts.contains { key[$0...].hasPrefix(query) }
        }
    }

    // Cuántos gastos con una palabra hay de cada categoría y de cada método de pago.
    private struct WordStats {
        var occurrences = 0
        var categoryCounts: [UUID: Int] = [:]
        var paymentMethodCounts: [PaymentMethod: Int] = [:]
    }

    // Del más usado al menos usado.
    private let entries: [Entry]
    private let entriesByKey: [String: Entry]
    private let wordStats: [String: WordStats]
    private let categoriesByID: [UUID: ExpenseCategory]

    init(expenses: [Expense], now: Date = .now) {
        let start = Self.historyStart(now: now)
        var latest: [String: Expense] = [:]
        var scores: [String: Double] = [:]
        var wordStats: [String: WordStats] = [:]
        var categoriesByID: [UUID: ExpenseCategory] = [:]

        for expense in expenses where !expense.isSoftDeleted && expense.date >= start {
            let key = Self.normalized(expense.title)
            guard !key.isEmpty else { continue }

            if latest[key].map({ Self.isMoreRecent(expense, than: $0) }) ?? true {
                latest[key] = expense
            }
            let age = max(0, now.timeIntervalSince(expense.date))
            scores[key, default: 0] += pow(0.5, age / Self.recencyHalfLife)

            for word in Set(Self.words(in: key)) {
                wordStats[word, default: WordStats()].occurrences += 1
                if let category = expense.category {
                    wordStats[word]?.categoryCounts[category.id, default: 0] += 1
                    categoriesByID[category.id] = category
                }
                wordStats[word]?.paymentMethodCounts[expense.paymentMethod, default: 0] += 1
            }
        }

        let ranked = latest.sorted { lhs, rhs in
            let lhsScore = scores[lhs.key] ?? 0
            let rhsScore = scores[rhs.key] ?? 0
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            if lhs.value.date != rhs.value.date { return lhs.value.date > rhs.value.date }
            return lhs.key < rhs.key
        }
        entries = ranked.map { key, expense in
            Entry(
                suggestion: ExpenseSuggestion(
                    id: key,
                    title: expense.title,
                    amount: expense.amount,
                    category: expense.category,
                    paymentMethod: expense.paymentMethod
                ),
                key: key,
                wordStarts: Self.wordStarts(in: key)
            )
        }
        entriesByKey = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0) })
        self.wordStats = wordStats
        self.categoriesByID = categoriesByID
    }

    // Lee los gastos de los últimos 12 meses que tienen título.
    static func load(context: ModelContext, now: Date = .now) -> ExpenseSuggestionIndex {
        let start = historyStart(now: now)
        var descriptor = FetchDescriptor<Expense>(predicate: #Predicate { expense in
            !expense.isSoftDeleted && expense.date >= start && !expense.title.isEmpty
        })
        descriptor.relationshipKeyPathsForPrefetching = [\.category]
        let expenses = context.fetchOrEmpty(descriptor, failureMessage: "No se han podido leer los gastos para las sugerencias")
        return ExpenseSuggestionIndex(expenses: expenses, now: now)
    }

    // Los gastos anteriores cuyo título tiene alguna palabra que empieza por lo escrito, los más usados
    // primero. Hacen falta al menos 2 letras.
    func suggestions(matching text: String) -> [ExpenseSuggestion] {
        let query = Self.normalized(text)
        guard query.count >= Self.minimumQueryLength else { return [] }

        var result: [ExpenseSuggestion] = []
        for entry in entries where entry.matches(query) {
            result.append(entry.suggestion)
            if result.count == Self.maximumSuggestions { break }
        }
        return result
    }

    // La parte de un título que coincide con lo escrito, para resaltarla: la primera palabra que empieza
    // por ello, con las mismas reglas que `suggestions(matching:)`.
    static func matchedRange(of text: String, in title: String) -> Range<String.Index>? {
        let query = normalized(text)
        guard query.count >= minimumQueryLength else { return nil }
        for start in wordStarts(in: title) {
            if let range = title.range(of: query, options: [.anchored, .caseInsensitive, .diacriticInsensitive, .widthInsensitive], range: start..<title.endIndex) {
                return range
            }
        }
        return nil
    }

    // Categoría y método de pago para un título. Si ya hay gastos con ese mismo título se usan los del más
    // reciente; si no, los que deducen sus palabras, sumando los votos de cada una. Un empate no deduce nada.
    func prediction(for title: String) -> ExpenseFieldPrediction {
        let key = Self.normalized(title)
        guard !key.isEmpty else { return .none }

        // Un título conocido manda aunque se guardara sin categoría: es lo que el usuario hace con él.
        if let exactMatch = entriesByKey[key]?.suggestion {
            return ExpenseFieldPrediction(category: exactMatch.category, paymentMethod: exactMatch.paymentMethod)
        }

        var categoryVotes: [UUID: Int] = [:]
        var paymentMethodVotes: [PaymentMethod: Int] = [:]
        for word in Set(Self.words(in: key)) {
            guard let stats = wordStats[word], stats.occurrences >= Self.minimumWordOccurrences else { continue }
            if let (id, count) = Self.dominant(stats.categoryCounts, of: stats.occurrences) {
                categoryVotes[id, default: 0] += count
            }
            if let (method, count) = Self.dominant(stats.paymentMethodCounts, of: stats.occurrences) {
                paymentMethodVotes[method, default: 0] += count
            }
        }

        return ExpenseFieldPrediction(
            category: Self.winner(of: categoryVotes).flatMap { categoriesByID[$0] },
            paymentMethod: Self.winner(of: paymentMethodVotes)
        )
    }

    // Sin distinguir mayúsculas, tildes ni espacios repetidos: «Café  Bar» y «cafe bar» son el mismo título.
    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func historyStart(now: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: -historyMonths, to: now) ?? now
    }

    private static func isMoreRecent(_ expense: Expense, than other: Expense) -> Bool {
        expense.date != other.date ? expense.date > other.date : expense.createdAt > other.createdAt
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }

    // Las palabras que sirven para deducir: con al menos 3 caracteres y alguna letra.
    private static func words(in key: String) -> [String] {
        let parts: [Substring] = key.split { !isWordCharacter($0) }
        return parts
            .filter { $0.count >= minimumWordLength && $0.contains { $0.isLetter } }
            .map(String.init)
    }

    // Dónde empieza cada palabra del título, para buscar por inicio de palabra.
    private static func wordStarts(in key: String) -> [String.Index] {
        var starts: [String.Index] = []
        var previous: Character?
        for index in key.indices {
            let character = key[index]
            if index == key.startIndex || (isWordCharacter(character) && !(previous.map(isWordCharacter) ?? false)) {
                starts.append(index)
            }
            previous = character
        }
        return starts
    }

    // El valor que reúne más del 60 % de los gastos con la palabra, con cuántos son.
    private static func dominant<Value: Hashable>(_ counts: [Value: Int], of total: Int) -> (Value, Int)? {
        guard let (value, count) = counts.max(by: { $0.value < $1.value }),
              Double(count) / Double(total) > minimumWordShare else { return nil }
        return (value, count)
    }

    private static func winner<Value: Hashable>(of votes: [Value: Int]) -> Value? {
        guard let best = votes.values.max() else { return nil }
        let leaders = votes.filter { $0.value == best }
        return leaders.count == 1 ? leaders.first?.key : nil
    }
}
