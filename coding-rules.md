# Coding rules

Javascript4D follows the GDK Delphi coding standard, with the exceptions below. They describe the style the code base was written in; new code follows them too.

## Exceptions

- **Collections.** The library has no dependencies outside the Delphi RTL, so it uses `System.Generics.Collections` (`TList<T>`, `TDictionary<K, V>`, `TObjectList<T>`) instead of Spring4D collections.
- **Constants.** Constants are written in UPPER_CASE with underscores, for example `MAX_NESTING_DEPTH`.
- **Arrays.** `TArray<T>` is allowed. The host API passes arguments as `TArray<TJSValue>`, and the interpreter uses arrays on its hot paths.
- **Units.** Units are named `JS4D.<Concept>.pas` and live in the folder of their part of the engine (`Core`, `Lexer`, `Parser`, `Runtime`, `API`) instead of the `Module.Entity.Purpose` layers of an application. Closely related types, such as an object class and the record it stores, may share a unit.
- **Section markers.** The `{ TClassName }` line above the implementation of a class is allowed.

## Additions

- **No host crash.** No script may cause a stack overflow, an access violation or a hang of the host process. Deep recursion ends in a `RangeError` or a limit error, and unbounded work is bounded by the engine limits.
- **Hot paths.** Identifier lookup, property access, calls and iteration over plain arrays must not get slower. Measure them against the main branch when a change touches them.
- **Engine lifetime.** Freeing an engine releases every object it created. A test in `JS4D.Tests.EngineLifetime` covers each new kind of object.
