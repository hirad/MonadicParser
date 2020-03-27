//: [Previous](@previous)

import Foundation

typealias Parser<A> = (String) -> [(A, String)]

func result<A>(_ a: A) -> Parser<A> {
    return { [(a, $0)] }
}

// Example:
let resultIsT = result("T")
print(resultIsT("Hello world"))

func zero<A>() -> Parser<A> {
    return { _ in [] }
}

func item() -> Parser<Character> { // -> (String) -> [(Character, String)]
    return { input in
        if let fst = input.first {
            let rem = input.dropFirst()
            return [(fst, String(rem))]
        }

        return []
    }
}

// Example
print(item()("Hello world"))

func bind<A, B>(_ p: @escaping Parser<A>, _ f: @escaping ((A) -> Parser<B>)) -> Parser<B> {
    return { input in
        return p(input).flatMap { f($0.0)($0.1) }
    }
}

infix operator >>= : AdditionPrecedence

func >>= <A, B>(p: @escaping Parser<A>, f: @escaping ((A) -> Parser<B>)) -> Parser<B> {
    return bind(p, f)
}

// Example
let boundParser = item() >>= { _ in item() }
print(boundParser("Hello world"))

func sequential<A, B>(_ p: @escaping Parser<A>, _ q: @escaping Parser<B>) -> Parser<(A,B)> {
    return (p >>= { a in q >>= { b in result((a, b)) } })
}

let seqParser = sequential(item(), item())
print(seqParser("Hello world"))

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
let alphanumeric = CharacterSet.alphanumerics.parser

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

let markdown = """
# Intro

This _is_ a test of **markdown** parsing.

As specified at [CommonMark](http://commonmark.org).

"""
let mdLine = "_is_ a test of **markdown** parsing."

/// Markdown Parsers
var beginItalics1 = sequential(satisfy({ $0 == Character("_") }), alphanumeric)
var endItalics1 = sequential(alphanumeric, satisfy({ $0 == Character("_") }))

let c = beginItalics1(mdLine).first
endItalics1(mdLine)

//: [Next](@next)
