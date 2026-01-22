program Javascript4D;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  JS4D.Types in 'Source\Core\JS4D.Types.pas',
  JS4D.Errors in 'Source\Core\JS4D.Errors.pas',
  JS4D.Tokens in 'Source\Lexer\JS4D.Tokens.pas',
  JS4D.Lexer in 'Source\Lexer\JS4D.Lexer.pas',
  JS4D.AST in 'Source\Parser\JS4D.AST.pas',
  JS4D.Parser in 'Source\Parser\JS4D.Parser.pas',
  JS4D.Builtins in 'Source\Runtime\JS4D.Builtins.pas',
  JS4D.Interpreter in 'Source\Runtime\JS4D.Interpreter.pas',
  JS4D.Engine in 'Source\API\JS4D.Engine.pas';

begin
  try
    var Engine := TJSEngine.Create;
    try
      WriteLn('JavaScript4D - JavaScript Parser & Interpreter for Delphi');
      WriteLn('ECMAScript 5.1 Compatible');
      WriteLn('');

      WriteLn('Test 1: Simple expression');
      var Result := Engine.Evaluate('1 + 2 * 3');
      WriteLn('  1 + 2 * 3 = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 2: Variables');
      Engine.Execute('var x = 10;');
      Result := Engine.Evaluate('x + 5');
      WriteLn('  var x = 10; x + 5 = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 3: Function declaration and call');
      Engine.Execute('function add(a, b) { return a + b; }');
      Result := Engine.Evaluate('add(2, 3)');
      WriteLn('  function add(a, b) { return a + b; } add(2, 3) = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 4: Object literals');
      Engine.Execute('var obj = { x: 1, y: 2 };');
      Result := Engine.Evaluate('obj.x + obj.y');
      WriteLn('  var obj = { x: 1, y: 2 }; obj.x + obj.y = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 5: Array literals');
      Engine.Execute('var arr = [1, 2, 3, 4, 5];');
      Result := Engine.Evaluate('arr[2]');
      WriteLn('  var arr = [1, 2, 3, 4, 5]; arr[2] = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 6: Control flow (if statement)');
      Engine.Execute('var result = ""; if (x > 5) { result = "positive"; } else { result = "non-positive"; }');
      Result := Engine.GetVariable('result');
      WriteLn('  if (x > 5) result = "positive" else result = "non-positive" -> result = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 7: For loop');
      Engine.Execute('var sum = 0; for (var i = 1; i <= 5; i++) { sum += i; }');
      Result := Engine.GetVariable('sum');
      WriteLn('  for (var i = 1; i <= 5; i++) sum += i; -> sum = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 8: Math object');
      Result := Engine.Evaluate('Math.sqrt(16) + Math.pow(2, 3)');
      WriteLn('  Math.sqrt(16) + Math.pow(2, 3) = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 9: String concatenation');
      Result := Engine.Evaluate('"Hello, " + "World!"');
      WriteLn('  "Hello, " + "World!" = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 10: Console output');
      Engine.Execute('console.log("This is a console.log test");');
      WriteLn('');

      WriteLn('Test 11: Array.map');
      Engine.Execute('var nums = [1, 2, 3, 4, 5];');
      Engine.Execute('var doubled = nums.map(function(x) { return x * 2; });');
      Result := Engine.Evaluate('doubled.join(",")');
      WriteLn('  [1,2,3,4,5].map(x => x*2) = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 12: Array.filter');
      Engine.Execute('var evens = nums.filter(function(x) { return x % 2 == 0; });');
      Result := Engine.Evaluate('evens.join(",")');
      WriteLn('  [1,2,3,4,5].filter(x => x%2==0) = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 13: Array.reduce');
      Result := Engine.Evaluate('nums.reduce(function(acc, x) { return acc + x; }, 0)');
      WriteLn('  [1,2,3,4,5].reduce((acc,x) => acc+x, 0) = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 14: String.split and join');
      Result := Engine.Evaluate('"hello world".split(" ").join("-")');
      WriteLn('  "hello world".split(" ").join("-") = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 15: String.toUpperCase');
      Result := Engine.Evaluate('"hello".toUpperCase()');
      WriteLn('  "hello".toUpperCase() = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 16: Array.find');
      Result := Engine.Evaluate('nums.find(function(x) { return x > 3; })');
      WriteLn('  [1,2,3,4,5].find(x => x>3) = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 17: Array.some and every');
      Result := Engine.Evaluate('nums.some(function(x) { return x > 3; })');
      WriteLn('  [1,2,3,4,5].some(x => x>3) = ' + Result.ToString);
      Result := Engine.Evaluate('nums.every(function(x) { return x > 0; })');
      WriteLn('  [1,2,3,4,5].every(x => x>0) = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 18: Array.sort');
      Engine.Execute('var unsorted = [3, 1, 4, 1, 5, 9, 2, 6];');
      Result := Engine.Evaluate('unsorted.sort().join(",")');
      WriteLn('  [3,1,4,1,5,9,2,6].sort() = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 19: Object.keys');
      Engine.Execute('var person = { name: "John", age: 30, city: "NYC" };');
      Result := Engine.Evaluate('Object.keys(person).join(",")');
      WriteLn('  Object.keys({name,age,city}) = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 20: Object.values');
      Result := Engine.Evaluate('Object.values(person).join(",")');
      WriteLn('  Object.values({name:"John",age:30,city:"NYC"}) = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 21: JSON.stringify');
      Result := Engine.Evaluate('JSON.stringify(person)');
      WriteLn('  JSON.stringify(person) = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 22: JSON.parse');
      Engine.Execute('var parsed = JSON.parse(''{"x":1,"y":2}'');');
      Result := Engine.Evaluate('parsed.x + parsed.y');
      WriteLn('  JSON.parse(''{"x":1,"y":2}'').x + .y = ' + Result.ToString);
      WriteLn('');

      WriteLn('Test 23: Array.isArray');
      Result := Engine.Evaluate('Array.isArray([1,2,3])');
      WriteLn('  Array.isArray([1,2,3]) = ' + Result.ToString);
      Result := Engine.Evaluate('Array.isArray("hello")');
      WriteLn('  Array.isArray("hello") = ' + Result.ToString);
      WriteLn('');

      WriteLn('All tests completed successfully!');
    finally
      Engine.Free;
    end;
  except
    on E: Exception do
      WriteLn('Error: ', E.ClassName, ': ', E.Message);
  end;

  WriteLn('');
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
