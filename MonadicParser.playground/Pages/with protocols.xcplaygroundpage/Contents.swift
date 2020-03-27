//: Playground - noun: a place where people can play

import Foundation

protocol ParserType {
    associatedtype Value
    typealias ParseResult = (value: Value, remainder: String)
    func parse(input: String) -> [ParseResult]
}

struct Result<A>: ParserType {
    let value: A
    
    init(_ value: A) {
        self.value = value
    }
    
    func parse(input: String) -> [(value: A, remainder: String)] {
        return [(value, input)]
    }
}

struct Zero<A>: ParserType {
    func parse(input: String) -> [(value: A, remainder: String)] {
        return []
    }
}

struct Item: ParserType {
    typealias Value = Character
    
    func parse(input: String) -> [(value: Character, remainder: String)] {
        if let fst = input.first {
            let remainder = input.dropFirst()
            
            return [(fst, String(remainder))]
        }
        
        return []
    }
}

struct AnyParser<A>: ParserType {
    private let _parse: ((String) -> [(value: A, remainder: String)])
    
    init<P: ParserType>(_ p: P) where P.Value == A {
        _parse = p.parse
    }
    
    func parse(input: String) -> [(value: A, remainder: String)] {
        return _parse(input)
    }
}

struct Bind<A, B>: ParserType {
    private let parser: AnyParser<A>
    private let transform: (A) -> AnyParser<B>
    
    init<P1: ParserType, P2: ParserType>(_ p: P1, transform f: @escaping ((A) -> P2))
        where P1.Value == A, P2.Value == B {
            parser = AnyParser(p)
            transform = { input in return AnyParser(f(input)) }
    }
    
    func parse(input: String) -> [(value: B, remainder: String)] {
        return parser.parse(input: input).flatMap { result in
            return transform(result.value).parse(input: result.remainder)
        }
    }
}

struct Sequential<A, B>: ParserType {
    typealias Value = (A, B)
    
    let p: AnyParser<A>
    let q: AnyParser<B>
    
    init<P: ParserType, Q: ParserType>(_ p: P, _ q: Q) where P.Value == A, Q.Value == B {
        self.p = p.asAny()
        self.q = q.asAny()
    }
    
    func parse(input: String) -> [(value: Value, remainder: String)] {
        return p.bind { (val1: A) -> AnyParser<Value> in
            return self.q.bind { (val2: B) -> Result<Value> in
                return Result((val1, val2))
            }.asAny()
        }.parse(input: input)
    }
}

extension ParserType {
    func asAny() -> AnyParser<Value> {
        return AnyParser(self)
    }
    
    func bind<Next, P: ParserType>(_ f: @escaping ((Value) -> P)) -> Bind<Value, Next> where P.Value == Next {
        return Bind(self, transform: f)
    }
    
    // This works but the type `OtherValue` can't be inferred at call site.
//    func seq<OtherValue, P: ParserType, R: ParserType>(other: P) -> R where P.Value == OtherValue, R.Value == (Value, OtherValue) {
//        let b = bind { (val: Value) in
//            return other.bind { (other: OtherValue) -> Result<(Value, OtherValue)> in
//                return Result((val, other))
//            }
//        }
//        
//        return b as! R
//    }
}

infix operator >>=

extension ParserType {
    static func >>= <Next, P: ParserType>(lhs: Self, rhs: @escaping ((Self.Value) -> P)) -> Bind<Self.Value, Next> where P.Value == Next {
        return lhs.bind(rhs)
    }
}

struct ConditionalParser: ParserType {
    private let predicate: ((Character) -> Bool)
    
    init(_ p: @escaping ((Character) -> Bool)) {
        predicate = p
    }
    
    func parse(input: String) -> [(value: Character, remainder: String)] {
        return Item()
            .bind { ch -> AnyParser<Character> in
                if self.predicate(ch) {
                    return AnyParser(Result(ch))
                }
                else {
                    return AnyParser(Zero())
                }
            }
            .parse(input: input)
    }
}

let r1 = Result("a")
let r2 = Result("1")

let bind = Bind(r1) { (input: String) -> AnyParser<String> in
    return AnyParser(r2)
}

bind.parse(input: "hello")

let onlyA = ConditionalParser { $0 == "a" }
let a = Sequential(onlyA, onlyA)
a.parse(input: "a")

// MARK: Specific Types of Characters

extension CharacterSet {
    var parser: ConditionalParser {
        return ConditionalParser { ch in
            guard let us = UnicodeScalar(String(ch)) else { return false }
            return self.contains(us)
        }
    }
}

let digit = CharacterSet.decimalDigits.parser
let lower = CharacterSet.lowercaseLetters.parser
let upper = CharacterSet.uppercaseLetters.parser
let letter = CharacterSet.letters.parser

// a parser that takes two lowercase letters in sequence
let doubleLower = lower >>= { ch1 in lower >>= { ch2 in Result("\(ch1)\(ch2)") } }

doubleLower.parse(input: "abcd")

// A 'choice' operator will help us combine parsers
struct Choice<A>: ParserType {
    typealias Value = A

    private let p: AnyParser<A>
    private let q: AnyParser<A>

    init<P: ParserType, Q: ParserType>(_ p: P, _ q: Q) where P.Value == A, Q.Value == A {
        self.p = p.asAny()
        self.q = q.asAny()
    }

    func parse(input: String) -> [(value: A, remainder: String)] {
        return Array([p.parse(input: input), q.parse(input: input)].joined())
    }
}

extension ParserType {
    func plus<P: ParserType>(other: P) -> Choice<Value> where P.Value == Self.Value {
        return Choice(self, other)
    }
}

// we can write a word parser in terms of our letter parser and itself
struct Word: ParserType {
    typealias Value = String

    private func anyWord() -> AnyParser<String> {
        return (letter >>= { c in Word() >>= { s in Result("\(c)\(s)") } }).asAny()
    }

    func parse(input: String) -> [(value: String, remainder: String)] {
        return anyWord().plus(other: Result("")).parse(input: input)
    }
}

let word = Word()
word.parse(input: "hello world")
