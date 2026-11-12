unit JS4D.Tests.GlobalDeclarations;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TGlobalDeclarationTests = class
  private
    FEngine: TJSEngine;

    function EvaluatesToTrue(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure StrictAssignment_ToNonWritableGlobal_ThrowsTypeError;

    [Test]
    procedure StrictAssignment_ToNonWritableGlobalInsideFunction_ThrowsTypeError;

    [Test]
    procedure SloppyAssignment_ToNonWritableGlobal_IsIgnored;

    [Test]
    procedure EvalVar_OnNonExtensibleGlobal_ThrowsTypeErrorBeforeRunning;

    [Test]
    procedure EvalFunction_OnNonExtensibleGlobal_ThrowsTypeErrorBeforeRunning;

    [Test]
    procedure EvalFunction_OverConfigurableGlobalProperty_RedefinesAttributes;

    [Test]
    procedure ScriptFunction_OverConfigurableGlobalProperty_DefinesNonConfigurable;

    [Test]
    procedure ScriptFunction_OverNonConfigurableDataProperty_KeepsAttributes;

    [Test]
    procedure EvalVar_InFunction_CanBeDeleted;

    [Test]
    procedure EvalVar_InFunction_IsGoneAfterDelete;

    [Test]
    procedure EvalVar_InFunction_IsNotDeletableWhenDeclaredByVar;
  end;

implementation

procedure TGlobalDeclarationTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TGlobalDeclarationTests.TearDown;
begin
  FEngine.Free;
end;

function TGlobalDeclarationTests.EvaluatesToTrue(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

procedure TGlobalDeclarationTests.StrictAssignment_ToNonWritableGlobal_ThrowsTypeError;
begin
  const Script = '"use strict"; try { NaN = 12; false; } catch (e) { e instanceof TypeError; }';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalDeclarationTests.StrictAssignment_ToNonWritableGlobalInsideFunction_ThrowsTypeError;
begin
  const Script = '"use strict"; try { (function () { undefined = 12; })(); false; } catch (e) { e instanceof TypeError; }';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalDeclarationTests.SloppyAssignment_ToNonWritableGlobal_IsIgnored;
begin
  const Script = 'NaN = 12; isNaN(NaN);';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalDeclarationTests.EvalVar_OnNonExtensibleGlobal_ThrowsTypeErrorBeforeRunning;
begin
  const Script = 'var executed = false; var error;' +
                 'Object.preventExtensions(this);' +
                 'try { (0, eval)("executed = true; var test262Var;"); } catch (e) { error = e; }' +
                 'error instanceof TypeError && executed === false;';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalDeclarationTests.EvalFunction_OnNonExtensibleGlobal_ThrowsTypeErrorBeforeRunning;
begin
  const Script = 'var executed = false; var error;' +
                 'Object.preventExtensions(this);' +
                 'try { (0, eval)("executed = true; function test262Function() {}"); } catch (e) { error = e; }' +
                 'error instanceof TypeError && executed === false;';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalDeclarationTests.EvalFunction_OverConfigurableGlobalProperty_RedefinesAttributes;
begin
  const Script = 'Object.defineProperty(this, "f", { enumerable: false, writable: false, configurable: true });' +
                 '(0, eval)("function f() { return 345; }");' +
                 'var descriptor = Object.getOwnPropertyDescriptor(this, "f");' +
                 'descriptor.writable && descriptor.enumerable && descriptor.configurable && f() === 345;';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalDeclarationTests.ScriptFunction_OverConfigurableGlobalProperty_DefinesNonConfigurable;
begin
  FEngine.Execute('Object.defineProperty(this, "configurable", { configurable: true, value: 0 });' +
                  'Object.preventExtensions(this);');

  FEngine.Execute('function configurable() {}');

  const Script = '(function (global) {' +
                 '  var descriptor = Object.getOwnPropertyDescriptor(global, "configurable");' +
                 '  return typeof configurable === "function" && descriptor.writable && descriptor.enumerable &&' +
                 '         !descriptor.configurable;' +
                 '})(this);';
  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalDeclarationTests.ScriptFunction_OverNonConfigurableDataProperty_KeepsAttributes;
begin
  FEngine.Execute('Object.defineProperty(this, "fixed", { configurable: false, writable: true, enumerable: true,' +
                  ' value: 0 });');

  FEngine.Execute('function fixed() {}');

  const Script = 'var descriptor = Object.getOwnPropertyDescriptor(this, "fixed");' +
                 'typeof fixed === "function" && descriptor.writable && descriptor.enumerable &&' +
                 ' !descriptor.configurable;';
  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalDeclarationTests.EvalVar_InFunction_CanBeDeleted;
begin
  const Script = 'var deleted; (function () { eval("var x; deleted = delete x;"); })(); deleted;';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalDeclarationTests.EvalVar_InFunction_IsGoneAfterDelete;
begin
  const Script = 'var error;' +
                 '(function () {' +
                 '  eval("delete x; var read = function () { x; }; var x;");' +
                 '  try { read(); } catch (e) { error = e; }' +
                 '})();' +
                 'error instanceof ReferenceError;';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalDeclarationTests.EvalVar_InFunction_IsNotDeletableWhenDeclaredByVar;
begin
  const Script = 'var deleted = true; (function () { var x; eval("deleted = delete x;"); })(); deleted === false;';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

end.
