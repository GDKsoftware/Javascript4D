unit JS4D.Tests.DeleteIdentifier;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Engine;

type
  [TestFixture]
  TDeleteIdentifierTests = class
  private
    FEngine: TJSEngine;

    function EvaluatesToTrue(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Delete_OwnPropertyOfWithObject_RemovesPropertyAndReturnsTrue;

    [Test]
    procedure Delete_InheritedPropertyOfWithObject_ReturnsTrueAndKeepsProperty;

    [Test]
    procedure Delete_NonConfigurablePropertyOfWithObject_ReturnsFalse;

    [Test]
    procedure Delete_UnresolvableName_ReturnsTrue;

    [Test]
    procedure Delete_FunctionLocalVariable_ReturnsFalse;

    [Test]
    procedure Delete_GlobalVar_ReturnsFalseAndKeepsVariable;

    [Test]
    procedure Delete_ImplicitGlobal_RemovesVariable;

    [Test]
    procedure Delete_GlobalPropertyCreatedThroughThis_RemovesVariable;

    [Test]
    procedure GlobalVar_IsNotConfigurable;

    [Test]
    procedure GlobalVar_RedeclarationKeepsAttributes;

    [Test]
    procedure GlobalFunctionDeclaration_IsNotConfigurable;

    [Test]
    procedure StrictAssignment_BindingDeletedByRightHandSideInWith_ThrowsReferenceError;

    [Test]
    procedure StrictCompoundAssignment_BindingDeletedByGetterOnGlobal_ThrowsReferenceError;

    [Test]
    procedure StrictIncrement_BindingDeletedByGetterInWith_ThrowsReferenceError;

    [Test]
    procedure SloppyAssignment_BindingDeletedByRightHandSideInWith_RecreatesPropertyOnWithObject;
  end;

implementation

procedure TDeleteIdentifierTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TDeleteIdentifierTests.TearDown;
begin
  FEngine.Free;
end;

function TDeleteIdentifierTests.EvaluatesToTrue(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).ToBoolean;
end;

procedure TDeleteIdentifierTests.Delete_OwnPropertyOfWithObject_RemovesPropertyAndReturnsTrue;
begin
  const Script = 'var o = {p: 1}; var r; with (o) { r = delete p; } r === true && !o.hasOwnProperty("p")';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TDeleteIdentifierTests.Delete_InheritedPropertyOfWithObject_ReturnsTrueAndKeepsProperty;
begin
  const Script = 'function P() {} P.prototype.q = 2; var o = new P(); var r; with (o) { r = delete q; } ' +
                 'r === true && o.q === 2';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TDeleteIdentifierTests.Delete_NonConfigurablePropertyOfWithObject_ReturnsFalse;
begin
  const Script = 'var o = {}; Object.defineProperty(o, "p", {value: 1, configurable: false}); var r; ' +
                 'with (o) { r = delete p; } r === false && o.p === 1';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TDeleteIdentifierTests.Delete_UnresolvableName_ReturnsTrue;
begin
  Assert.IsTrue(EvaluatesToTrue('delete neverDeclared === true'));
end;

procedure TDeleteIdentifierTests.Delete_FunctionLocalVariable_ReturnsFalse;
begin
  const Script = 'function f(a) { var b = 1; return [delete a, delete b, a, b].join(); } f(7) === "false,false,7,1"';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TDeleteIdentifierTests.Delete_GlobalVar_ReturnsFalseAndKeepsVariable;
begin
  Assert.IsTrue(EvaluatesToTrue('var kept = 3; (delete kept) === false && kept === 3'));
end;

procedure TDeleteIdentifierTests.Delete_ImplicitGlobal_RemovesVariable;
begin
  const Script = 'implicit = 4; (delete implicit) === true && typeof implicit === "undefined"';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TDeleteIdentifierTests.Delete_GlobalPropertyCreatedThroughThis_RemovesVariable;
begin
  const Script = 'this.viaThis = 5; (delete viaThis) === true && typeof viaThis === "undefined"';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TDeleteIdentifierTests.GlobalVar_IsNotConfigurable;
begin
  const Script = 'var declared = 1; var d = Object.getOwnPropertyDescriptor(this, "declared"); ' +
                 'd.configurable === false && d.writable === true && d.enumerable === true';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TDeleteIdentifierTests.GlobalVar_RedeclarationKeepsAttributes;
begin
  const Script = 'var twice = 1; var twice = 2; var d = Object.getOwnPropertyDescriptor(this, "twice"); ' +
                 'd.configurable === false && d.value === 2';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TDeleteIdentifierTests.GlobalFunctionDeclaration_IsNotConfigurable;
begin
  const Script = 'function declaredFn() {} ' +
                 'Object.getOwnPropertyDescriptor(this, "declaredFn").configurable === false';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TDeleteIdentifierTests.StrictAssignment_BindingDeletedByRightHandSideInWith_ThrowsReferenceError;
begin
  const Script = 'var scope = {x: 1}, name; with (scope) { (function() { "use strict"; ' +
                 'try { x = (delete scope.x, 2); } catch (e) { name = e.name; } })(); } ' +
                 'name === "ReferenceError" && !("x" in scope)';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TDeleteIdentifierTests.StrictCompoundAssignment_BindingDeletedByGetterOnGlobal_ThrowsReferenceError;
begin
  const Script = 'Object.defineProperty(this, "g", {configurable: true, get: function() { delete this.g; return 2; }}); ' +
                 'var name; (function() { "use strict"; try { g ^= 3; } catch (e) { name = e.name; } })(); ' +
                 'name === "ReferenceError" && !("g" in this)';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TDeleteIdentifierTests.StrictIncrement_BindingDeletedByGetterInWith_ThrowsReferenceError;
begin
  const Script = 'var scope = {get x() { delete this.x; return 2; }}, name; with (scope) { ' +
                 '(function() { "use strict"; try { ++x; } catch (e) { name = e.name; } })(); } ' +
                 'name === "ReferenceError" && !("x" in scope)';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TDeleteIdentifierTests.SloppyAssignment_BindingDeletedByRightHandSideInWith_RecreatesPropertyOnWithObject;
begin
  const Script = 'var scope = {x: 1}; with (scope) { x = (delete scope.x, 2); } ' +
                 'scope.x === 2';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

end.
