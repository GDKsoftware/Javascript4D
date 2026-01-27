unit JS4D.Demo.Main;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  JS4D.Engine,
  JS4D.Types;

type
  TFormMain = class(TForm)
    PanelTop: TPanel;
    PanelBottom: TPanel;
    SplitterMain: TSplitter;
    PageControlMain: TPageControl;
    TabSheetExamples: TTabSheet;
    MemoOutput: TMemo;
    LabelOutput: TLabel;
    ListBoxExamples: TListBox;
    MemoExampleCode: TMemo;
    ButtonRunExample: TButton;
    LabelExamples: TLabel;
    LabelExampleCode: TLabel;
    PanelExampleLeft: TPanel;
    PanelExampleRight: TPanel;
    SplitterExamples: TSplitter;
    TabSheetDelphi: TTabSheet;
    MemoDelphiInfo: TMemo;
    ButtonRunDelphiDemo: TButton;
    PanelDelphiBottom: TPanel;
    MemoDelphiOutput: TMemo;
    LabelDelphiOutput: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ListBoxExamplesClick(Sender: TObject);
    procedure ButtonRunExampleClick(Sender: TObject);
    procedure ButtonRunDelphiDemoClick(Sender: TObject);
  private
    FEngine: TJSEngine;
    FExamples: TDictionary<string, string>;

    procedure InitializeExamples;
    procedure WriteOutput(const Text: string);
    procedure WriteDelphiOutput(const Text: string);
    procedure RunCode(const Code: string; OutputMemo: TMemo);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FEngine := TJSEngine.Create;
  FExamples := TDictionary<string, string>.Create;

  FEngine.OnConsoleOutput :=
    procedure(const Output: string)
    begin
      WriteOutput('console: ' + Output);
    end;

  InitializeExamples;

  if ListBoxExamples.Items.Count > 0 then
  begin
    ListBoxExamples.ItemIndex := 0;
    ListBoxExamplesClick(nil);
  end;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FExamples.Free;
  FEngine.Free;
end;

