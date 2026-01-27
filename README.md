# JavaScript4D

A complete JavaScript (ECMAScript 5.1) parser and interpreter written in Delphi/Object Pascal.

## Overview

JavaScript4D enables Delphi applications to parse and execute JavaScript code natively. It's designed to allow LLMs to write JavaScript functions that can be executed by Delphi code, bridging the gap between AI-generated scripts and native Delphi applications.

## Features

- **Complete ES5.1 Support**: Full ECMAScript 5.1 specification compliance
- **Pure Delphi**: No external dependencies or DLLs required
- **Recursive Descent Parser**: Clean AST-based architecture
- **Built-in Objects**: Array, String, Number, Object, Math, JSON, Date, RegExp support
- **Higher-Order Functions**: map, filter, reduce, forEach, find, some, every
- **Closures**: Full support for lexical scoping and closures
- **Error Handling**: Try/catch/finally with TypeError, RangeError, SyntaxError, etc.
- **Native Binding**: Easy integration between Delphi and JavaScript

## Quick Start

```pascal
uses
  JS4D.Engine;

var
  Engine: TJSEngine;
begin
  Engine := TJSEngine.Create;
  try
    // Simple expression
    var Result := Engine.Evaluate('1 + 2 * 3');
    WriteLn(Result.ToString);  // Output: 7

    // Variables and functions
    Engine.Execute('var x = 10;');
    Engine.Execute('function double(n) { return n * 2; }');
    Result := Engine.Evaluate('double(x)');
    WriteLn(Result.ToString);  // Output: 20

    // Array operations
    Engine.Execute('var nums = [1, 2, 3, 4, 5];');
    Result := Engine.Evaluate('nums.map(function(x) { return x * 2; }).join(",")');
    WriteLn(Result.ToString);  // Output: 2,4,6,8,10

    // Object literals
    Engine.Execute('var person = { name: "John", age: 30 };');
    Result := Engine.Evaluate('JSON.stringify(person)');
    WriteLn(Result.ToString);  // Output: {"name":"John","age":30}
  finally
    Engine.Free;
  end;
end;
```

## Supported JavaScript Features

### Core Language
- Variables (`var`)
- Functions (declaration and expression)
- Control flow (`if`, `else`, `for`, `while`, `do-while`, `switch`)
- Operators (arithmetic, comparison, logical, bitwise)
- Object literals and property access
- Array literals and indexing
- Try/catch/finally

### Built-in Objects

**Array Methods**
- `push`, `pop`, `shift`, `unshift`
- `indexOf`, `lastIndexOf`, `includes`
- `join`, `slice`, `splice`, `concat`, `reverse`
- `map`, `filter`, `reduce`, `reduceRight`
- `forEach`, `find`, `findIndex`
- `some`, `every`, `sort`
- `fill`, `copyWithin`, `flat`

**String Methods**
- `charAt`, `charCodeAt`
- `indexOf`, `lastIndexOf`, `includes`
- `substring`, `substr`, `slice`
- `split`, `trim`, `trimStart`, `trimEnd`
- `toLowerCase`, `toUpperCase`
- `replace`, `concat`, `repeat`
- `startsWith`, `endsWith`
- `padStart`, `padEnd`

**Object Methods**
- `Object.keys`, `Object.values`, `Object.entries`
- `Object.assign`, `Object.create`
- `hasOwnProperty`

**JSON**
- `JSON.parse`, `JSON.stringify`

**Math**
- All standard Math functions (`abs`, `floor`, `ceil`, `round`, `sqrt`, `pow`, `min`, `max`, `random`, `sin`, `cos`, `tan`, etc.)

**Global Functions**
- `parseInt`, `parseFloat`
- `isNaN`, `isFinite`
- `Array.isArray`, `Array.from`
- `Date.now`, `Date.parse`

## Architecture

```
JavaScript Source Code
        │
        ▼
┌─────────────────┐
│     Lexer       │  → Tokens
└─────────────────┘
        │
        ▼
┌─────────────────┐
│     Parser      │  → Abstract Syntax Tree (AST)
└─────────────────┘
        │
        ▼
┌─────────────────┐
│   Interpreter   │  → Execution Result
└─────────────────┘
```

## Project Structure

```
Javascript4D/
├── Source/
│   ├── API/            # Public Engine API
│   ├── Core/           # Types, Errors
│   ├── Lexer/          # Tokenizer
│   ├── Parser/         # AST Builder
│   └── Runtime/        # Interpreter, Built-ins
├── Demo/               # VCL demo application
├── Tests/              # DUnitX unit tests
└── CLAUDE.md           # Claude Code instructions
```

## Building

Requires Delphi 12.3 (RAD Studio Athens) or later.

Open the project in RAD Studio IDE or use MSBuild:

```bash
msbuild Tests/JS4D.Tests.dproj /p:Configuration=Release /p:Platform=Win64
msbuild Demo/JS4D.Demo.dproj /p:Configuration=Release /p:Platform=Win64
```

## Running Tests

Run the compiled test executable `JS4D.Tests.exe` from your build output directory.

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit pull requests.