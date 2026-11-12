# JavaScript4D

A JavaScript parser and interpreter written in Delphi/Object Pascal. It targets ECMAScript 5.1 and supports the ES2015 syntax listed below; see [Conformance](#conformance-test262) for what passes today.

## Overview

JavaScript4D enables Delphi applications to parse and execute JavaScript code natively. It's designed to allow LLMs to write JavaScript functions that can be executed by Delphi code, bridging the gap between AI-generated scripts and native Delphi applications.

## Features

- **ECMAScript 5.1 core**: Most ES5.1 language features and built-ins, measured against test262 (see Conformance)
- **ES2015 syntax**: `let` and `const` with block scope, arrow functions, template literals, enhanced object literals, default and rest parameters, spread, destructuring, and `for-of` over any iterable
- **Classes**: class declarations and expressions with constructors, methods, getters and setters, static members, computed names, `extends` (including `null` and the built-in constructors), `super()` calls, `super.property` in classes and object literal methods, and `new.target`. Class fields, private members and static blocks are not supported yet
- **Symbol**: symbols as property keys, `Symbol.for` and `Symbol.keyFor`, all well-known symbols, and the protocols `toPrimitive`, `toStringTag`, `hasInstance`, `isConcatSpreadable`, `unscopables` and `species`
- **Map, Set, WeakMap and WeakSet**: constructors that take iterables, SameValueZero keys, insertion order, iteration that sees additions and skips deletions made while it runs, `size`, `forEach`, `keys`, `values` and `entries`
- **Promise**: `Promise` with `then`, `catch` and `finally`, `resolve`, `reject`, `all`, `allSettled`, `any`, `race`, `withResolvers` and `try`, thenable assimilation, subclassing and species, and `AggregateError`. Reactions run as microtasks: `Execute` runs every pending job when the script ends (also when it throws), so callbacks have run before it returns. `Engine.RunPendingJobs` runs jobs that are still waiting. The step budget covers the jobs, so a promise loop that never ends raises `EJSStepBudgetExceeded`. Unhandled rejections are ignored
- **Generators**: `function*` declarations and expressions, generator methods in object literals and classes, `yield` and `yield*` (which forwards `next`, `throw` and `return` and closes the inner iterator), `next`, `return` and `throw` with `try`/`finally` semantics, `GeneratorFunction`, and generators as iterables in `for-of`, spread and destructuring. A suspended generator keeps no thread: its body is left at the `yield` and entered again at the same place when the generator is resumed. Async generators are not supported yet
- **Async functions**: `async function` declarations and expressions, async arrow functions and async methods in object literals and classes, and `await` on promises, thenables and plain values. An async function runs on the generator machinery: it is suspended at an `await` without a thread and resumed from the promise job queue, so `Execute` returns after the pending jobs have run. A rejected promise is thrown at the `await`, and an uncaught error rejects the promise that the call returned. Async iteration (`for await`, async generators) is not supported yet
- **`__proto__`**: the `__proto__` accessor on `Object.prototype` and `__proto__: value` in object literals (Annex B)
- **Iterator protocol**: `Symbol.iterator` on arrays, strings, `arguments`, maps and sets, array and string iterators, and `for-of`, spread, array destructuring and `Array.from` over any iterable, with iterator closing
- **Proxy and Reflect**: all proxy traps with their invariants, and every `Reflect` function
- **ArrayBuffer, DataView and typed arrays**: `ArrayBuffer`, `DataView` with endianness, and all typed array constructors with the `%TypedArray%` methods, `from` and `of`; the host can detach buffers
- **ES2015 and later library methods**: `Symbol.match`, `replace`, `search` and `split` on `RegExp.prototype` with the String methods delegating to them, sticky and unicode regular expressions, `String.prototype.replaceAll`, `at`, `String.fromCodePoint`, `Object.hasOwn`, `Object.setPrototypeOf`, `Object.fromEntries`, `Array.prototype.at`, `includes`, `flat` and `flatMap`, and the `**` operator
- **Pure Delphi**: No external dependencies or DLLs required
- **Recursive Descent Parser**: Clean AST-based architecture
- **Built-in Objects**: Array, String, Number, Object, Math, JSON, Date, RegExp support
- **Locale-aware formatting**: `toLocaleString` on numbers (decimal, percent and currency styles) and on dates (`toLocaleString`, `toLocaleDateString`, `toLocaleTimeString`) for en-US, en-GB, nl-NL, nl-BE, de-DE, fr-FR, es-ES and it-IT, from built-in tables that give the same output on every platform. The `Intl` object is not provided
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

## Promises and the Job Queue

Promise reactions and the continuations of async functions are jobs in a queue that belongs to the engine. `Execute` runs the queue empty when the script ends, also when the script throws, so `then` callbacks and the code after an `await` have run when `Execute` returns:

```delphi
Engine.Execute('Promise.resolve(1).then(function (v) { result = v + 1; });');
// result is already 2 here
```

Jobs that are still waiting after that, because host code queued them outside a script, run with `Engine.RunPendingJobs`; with an empty queue it does nothing. Jobs count against the step budget like ordinary script code, so `StepBudget` stops a promise loop that never ends with `EJSStepBudgetExceeded`. A promise that is never settled leaves its callbacks unrun; freeing the engine releases them. Unhandled rejections are ignored.

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

**What the limits cover.** Zero turns a limit off.

- `MaxCallDepth` counts nested calls of script functions, including calls made through `map`, `sort`, `call`, `apply`, `bind` and `new`. It also caps how deeply nested arrays and objects may be when the engine turns them into text or JSON, so `a = [a]` repeated thousands of times cannot overflow the stack in `String(a)`, `indexOf(a)`, `JSON.stringify(a)` and the like.
- `MaxStringLength` applies to the result of `+`, `+=`, `concat`, `repeat`, `padStart`, `padEnd`, `join` and `replace`, to every conversion of an array to a string (`String(array)`, `array + ''`, an array used as a property key or printed with `console.log`, and the pieces handed to `join` and `concat`), and to the text `JSON.stringify` produces.
- `MaxArrayLength` applies to array literals, `push`, `unshift`, `splice`, `concat`, `flat`, `split`, `Array.from` and assigning to an index past the end.
- Other builtins only return results bounded by their own limited input and are not checked.

**Checked before the work is done.** The length is compared with the limit before the string or array is allocated: `'x'.repeat(1000000000)` raises at once instead of asking for 2 GB, and `padStart`, `concat`, `push`, `splice` and the like do the same. Array-to-text conversion and `JSON.stringify` check the running length before each piece is appended; `JSON.stringify` measures the text of each value as it will be written, so many small numbers are not refused on a worst-case estimate.

**Checked after the fact.** A `replace` with a regular expression is refused up front when the source length plus the number of matches times the replacement length exceeds the limit, but a replacement that expands `$` patterns is only caught by the check on the finished result. `JSON.parse` does not limit the arrays it builds from its input.

**Cycles.** An array that contains itself converts to a string the way JavaScript does (the repeated array is an empty element) and `JSON.stringify` of a circular structure raises a `TypeError`. The engine does not collect reference cycles, so a script that builds one should break it before it ends.

**Host-side conversion.** `TJSValue.ToString` is meant for values the host holds. It caps array nesting at the default call depth but does not limit the text length; inside the engine every conversion goes through `ToLimitedString` with the engine's limits.

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
- Variables (`var`, `let`, `const` with block scope and temporal dead zone)
- Functions (declaration and expression)
- Control flow (`if`, `else`, `for`, `while`, `do-while`, `switch`)
- Operators (arithmetic, comparison, logical, bitwise)
- Object literals and property access (shorthand properties, methods, computed keys, getters and setters)
- Arrow functions with lexical `this` and `arguments`
- Classes (`class`, `extends`, `super`, `new.target`, static members, accessors, computed names)
- Template literals and tagged templates, `String.raw`
- Default parameters, rest parameters and spread in calls, arrays and objects
- Destructuring in declarations, parameters, assignments and `for-of` heads, with defaults and rest
- `for-of` over arrays, strings and array-likes
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
- `Array.isArray`, `Array.from`, `Array.of`, `Array.prototype.keys`, `values` and `entries`
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

## Conformance (test262)

The `Conformance` folder holds a runner for [test262](https://github.com/tc39/test262), the ECMAScript conformance suite. It runs `test/language` and `test/built-ins` against JS4D and reports how many tests pass.

```bash
powershell -File Conformance/fetch-test262.ps1
powershell -File Conformance/run-conformance.ps1
```

`fetch-test262.ps1` checks out test262 at a pinned commit into `Conformance/test262`. `run-conformance.ps1` always rebuilds the runner before running it, so the pass list never comes from an executable older than the sources. Runner options go through `-RunnerArguments`, for example `-RunnerArguments '-filter=built-ins/Array'` for a path prefix, `-budget=N` for the step budget per script and `-results=DIR` for the output folder.

Pass rates for the areas with the most tests, counting only the tests that run (tests for features JS4D does not support yet are skipped):

| Area | Tests run | Passed | Rate |
|---|---:|---:|---:|
| built-ins/Array | 2753 | 2751 | 99.9% |
| built-ins/AggregateError | 23 | 23 | 100.0% |
| built-ins/ArrayBuffer | 80 | 80 | 100.0% |
| built-ins/DataView | 376 | 374 | 99.5% |
| built-ins/Date | 599 | 599 | 100.0% |
| built-ins/Function | 459 | 458 | 99.8% |
| built-ins/GeneratorFunction | 21 | 21 | 100.0% |
| built-ins/GeneratorPrototype | 61 | 61 | 100.0% |
| built-ins/JSON | 135 | 135 | 100.0% |
| built-ins/Map | 154 | 154 | 100.0% |
| built-ins/Math | 312 | 312 | 100.0% |
| built-ins/Number | 334 | 331 | 99.1% |
| built-ins/Object | 3319 | 3310 | 99.7% |
| built-ins/Proxy | 273 | 273 | 100.0% |

| built-ins/Promise | 642 | 638 | 99.4% |
| built-ins/Reflect | 153 | 153 | 100.0% |
| built-ins/RegExp | 804 | 780 | 97.0% |
| built-ins/Set | 194 | 194 | 100.0% |
| built-ins/String | 1167 | 1156 | 99.1% |
| built-ins/Symbol | 75 | 75 | 100.0% |
| built-ins/TypedArray | 703 | 703 | 100.0% |
| built-ins/TypedArrayConstructors | 365 | 364 | 99.7% |
| built-ins/WeakMap | 92 | 92 | 100.0% |
| built-ins/WeakSet | 77 | 77 | 100.0% |
| language/expressions | 5864 | 5856 | 99.9% |
| language/statements | 4527 | 4524 | 99.9% |
| **Total** | 26258 | 26178 | 99.7% |

The full per-directory table is in `Conformance/results/baseline.txt` after a run.

Tests that need features JS4D does not implement are skipped: BigInt, Temporal, async iteration (`for await`, async generators), class fields, private members and static blocks, modules and dynamic import, tail calls, and the ES2018 and later library and syntax features. Tests with the `async` flag run: the runner drains the job queue and waits for the `$DONE` callback. `Conformance/exclusions.txt` lists skipped feature tags and `Conformance/excluded-paths.txt` lists skipped path prefixes. Together they are the roadmap: implement a feature, remove its entry, and its tests run.

Results go to `Conformance/results`: `baseline.txt` (totals, skips and pass rate per directory), `failures.txt` and `passed.txt` (one `path [variant]` line per passing test, sorted, for comparing runs).

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit pull requests.
## Commercial Support

This library is MIT licensed and free to use. For companies that depend on it commercially we offer support and maintenance agreements with guaranteed response times, and sponsored development of features you need. Contact us at [gdksoftware.com/contact-us](https://gdksoftware.com/contact-us) or open an issue to get in touch.