procedure TFormMain.InitializeExamples;
begin
  // 1. Basic Expressions
  FExamples.Add('1. Basic Expressions',
    '// Arithmetic operations' + sLineBreak +
    'console.log("=== Basic Expressions ===");' + sLineBreak +
    'console.log("5 + 3 = " + (5 + 3));' + sLineBreak +
    'console.log("10 - 4 = " + (10 - 4));' + sLineBreak +
    'console.log("6 * 7 = " + (6 * 7));' + sLineBreak +
    'console.log("20 / 4 = " + (20 / 4));' + sLineBreak +
    'console.log("17 % 5 = " + (17 % 5));' + sLineBreak +
    sLineBreak +
    '// Comparison operators' + sLineBreak +
    'console.log("5 > 3: " + (5 > 3));' + sLineBreak +
    'console.log("5 == 5: " + (5 == 5));' + sLineBreak +
    'console.log("5 === \"5\": " + (5 === "5"));' + sLineBreak +
    sLineBreak +
    '// Logical operators' + sLineBreak +
    'console.log("true && false: " + (true && false));' + sLineBreak +
    'console.log("true || false: " + (true || false));' + sLineBreak +
    'console.log("!true: " + (!true));');
  ListBoxExamples.Items.Add('1. Basic Expressions');

  // 2. Variables
  FExamples.Add('2. Variables',
    '// Declaring and using variables' + sLineBreak +
    'console.log("=== Variables ===");' + sLineBreak +
    sLineBreak +
    'var name = "JavaScript4D";' + sLineBreak +
    'var version = 1.0;' + sLineBreak +
    'var active = true;' + sLineBreak +
    sLineBreak +
    'console.log("Name: " + name);' + sLineBreak +
    'console.log("Version: " + version);' + sLineBreak +
    'console.log("Active: " + active);' + sLineBreak +
    sLineBreak +
    '// Modifying variables' + sLineBreak +
    'var counter = 0;' + sLineBreak +
    'counter = counter + 1;' + sLineBreak +
    'counter += 5;' + sLineBreak +
    'counter++;' + sLineBreak +
    'console.log("Counter: " + counter);');
  ListBoxExamples.Items.Add('2. Variables');

  // 3. Functions
  FExamples.Add('3. Functions',
    '// Function declarations' + sLineBreak +
    'console.log("=== Functions ===");' + sLineBreak +
    sLineBreak +
    'function greet(name) {' + sLineBreak +
    '    return "Hello, " + name + "!";' + sLineBreak +
    '}' + sLineBreak +
    sLineBreak +
    'console.log(greet("World"));' + sLineBreak +
    'console.log(greet("Delphi"));' + sLineBreak +
    sLineBreak +
    '// Function with multiple parameters' + sLineBreak +
    'function calculate(a, b, operation) {' + sLineBreak +
    '    if (operation == "add") return a + b;' + sLineBreak +
    '    if (operation == "sub") return a - b;' + sLineBreak +
    '    if (operation == "mul") return a * b;' + sLineBreak +
    '    if (operation == "div") return a / b;' + sLineBreak +
    '    return 0;' + sLineBreak +
    '}' + sLineBreak +
    sLineBreak +
    'console.log("10 + 5 = " + calculate(10, 5, "add"));' + sLineBreak +
    'console.log("10 - 5 = " + calculate(10, 5, "sub"));' + sLineBreak +
    'console.log("10 * 5 = " + calculate(10, 5, "mul"));' + sLineBreak +
    'console.log("10 / 5 = " + calculate(10, 5, "div"));' + sLineBreak +
    sLineBreak +
    '// Recursive function (Fibonacci)' + sLineBreak +
    'function fibonacci(n) {' + sLineBreak +
    '    if (n <= 1) return n;' + sLineBreak +
    '    return fibonacci(n - 1) + fibonacci(n - 2);' + sLineBreak +
    '}' + sLineBreak +
    sLineBreak +
    'console.log("Fibonacci(10) = " + fibonacci(10));');
  ListBoxExamples.Items.Add('3. Functions');

  // 4. Control Flow
  FExamples.Add('4. Control Flow',
    '// If/Else statements' + sLineBreak +
    'console.log("=== Control Flow ===");' + sLineBreak +
    sLineBreak +
    'var age = 25;' + sLineBreak +
    sLineBreak +
    'if (age < 18) {' + sLineBreak +
    '    console.log("Minor");' + sLineBreak +
    '} else if (age < 65) {' + sLineBreak +
    '    console.log("Adult");' + sLineBreak +
    '} else {' + sLineBreak +
    '    console.log("Senior");' + sLineBreak +
    '}' + sLineBreak +
    sLineBreak +
    '// Switch statement' + sLineBreak +
    'var day = 3;' + sLineBreak +
    'var dayName;' + sLineBreak +
    sLineBreak +
    'switch (day) {' + sLineBreak +
    '    case 1: dayName = "Monday"; break;' + sLineBreak +
    '    case 2: dayName = "Tuesday"; break;' + sLineBreak +
    '    case 3: dayName = "Wednesday"; break;' + sLineBreak +
    '    case 4: dayName = "Thursday"; break;' + sLineBreak +
    '    case 5: dayName = "Friday"; break;' + sLineBreak +
    '    default: dayName = "Weekend";' + sLineBreak +
    '}' + sLineBreak +
    sLineBreak +
    'console.log("Day " + day + " is " + dayName);' + sLineBreak +
    sLineBreak +
    '// Ternary operator' + sLineBreak +
    'var score = 75;' + sLineBreak +
    'var result = score >= 50 ? "Passed" : "Failed";' + sLineBreak +
    'console.log("Score " + score + ": " + result);');
  ListBoxExamples.Items.Add('4. Control Flow');

  // 5. Loops
  FExamples.Add('5. Loops',
    '// For loop' + sLineBreak +
    'console.log("=== Loops ===");' + sLineBreak +
    sLineBreak +
    'console.log("For loop 1-5:");' + sLineBreak +
    'for (var i = 1; i <= 5; i++) {' + sLineBreak +
    '    console.log("  " + i);' + sLineBreak +
    '}' + sLineBreak +
    sLineBreak +
    '// While loop' + sLineBreak +
    'console.log("While loop (countdown):");' + sLineBreak +
    'var n = 5;' + sLineBreak +
    'while (n > 0) {' + sLineBreak +
    '    console.log("  " + n);' + sLineBreak +
    '    n--;' + sLineBreak +
    '}' + sLineBreak +
    'console.log("  Liftoff!");' + sLineBreak +
    sLineBreak +
    '// Do-while loop' + sLineBreak +
    'console.log("Do-while loop:");' + sLineBreak +
    'var x = 0;' + sLineBreak +
    'do {' + sLineBreak +
    '    console.log("  x = " + x);' + sLineBreak +
    '    x++;' + sLineBreak +
    '} while (x < 3);' + sLineBreak +
    sLineBreak +
    '// For-in loop (over object properties)' + sLineBreak +
    'console.log("For-in loop over object:");' + sLineBreak +
    'var person = { name: "John", age: 30, city: "Amsterdam" };' + sLineBreak +
    'for (var key in person) {' + sLineBreak +
    '    console.log("  " + key + ": " + person[key]);' + sLineBreak +
    '}');
  ListBoxExamples.Items.Add('5. Loops');

  // 6. Arrays
  FExamples.Add('6. Arrays',
    '// Array basics' + sLineBreak +
    'console.log("=== Arrays ===");' + sLineBreak +
    sLineBreak +
    'var numbers = [1, 2, 3, 4, 5];' + sLineBreak +
    'console.log("Array: " + numbers.join(", "));' + sLineBreak +
    'console.log("Length: " + numbers.length);' + sLineBreak +
    'console.log("First: " + numbers[0]);' + sLineBreak +
    'console.log("Last: " + numbers[numbers.length - 1]);' + sLineBreak +
    sLineBreak +
    '// Array methods' + sLineBreak +
    'numbers.push(6);' + sLineBreak +
    'console.log("After push(6): " + numbers.join(", "));' + sLineBreak +
    sLineBreak +
    'var last = numbers.pop();' + sLineBreak +
    'console.log("Pop: " + last);' + sLineBreak +
    sLineBreak +
    'numbers.unshift(0);' + sLineBreak +
    'console.log("After unshift(0): " + numbers.join(", "));' + sLineBreak +
    sLineBreak +
    'var first = numbers.shift();' + sLineBreak +
    'console.log("Shift: " + first);' + sLineBreak +
    sLineBreak +
    '// Slice and splice' + sLineBreak +
    'var part = numbers.slice(1, 4);' + sLineBreak +
    'console.log("Slice(1,4): " + part.join(", "));' + sLineBreak +
    sLineBreak +
    '// Reverse and sort' + sLineBreak +
    'var letters = ["c", "a", "b", "e", "d"];' + sLineBreak +
    'console.log("Original: " + letters.join(", "));' + sLineBreak +
    'console.log("Sorted: " + letters.sort().join(", "));' + sLineBreak +
    'console.log("Reversed: " + letters.reverse().join(", "));');
  ListBoxExamples.Items.Add('6. Arrays');

  // 7. Array Higher-Order Functions
  FExamples.Add('7. Array Higher-Order',
    '// Map, Filter, Reduce' + sLineBreak +
    'console.log("=== Array Higher-Order Functions ===");' + sLineBreak +
    sLineBreak +
    'var numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];' + sLineBreak +
    'console.log("Original: " + numbers.join(", "));' + sLineBreak +
    sLineBreak +
    '// Map: transform each element' + sLineBreak +
    'var doubled = numbers.map(function(x) {' + sLineBreak +
    '    return x * 2;' + sLineBreak +
    '});' + sLineBreak +
    'console.log("Map (x2): " + doubled.join(", "));' + sLineBreak +
    sLineBreak +
    '// Filter: select elements' + sLineBreak +
    'var evens = numbers.filter(function(x) {' + sLineBreak +
    '    return x % 2 == 0;' + sLineBreak +
    '});' + sLineBreak +
    'console.log("Filter (even): " + evens.join(", "));' + sLineBreak +
    sLineBreak +
    '// Reduce: reduce to single value' + sLineBreak +
    'var sum = numbers.reduce(function(acc, x) {' + sLineBreak +
    '    return acc + x;' + sLineBreak +
    '}, 0);' + sLineBreak +
    'console.log("Reduce (sum): " + sum);' + sLineBreak +
    sLineBreak +
    '// Find and findIndex' + sLineBreak +
    'var found = numbers.find(function(x) {' + sLineBreak +
    '    return x > 5;' + sLineBreak +
    '});' + sLineBreak +
    'console.log("Find (>5): " + found);' + sLineBreak +
    sLineBreak +
    '// Some and Every' + sLineBreak +
    'var hasEven = numbers.some(function(x) {' + sLineBreak +
    '    return x % 2 == 0;' + sLineBreak +
    '});' + sLineBreak +
    'console.log("Some (even): " + hasEven);' + sLineBreak +
    sLineBreak +
    'var allPositive = numbers.every(function(x) {' + sLineBreak +
    '    return x > 0;' + sLineBreak +
    '});' + sLineBreak +
    'console.log("Every (positive): " + allPositive);' + sLineBreak +
    sLineBreak +
    '// ForEach' + sLineBreak +
    'console.log("ForEach:");' + sLineBreak +
    '[1, 2, 3].forEach(function(x, i) {' + sLineBreak +
    '    console.log("  Index " + i + ": " + x);' + sLineBreak +
    '});');
  ListBoxExamples.Items.Add('7. Array Higher-Order');

  // 8. Objects
  FExamples.Add('8. Objects',
    '// Object literals' + sLineBreak +
    'console.log("=== Objects ===");' + sLineBreak +
    sLineBreak +
    'var person = {' + sLineBreak +
    '    firstName: "John",' + sLineBreak +
    '    lastName: "Doe",' + sLineBreak +
    '    age: 30,' + sLineBreak +
    '    address: {' + sLineBreak +
    '        street: "Main Street 1",' + sLineBreak +
    '        city: "Amsterdam"' + sLineBreak +
    '    }' + sLineBreak +
    '};' + sLineBreak +
    sLineBreak +
    'console.log("First name: " + person.firstName);' + sLineBreak +
    'console.log("Last name: " + person["lastName"]);' + sLineBreak +
    'console.log("City: " + person.address.city);' + sLineBreak +
    sLineBreak +
    '// Object.keys, values, entries' + sLineBreak +
    'console.log("Keys: " + Object.keys(person).join(", "));' + sLineBreak +
    sLineBreak +
    '// Modifying object' + sLineBreak +
    'person.email = "john@example.com";' + sLineBreak +
    'console.log("Email added: " + person.email);' + sLineBreak +
    sLineBreak +
    '// Object.assign' + sLineBreak +
    'var extra = { phone: "555-1234", active: true };' + sLineBreak +
    'Object.assign(person, extra);' + sLineBreak +
    'console.log("After assign - phone: " + person.phone);' + sLineBreak +
    sLineBreak +
    '// HasOwnProperty' + sLineBreak +
    'console.log("Has firstName: " + person.hasOwnProperty("firstName"));' + sLineBreak +
    'console.log("Has unknown: " + person.hasOwnProperty("unknown"));');
  ListBoxExamples.Items.Add('8. Objects');

  // 9. Strings
  FExamples.Add('9. Strings',
    '// String methods' + sLineBreak +
    'console.log("=== Strings ===");' + sLineBreak +
    sLineBreak +
    'var text = "  Hello, JavaScript4D World!  ";' + sLineBreak +
    'console.log("Original: \"" + text + "\"");' + sLineBreak +
    'console.log("Length: " + text.length);' + sLineBreak +
    sLineBreak +
    '// Trim' + sLineBreak +
    'console.log("Trim: \"" + text.trim() + "\"");' + sLineBreak +
    sLineBreak +
    '// Case conversion' + sLineBreak +
    'console.log("Uppercase: " + text.trim().toUpperCase());' + sLineBreak +
    'console.log("Lowercase: " + text.trim().toLowerCase());' + sLineBreak +
    sLineBreak +
    '// Substring and slice' + sLineBreak +
    'var word = "JavaScript";' + sLineBreak +
    'console.log("Substring(0,4): " + word.substring(0, 4));' + sLineBreak +
    'console.log("Slice(-6): " + word.slice(-6));' + sLineBreak +
    sLineBreak +
    '// IndexOf and includes' + sLineBreak +
    'console.log("IndexOf(\"Script\"): " + word.indexOf("Script"));' + sLineBreak +
    'console.log("Includes(\"Java\"): " + word.includes("Java"));' + sLineBreak +
    sLineBreak +
    '// StartsWith and endsWith' + sLineBreak +
    'console.log("StartsWith(\"Java\"): " + word.startsWith("Java"));' + sLineBreak +
    'console.log("EndsWith(\"Script\"): " + word.endsWith("Script"));' + sLineBreak +
    sLineBreak +
    '// Split and join' + sLineBreak +
    'var sentence = "one,two,three,four,five";' + sLineBreak +
    'var parts = sentence.split(",");' + sLineBreak +
    'console.log("Split: " + parts.join(" | "));' + sLineBreak +
    sLineBreak +
    '// Replace' + sLineBreak +
    'console.log("Replace: " + "hello world".replace("world", "Delphi"));' + sLineBreak +
    sLineBreak +
    '// Repeat and pad' + sLineBreak +
    'console.log("Repeat: " + "ab".repeat(5));' + sLineBreak +
    'console.log("PadStart: " + "5".padStart(3, "0"));' + sLineBreak +
    'console.log("PadEnd: " + "5".padEnd(3, "0"));');
  ListBoxExamples.Items.Add('9. Strings');

  // 10. Math Object
  FExamples.Add('10. Math Object',
    '// Math functions' + sLineBreak +
    'console.log("=== Math Object ===");' + sLineBreak +
    sLineBreak +
    '// Constants' + sLineBreak +
    'console.log("Math.PI: " + Math.PI);' + sLineBreak +
    'console.log("Math.E: " + Math.E);' + sLineBreak +
    sLineBreak +
    '// Rounding' + sLineBreak +
    'var num = 4.7;' + sLineBreak +
    'console.log("Number: " + num);' + sLineBreak +
    'console.log("Math.floor: " + Math.floor(num));' + sLineBreak +
    'console.log("Math.ceil: " + Math.ceil(num));' + sLineBreak +
    'console.log("Math.round: " + Math.round(num));' + sLineBreak +
    'console.log("Math.trunc: " + Math.trunc(num));' + sLineBreak +
    sLineBreak +
    '// Mathematical functions' + sLineBreak +
    'console.log("Math.abs(-5): " + Math.abs(-5));' + sLineBreak +
    'console.log("Math.sqrt(16): " + Math.sqrt(16));' + sLineBreak +
    'console.log("Math.pow(2, 8): " + Math.pow(2, 8));' + sLineBreak +
    'console.log("Math.exp(1): " + Math.exp(1));' + sLineBreak +
    'console.log("Math.log(Math.E): " + Math.log(Math.E));' + sLineBreak +
    sLineBreak +
    '// Min and Max' + sLineBreak +
    'console.log("Math.min(3,1,4,1,5): " + Math.min(3, 1, 4, 1, 5));' + sLineBreak +
    'console.log("Math.max(3,1,4,1,5): " + Math.max(3, 1, 4, 1, 5));' + sLineBreak +
    sLineBreak +
    '// Trigonometry' + sLineBreak +
    'console.log("Math.sin(0): " + Math.sin(0));' + sLineBreak +
    'console.log("Math.cos(0): " + Math.cos(0));' + sLineBreak +
    'console.log("Math.tan(Math.PI/4): " + Math.tan(Math.PI / 4));' + sLineBreak +
    sLineBreak +
    '// Random' + sLineBreak +
    'console.log("Math.random(): " + Math.random());' + sLineBreak +
    'console.log("Random 1-10: " + (Math.floor(Math.random() * 10) + 1));');
  ListBoxExamples.Items.Add('10. Math Object');

  // 11. Date Object
  FExamples.Add('11. Date Object',
    '// Date functions' + sLineBreak +
    'console.log("=== Date Object ===");' + sLineBreak +
    sLineBreak +
    '// Current date/time' + sLineBreak +
    'var now = new Date();' + sLineBreak +
    'console.log("Current date: " + now.toString());' + sLineBreak +
    'console.log("ISO format: " + now.toISOString());' + sLineBreak +
    sLineBreak +
    '// Date components' + sLineBreak +
    'console.log("Year: " + now.getFullYear());' + sLineBreak +
    'console.log("Month (0-11): " + now.getMonth());' + sLineBreak +
    'console.log("Day: " + now.getDate());' + sLineBreak +
    'console.log("Weekday (0-6): " + now.getDay());' + sLineBreak +
    'console.log("Hours: " + now.getHours());' + sLineBreak +
    'console.log("Minutes: " + now.getMinutes());' + sLineBreak +
    'console.log("Seconds: " + now.getSeconds());' + sLineBreak +
    sLineBreak +
    '// Timestamp' + sLineBreak +
    'console.log("Timestamp (ms): " + now.getTime());' + sLineBreak +
    'console.log("Date.now(): " + Date.now());' + sLineBreak +
    sLineBreak +
    '// Create specific date' + sLineBreak +
    'var christmas = new Date(2024, 11, 25);' + sLineBreak +
    'console.log("Christmas 2024: " + christmas.toDateString());' + sLineBreak +
    sLineBreak +
    '// Date modification' + sLineBreak +
    'var date = new Date();' + sLineBreak +
    'date.setFullYear(2025);' + sLineBreak +
    'date.setMonth(0);' + sLineBreak +
    'date.setDate(1);' + sLineBreak +
    'console.log("New Year 2025: " + date.toDateString());');
  ListBoxExamples.Items.Add('11. Date Object');

  // 12. JSON
  FExamples.Add('12. JSON',
    '// JSON parse and stringify' + sLineBreak +
    'console.log("=== JSON ===");' + sLineBreak +
    sLineBreak +
    '// Object to JSON' + sLineBreak +
    'var product = {' + sLineBreak +
    '    id: 123,' + sLineBreak +
    '    name: "Laptop",' + sLineBreak +
    '    price: 999.99,' + sLineBreak +
    '    available: true,' + sLineBreak +
    '    tags: ["electronics", "computer", "portable"]' + sLineBreak +
    '};' + sLineBreak +
    sLineBreak +
    'var jsonString = JSON.stringify(product);' + sLineBreak +
    'console.log("JSON.stringify:");' + sLineBreak +
    'console.log(jsonString);' + sLineBreak +
    sLineBreak +
    '// JSON to Object' + sLineBreak +
    'var jsonInput = ''{"name":"John","age":30,"active":true}'';' + sLineBreak +
    'console.log("JSON input: " + jsonInput);' + sLineBreak +
    sLineBreak +
    'var parsed = JSON.parse(jsonInput);' + sLineBreak +
    'console.log("Parsed name: " + parsed.name);' + sLineBreak +
    'console.log("Parsed age: " + parsed.age);' + sLineBreak +
    'console.log("Parsed active: " + parsed.active);' + sLineBreak +
    sLineBreak +
    '// Nested JSON' + sLineBreak +
    'var nested = ''{"person":{"name":"Pete","address":{"city":"Rotterdam"}}}'';' + sLineBreak +
    'var obj = JSON.parse(nested);' + sLineBreak +
    'console.log("Nested city: " + obj.person.address.city);');
  ListBoxExamples.Items.Add('12. JSON');

  // 13. RegExp
  FExamples.Add('13. RegExp',
    '// Regular Expressions' + sLineBreak +
    'console.log("=== Regular Expressions ===");' + sLineBreak +
    sLineBreak +
    '// Regex literals' + sLineBreak +
    'var emailRegex = /^[a-zA-Z0-9]+@[a-zA-Z0-9]+\.[a-zA-Z]+$/;' + sLineBreak +
    sLineBreak +
    'console.log("Email validation:");' + sLineBreak +
    'console.log("test@example.com: " + emailRegex.test("test@example.com"));' + sLineBreak +
    'console.log("invalid-email: " + emailRegex.test("invalid-email"));' + sLineBreak +
    sLineBreak +
    '// RegExp constructor' + sLineBreak +
    'var numberRegex = new RegExp("^[0-9]+$");' + sLineBreak +
    'console.log("Number validation:");' + sLineBreak +
    'console.log("12345: " + numberRegex.test("12345"));' + sLineBreak +
    'console.log("abc123: " + numberRegex.test("abc123"));' + sLineBreak +
    sLineBreak +
    '// String match' + sLineBreak +
    'var text = "The price is 100 euros or 150 dollars";' + sLineBreak +
    'var matches = text.match(/[0-9]+/g);' + sLineBreak +
    'if (matches) {' + sLineBreak +
    '    console.log("Found numbers: " + matches.join(", "));' + sLineBreak +
    '}' + sLineBreak +
    sLineBreak +
    '// String replace with regex' + sLineBreak +
    'var sentence = "hello world hello";' + sLineBreak +
    'var replaced = sentence.replace(/hello/g, "hi");' + sLineBreak +
    'console.log("Replace: " + replaced);' + sLineBreak +
    sLineBreak +
    '// String split with regex' + sLineBreak +
    'var data = "one;two,three:four";' + sLineBreak +
    'var parts = data.split(/[;,:]/);' + sLineBreak +
    'console.log("Split with regex: " + parts.join(" | "));');
  ListBoxExamples.Items.Add('13. RegExp');

  // 14. Error Handling
  FExamples.Add('14. Error Handling',
    '// Try/Catch/Finally' + sLineBreak +
    'console.log("=== Error Handling ===");' + sLineBreak +
    sLineBreak +
    '// Basic try/catch' + sLineBreak +
    'try {' + sLineBreak +
    '    console.log("Code in try block...");' + sLineBreak +
    '    throw new Error("This is a test error!");' + sLineBreak +
    '} catch (e) {' + sLineBreak +
    '    console.log("Caught: " + e.message);' + sLineBreak +
    '} finally {' + sLineBreak +
    '    console.log("Finally block executed");' + sLineBreak +
    '}' + sLineBreak +
    sLineBreak +
    '// Different error types' + sLineBreak +
    'console.log("Error types:");' + sLineBreak +
    sLineBreak +
    'try {' + sLineBreak +
    '    throw new TypeError("Type error!");' + sLineBreak +
    '} catch (e) {' + sLineBreak +
    '    console.log("TypeError: " + e.message);' + sLineBreak +
    '}' + sLineBreak +
    sLineBreak +
    'try {' + sLineBreak +
    '    throw new RangeError("Value out of range!");' + sLineBreak +
    '} catch (e) {' + sLineBreak +
    '    console.log("RangeError: " + e.message);' + sLineBreak +
    '}' + sLineBreak +
    sLineBreak +
    '// Custom error throwing' + sLineBreak +
    'function validate(value) {' + sLineBreak +
    '    if (value < 0) {' + sLineBreak +
    '        throw new RangeError("Value cannot be negative");' + sLineBreak +
    '    }' + sLineBreak +
    '    return value * 2;' + sLineBreak +
    '}' + sLineBreak +
    sLineBreak +
    'try {' + sLineBreak +
    '    console.log("validate(5): " + validate(5));' + sLineBreak +
    '    console.log("validate(-3): " + validate(-3));' + sLineBreak +
    '} catch (e) {' + sLineBreak +
    '    console.log("Validation error: " + e.message);' + sLineBreak +
    '}');
  ListBoxExamples.Items.Add('14. Error Handling');

  // 15. Closures
  FExamples.Add('15. Closures',
    '// Closures and scope' + sLineBreak +
    'console.log("=== Closures ===");' + sLineBreak +
    sLineBreak +
    '// Basic closure' + sLineBreak +
    'function makeCounter() {' + sLineBreak +
    '    var count = 0;' + sLineBreak +
    '    return function() {' + sLineBreak +
    '        count++;' + sLineBreak +
    '        return count;' + sLineBreak +
    '    };' + sLineBreak +
    '}' + sLineBreak +
    sLineBreak +
    'var counter1 = makeCounter();' + sLineBreak +
    'var counter2 = makeCounter();' + sLineBreak +
    sLineBreak +
    'console.log("Counter1: " + counter1());' + sLineBreak +
    'console.log("Counter1: " + counter1());' + sLineBreak +
    'console.log("Counter1: " + counter1());' + sLineBreak +
    'console.log("Counter2: " + counter2());' + sLineBreak +
    sLineBreak +
    '// Factory function' + sLineBreak +
    'function makeMultiplier(factor) {' + sLineBreak +
    '    return function(number) {' + sLineBreak +
    '        return number * factor;' + sLineBreak +
    '    };' + sLineBreak +
    '}' + sLineBreak +
    sLineBreak +
    'var double = makeMultiplier(2);' + sLineBreak +
    'var triple = makeMultiplier(3);' + sLineBreak +
    sLineBreak +
    'console.log("Double 5: " + double(5));' + sLineBreak +
    'console.log("Triple 5: " + triple(5));' + sLineBreak +
    sLineBreak +
    '// Simulating private variables' + sLineBreak +
    'function makeBankAccount(initialBalance) {' + sLineBreak +
    '    var balance = initialBalance;' + sLineBreak +
    '    return {' + sLineBreak +
    '        deposit: function(amount) {' + sLineBreak +
    '            balance += amount;' + sLineBreak +
    '            return balance;' + sLineBreak +
    '        },' + sLineBreak +
    '        withdraw: function(amount) {' + sLineBreak +
    '            if (amount <= balance) {' + sLineBreak +
    '                balance -= amount;' + sLineBreak +
    '                return balance;' + sLineBreak +
    '            }' + sLineBreak +
    '            return "Insufficient funds";' + sLineBreak +
    '        },' + sLineBreak +
    '        getBalance: function() {' + sLineBreak +
    '            return balance;' + sLineBreak +
    '        }' + sLineBreak +
    '    };' + sLineBreak +
    '}' + sLineBreak +
    sLineBreak +
    'var account = makeBankAccount(100);' + sLineBreak +
    'console.log("Initial balance: " + account.getBalance());' + sLineBreak +
    'console.log("After deposit 50: " + account.deposit(50));' + sLineBreak +
    'console.log("After withdraw 30: " + account.withdraw(30));');
  ListBoxExamples.Items.Add('15. Closures');

  // 16. Practical Example
  FExamples.Add('16. Practical Example',
    '// Practical example: Data transformation' + sLineBreak +
    'console.log("=== Practical Example ===");' + sLineBreak +
    sLineBreak +
    '// Simulate API data' + sLineBreak +
    'var orders = [' + sLineBreak +
    '    { id: 1, customer: "John", product: "Laptop", price: 999, status: "shipped" },' + sLineBreak +
    '    { id: 2, customer: "Pete", product: "Phone", price: 599, status: "paid" },' + sLineBreak +
    '    { id: 3, customer: "Mary", product: "Tablet", price: 449, status: "shipped" },' + sLineBreak +
    '    { id: 4, customer: "John", product: "Headphones", price: 199, status: "new" },' + sLineBreak +
    '    { id: 5, customer: "Chris", product: "Monitor", price: 349, status: "shipped" }' + sLineBreak +
    '];' + sLineBreak +
    sLineBreak +
    'console.log("Total orders: " + orders.length);' + sLineBreak +
    sLineBreak +
    '// Filter shipped orders' + sLineBreak +
    'var shipped = orders.filter(function(o) {' + sLineBreak +
    '    return o.status == "shipped";' + sLineBreak +
    '});' + sLineBreak +
    'console.log("Shipped orders: " + shipped.length);' + sLineBreak +
    sLineBreak +
    '// Calculate total revenue' + sLineBreak +
    'var totalRevenue = orders.reduce(function(sum, o) {' + sLineBreak +
    '    return sum + o.price;' + sLineBreak +
    '}, 0);' + sLineBreak +
    'console.log("Total revenue: " + totalRevenue + " euros");' + sLineBreak +
    sLineBreak +
    '// Average order value' + sLineBreak +
    'var average = totalRevenue / orders.length;' + sLineBreak +
    'console.log("Average order: " + Math.round(average) + " euros");' + sLineBreak +
    sLineBreak +
    '// Orders per customer' + sLineBreak +
    'var johnOrders = orders.filter(function(o) {' + sLineBreak +
    '    return o.customer == "John";' + sLineBreak +
    '});' + sLineBreak +
    'console.log("Orders by John: " + johnOrders.length);' + sLineBreak +
    sLineBreak +
    '// Create overview' + sLineBreak +
    'var overview = orders.map(function(o) {' + sLineBreak +
    '    return o.customer + ": " + o.product + " (" + o.price + " euros)";' + sLineBreak +
    '});' + sLineBreak +
    'console.log("Overview:");' + sLineBreak +
    'overview.forEach(function(line) {' + sLineBreak +
    '    console.log("  " + line);' + sLineBreak +
    '});' + sLineBreak +
    sLineBreak +
    '// Export as JSON' + sLineBreak +
    'var report = {' + sLineBreak +
    '    totalOrders: orders.length,' + sLineBreak +
    '    totalRevenue: totalRevenue,' + sLineBreak +
    '    averageOrder: Math.round(average),' + sLineBreak +
    '    shippedOrders: shipped.length' + sLineBreak +
    '};' + sLineBreak +
    'console.log("JSON Report:");' + sLineBreak +
    'console.log(JSON.stringify(report));');
  ListBoxExamples.Items.Add('16. Practical Example');
