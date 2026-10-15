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
- **Interruptible**: A step budget and a thread-safe `Cancel` stop a runaway script; call depth and allocation limits stop one that would crash the host

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

## Memory Management

Executing a script repeatedly in a long-lived engine (for example a render loop at 30 FPS) accumulates the scopes, functions and parsed programs created by each run. Call `CollectGarbage` to reclaim everything that is no longer reachable from global state, without recreating the engine and losing your globals:

```pascal
while Running do
begin
  Engine.Execute(FrameScript);
  Engine.CollectGarbage;
end;
```

Anything still referenced from a global variable, including closures, survives collection. Only script functions and scopes that the host retains directly (raw values held outside the engine) should not be relied upon across a collection; keep persistent state in globals.

## Stopping a Running Script

A script written by an LLM, or by anyone else you do not control, can loop forever, recurse until the native stack overflows, or build a string until memory runs out. The engine counts the steps it takes and gives the host two ways to stop a run: a step budget it enforces itself, and a `Cancel` any thread may call. Two further limits, on call depth and on allocation size, are on by default and keep a script from crashing the host before the step budget bites.

A step is one statement executed, one iteration of a `while`, `do-while`, `for` or `for-in` loop, and one function call. Both checks happen at those points, so any script that runs away, by looping or by recursing, reaches one within a bounded number of steps.

### Step budget

`StepBudget` caps how many steps a single `Execute` may take. Zero, the default, means unlimited. Exceeding it raises `EJSStepBudgetExceeded`, which carries the budget it exceeded in its `StepBudget` property.

```pascal
Engine.StepBudget := 1000000;
try
  Engine.Execute(ScriptFromTheModel);
except
  on E: EJSStepBudgetExceeded do
    WriteLn(Format('Script stopped after %d steps', [E.StepBudget]));
end;
```

`StepCount` reports the steps the last `Execute` took, whether it finished or was stopped. Set `StepBudget` before calling `Execute`: the budget and the count both apply to one run and reset at the start of the next.

### Cancel

`Cancel` is thread safe and may be called while `Execute` runs on another thread. The running script stops at the next check and `Execute` raises `EJSExecutionCancelled` on the thread that called it.

```pascal
const Worker = TThread.CreateAnonymousThread(
  procedure
  begin
    try
      Engine.Execute(ScriptFromTheModel);
    except
      on EJSExecutionCancelled do
        WriteLn('Script cancelled');
    end;
  end);
Worker.Start;

if not Worker.WaitFor(TimeoutMilliseconds) then
  Engine.Cancel;
```

`Execute` does not clear the flag. A `Cancel` that arrives between two runs stays pending, so the next `Execute` stops at its first check, which is what a host that runs several scripts as one job means by cancelling. The check falls every 1024 steps, or sooner when a step budget is closer, so a run that finishes inside that interval can still complete; the flag stays set and stops the run after it. Nothing clears it: an engine that has been cancelled is done, and work that must run afterwards belongs to a fresh engine.

### Call depth and allocation limits

Every JavaScript call recurses in the interpreter, so unbounded recursion overflows the native stack long before a step budget of a useful size is reached, and a stack overflow can take the host process down. Strings and arrays can likewise grow geometrically. These limits are enforced before the work is done:

| Property | Default | Limits | Raises |
| --- | --- | --- | --- |
| `MaxCallDepth` | 100 | Nested calls of script functions | `EJSCallDepthExceeded` |
| `MaxStringLength` | 16 Mi chars | The length of any string a script builds | `EJSAllocationLimitExceeded` |
| `MaxArrayLength` | 1 Mi elements | The length of any array a script builds | `EJSAllocationLimitExceeded` |

The string limit applies to the result of `+`, `+=`, `concat`, `repeat`, `padStart`, `padEnd`, `join` and `replace`, and to every conversion of an array to a string: `String(array)`, `array + ''`, an array used as a property key, an array printed with `console.log`, and the elements of `join` and `concat`. It also applies to the text `JSON.stringify` produces. The array limit applies to array literals, `push`, `unshift`, `splice`, `concat`, `flat`, `split`, `Array.from` and assigning to an index past the end. Other operations only produce results bounded by their already limited input and are not checked.

A length is checked before the string or array is allocated, so `'x'.repeat(1000000000)` raises at once instead of asking for 2 GB. Conversions of arrays and `JSON.stringify` check the running length before each piece is appended. Two cases are checked after the fact because the underlying call allocates first: the result of a `replace` with a regular expression is refused up front when the source length plus the matches times the replacement length exceeds the limit, but a replacement that expands `$` patterns is only caught by the check on the finished result, and `JSON.parse` does not limit the arrays it builds from its input.

Nested arrays and objects count against `MaxCallDepth` when they are converted to a string or to JSON, so a structure nested deeper than the limit raises `EJSCallDepthExceeded`. An array that contains itself converts to a string the way JavaScript does (the repeated array is an empty element), and `JSON.stringify` of a circular structure raises a `TypeError`. The engine does not collect reference cycles, so a script that builds one should break it before it ends. Zero turns a limit off.

```pascal
Engine.MaxCallDepth := 50;
Engine.MaxStringLength := 1024 * 1024;
try
  Engine.Execute(ScriptFromTheModel);
except
  on E: EJSCallDepthExceeded do
    WriteLn(Format('Script nested deeper than %d calls', [E.MaxCallDepth]));
  on E: EJSAllocationLimitExceeded do
    WriteLn(E.Message);
end;
```

`EJSAllocationLimitExceeded.Kind` tells a string limit (`Characters`) from an array limit (`Elements`) and `Limit` carries the limit that was exceeded. The default call depth leaves a wide margin on a default 1 MB Win64 thread stack: a plain recursion overflows it at roughly 870 nested calls in a Debug build, and scripts that nest more expressions per call overflow it at roughly 465, so the default of 100 keeps at least a 4x margin. A host that runs scripts on a thread with a smaller stack, or that registers native functions which call back into the engine, should lower `MaxCallDepth` accordingly.

All the interrupting exceptions (the two above and the limit exceptions) derive from `EJSExecutionInterrupted` and none can be caught by the script itself: a `catch` block in JavaScript never sees them, and a `finally` block does not run once one is raised. After a step budget or a limit stopped a script the engine stays usable with its global state intact, so the next `Execute` starts from wherever the stopped script left the globals.

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

Requires Delphi 10.3 (RAD Studio Rio) or later. The `packages` folder has a runtime package for each RAD Studio version from 10.3 to 13.0.

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
## Commercial Support

This library is MIT licensed and free to use. For companies that depend on it commercially we offer support and maintenance agreements with guaranteed response times, and sponsored development of features you need. Contact us at [gdksoftware.com/contact-us](https://gdksoftware.com/contact-us) or open an issue to get in touch.
