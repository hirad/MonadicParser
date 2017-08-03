//: [Previous](@previous)

import Foundation

typealias Parser<A> = (String) -> [(A, String)]

func result<A>(_ a: A) -> Parser<A> {
    return { [(a, $0)] }
}

func zero<A>() -> Parser<A> {
    return { _ in [] }
}

func item() -> Parser<Character> {
    return { input in
        if let fst = input.characters.first {
            let rem = input.characters.dropFirst()
            return [(fst, String(rem))]
        }

        return []
    }
}

func bind<A, B>(_ p: @escaping Parser<A>, _ f: @escaping ((A) -> Parser<B>)) -> Parser<B> {
    return { input in
        return p(input).flatMap { f($0.0)($0.1) }
    }
}

infix operator >>= : AdditionPrecedence

func >>= <A, B>(p: @escaping Parser<A>, f: @escaping ((A) -> Parser<B>)) -> Parser<B> {
    return bind(p, f)
}

func sequential<A, B>(_ p: @escaping Parser<A>, _ q: @escaping Parser<B>) -> Parser<(A,B)> {
    return (p >>= { a in q >>= { b in result((a, b)) } })
}

func satisfy(_ pred: @escaping (Character) -> Bool) -> Parser<Character> {
    return (item() >>= { pred($0) ? result($0) : zero() })
}

extension CharacterSet {
    var parser: Parser<Character> {
        return satisfy { ch in
            guard let us = UnicodeScalar(String(ch)) else { return false }
            return self.contains(us)
        }
    }
}

let digit = CharacterSet.decimalDigits.parser
let lower = CharacterSet.lowercaseLetters.parser
let upper = CharacterSet.uppercaseLetters.parser
let letter = CharacterSet.letters.parser

let doubleLower = lower >>= { ch1 in lower >>= { ch2 in result("\(ch1)\(ch2)") } }

doubleLower("abcd")

// a 'choice' operator will help us combine parsers
func plus<A>(_ p: @escaping Parser<A>, _ q: @escaping Parser<A>) -> Parser<A> {
    return { inp in
        return Array([p(inp), q(inp)].joined())
    }
}

// now we can define a word parser in terms of the simpler parsers we have

var word: Parser<String> {
    func _word() -> Parser<String> {
        return letter >>= { c in word >>= { s in result("\(c)\(s)") } }
    }

    return plus(_word(), result(""))
}

word("hello word")

class A {
    var foo: Int! = 1
}

let a = A()
switch a.foo {
case 0:
    print("0")
case 1:
    print("Nada")
    default:
    print("default")
}

//protocol ResultGenerator {
//    associatedtype Value
//    func result<R: ResultGenerator>(_ a: Value) -> R where R.Value == Value
//}
//
//protocol Bindable {
//    associatedtype Value
//    func bind<B1: Bindable, B2: Bindable>(_ lhs: B1, _ f: ((Value) -> B2)) -> B2
//}
//
//protocol Monad: ResultGenerator, Bindable {}

//: [Next](@next)