end;

procedure TFormMain.WriteOutput(const Text: string);
begin
  MemoOutput.Lines.Add(Text);
end;

procedure TFormMain.WriteDelphiOutput(const Text: string);
begin
  MemoDelphiOutput.Lines.Add(Text);
end;

procedure TFormMain.RunCode(const Code: string; OutputMemo: TMemo);
begin
  FEngine.Free;
  FEngine := TJSEngine.Create;

  FEngine.OnConsoleOutput :=
    procedure(const Output: string)
    begin
      OutputMemo.Lines.Add('console: ' + Output);
    end;

  try
    var Result := FEngine.Execute(Code);

    if not Result.IsUndefined then
      OutputMemo.Lines.Add('=> ' + Result.ToString);
  except
    on E: Exception do
      OutputMemo.Lines.Add('ERROR: ' + E.Message);
  end;
end;

procedure TFormMain.ListBoxExamplesClick(Sender: TObject);
begin
  if ListBoxExamples.ItemIndex >= 0 then
  begin
    var ExampleName := ListBoxExamples.Items[ListBoxExamples.ItemIndex];
    if FExamples.ContainsKey(ExampleName) then
      MemoExampleCode.Lines.Text := FExamples[ExampleName];
  end;
end;

procedure TFormMain.ButtonRunExampleClick(Sender: TObject);
begin
  MemoOutput.Lines.Clear;

  if ListBoxExamples.ItemIndex >= 0 then
  begin
    MemoOutput.Lines.Add('--- ' + ListBoxExamples.Items[ListBoxExamples.ItemIndex] + ' ---');
    RunCode(MemoExampleCode.Lines.Text, MemoOutput);
    MemoOutput.Lines.Add('--- Done ---');
  end;
end;

procedure TFormMain.ButtonRunDelphiDemoClick(Sender: TObject);
var
  Engine: TJSEngine;
begin
  MemoDelphiOutput.Lines.Clear;
  MemoDelphiOutput.Lines.Add('=== Delphi Integration Demo ===');
  MemoDelphiOutput.Lines.Add('');

  Engine := TJSEngine.Create;
  try
    // Console output handler
    Engine.OnConsoleOutput :=
      procedure(const Output: string)
      begin
        WriteDelphiOutput('JS Console: ' + Output);
      end;

    // 1. Setting variables from Delphi
    MemoDelphiOutput.Lines.Add('1. Setting variables from Delphi:');
    Engine.SetNumber('delphiNumber', 42);
    Engine.SetString('delphiText', 'Hello from Delphi!');
    Engine.SetBoolean('delphiBoolean', True);

    Engine.Execute('console.log("delphiNumber = " + delphiNumber);');
    Engine.Execute('console.log("delphiText = " + delphiText);');
    Engine.Execute('console.log("delphiBoolean = " + delphiBoolean);');
    MemoDelphiOutput.Lines.Add('');

    // 2. Reading variables in Delphi
    MemoDelphiOutput.Lines.Add('2. Reading variables in Delphi:');
    Engine.Execute('var jsResult = delphiNumber * 2 + 10;');
    var Result := Engine.GetNumber('jsResult');
    MemoDelphiOutput.Lines.Add(Format('   jsResult (in Delphi): %.0f', [Result]));
    MemoDelphiOutput.Lines.Add('');

    // 3. Registering custom Delphi functions
    MemoDelphiOutput.Lines.Add('3. Registering custom Delphi functions:');

    // Function: formatCurrency
    Engine.RegisterFunction('formatCurrency',
      function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
      begin
        if Length(Args) >= 1 then
          Result := TJSValue.CreateString(Format('%.2f EUR', [Args[0].ToNumber]))
        else
          Result := TJSValue.CreateString('0.00 EUR');
      end);

    // Function: getDelphiVersion
    Engine.RegisterFunction('getDelphiVersion',
      function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
      begin
        {$IFDEF VER360}
        Result := TJSValue.CreateString('Delphi 12 Athens');
        {$ELSE}
        {$IFDEF VER350}
        Result := TJSValue.CreateString('Delphi 11 Alexandria');
        {$ELSE}
        Result := TJSValue.CreateString('Delphi (unknown version)');
        {$ENDIF}
        {$ENDIF}
      end);

    // Function: showMessage (calls Delphi ShowMessage)
    Engine.RegisterFunction('delphiAlert',
      function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
      begin
        if Length(Args) >= 1 then
          ShowMessage('JavaScript says: ' + Args[0].ToString);
        Result := TJSValue.CreateUndefined;
      end);

    // Function: currentDateTime
    Engine.RegisterFunction('getDelphiDateTime',
      function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
      begin
        Result := TJSValue.CreateString(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      end);

    // Function: calculate with Delphi Math
    Engine.RegisterFunction('delphiSqrt',
      function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
      begin
        if (Length(Args) >= 1) and (Args[0].ToNumber >= 0) then
          Result := TJSValue.CreateNumber(Sqrt(Args[0].ToNumber))
        else
          Result := TJSValue.CreateNaN;
      end);

    Engine.Execute('console.log("formatCurrency(1234.5) = " + formatCurrency(1234.5));');
    Engine.Execute('console.log("getDelphiVersion() = " + getDelphiVersion());');
    Engine.Execute('console.log("getDelphiDateTime() = " + getDelphiDateTime());');
    Engine.Execute('console.log("delphiSqrt(144) = " + delphiSqrt(144));');
    MemoDelphiOutput.Lines.Add('');

    // 4. Complex data exchange
    MemoDelphiOutput.Lines.Add('4. Complex data exchange via JSON:');

    // Delphi object to JavaScript via JSON
    var JSONData := '{"products":[{"name":"Laptop","price":999},{"name":"Mouse","price":29}],"discount":10}';
    Engine.SetString('jsonData', JSONData);

    Engine.Execute(
      'var cart = JSON.parse(jsonData);' + sLineBreak +
      'var total = cart.products.reduce(function(sum, p) { return sum + p.price; }, 0);' + sLineBreak +
      'var discountAmount = total * (cart.discount / 100);' + sLineBreak +
      'var finalTotal = total - discountAmount;' + sLineBreak +
      'console.log("Subtotal: " + formatCurrency(total));' + sLineBreak +
      'console.log("Discount (" + cart.discount + "%): -" + formatCurrency(discountAmount));' + sLineBreak +
      'console.log("Final total: " + formatCurrency(finalTotal));' + sLineBreak +
      'var result = JSON.stringify({ subtotal: total, discount: discountAmount, total: finalTotal });'
    );

    var JSONResult := Engine.GetString('result');
    MemoDelphiOutput.Lines.Add('   JSON result in Delphi: ' + JSONResult);
    MemoDelphiOutput.Lines.Add('');

    // 5. Calling JavaScript functions
    MemoDelphiOutput.Lines.Add('5. Defining and calling JavaScript functions:');

    Engine.Execute(
      'function calculateVAT(amount, percentage) {' + sLineBreak +
      '    return amount * (percentage / 100);' + sLineBreak +
      '}' + sLineBreak +
      'function calculateTotalWithVAT(amount, vatPercentage) {' + sLineBreak +
      '    var vat = calculateVAT(amount, vatPercentage);' + sLineBreak +
      '    return { net: amount, vat: vat, gross: amount + vat };' + sLineBreak +
      '}'
    );

    Engine.SetNumber('testAmount', 100);
    Engine.SetNumber('vatPercentage', 21);
    Engine.Execute('var vatResult = calculateTotalWithVAT(testAmount, vatPercentage);');
    Engine.Execute('console.log("Net: " + formatCurrency(vatResult.net));');
    Engine.Execute('console.log("VAT (21%): " + formatCurrency(vatResult.vat));');
    Engine.Execute('console.log("Gross: " + formatCurrency(vatResult.gross));');

    MemoDelphiOutput.Lines.Add('');
    MemoDelphiOutput.Lines.Add('=== Demo completed ===');

  finally
    Engine.Free;
  end;
end;

end.
