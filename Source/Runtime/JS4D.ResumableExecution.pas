unit JS4D.ResumableExecution;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.AST,
  JS4D.StrictThis,
  JS4D.GeneratorObjects,
  JS4D.ControlFlow,
  JS4D.StatementFrame;

const
  LABELED_LOOP_TYPES = [TJSASTNodeType.WhileStatement,
                        TJSASTNodeType.DoWhileStatement,
                        TJSASTNodeType.ForStatement,
                        TJSASTNodeType.ForInStatement,
                        TJSASTNodeType.ForOfStatement,
                        TJSASTNodeType.LabeledStatement];
  NO_CASE = -1;
  NOT_ITERABLE_LOOP = 'Value is not iterable';
  ITERATOR_NOT_AN_OBJECT = 'The Symbol.iterator method did not return an object';
  ITERATOR_NEXT_PROPERTY = 'next';

type
  TJSCallContext = record
    Callee: Pointer;
    NewTarget: Pointer;
    Binding: Pointer;
  end;

  TJSExecutionState = record
    ThisValue: IJSObject;
    ThisPrimitive: TJSStrictThis;
    StrictMode: Boolean;
    Scope: IJSScope;
    VarScope: IJSScope;
    Context: TJSCallContext;
    Generator: TJSGeneratorObject;
  end;

  TJSResumableExecution = class abstract
  public
    procedure AttachGeneratorPrototype(const Func: IJSFunction); virtual; abstract;
    function CaptureExecutionState: TJSExecutionState; virtual; abstract;
    procedure ConvertToAsyncFunction(const Func: IJSFunction); virtual; abstract;
    procedure ConvertToGeneratorFunction(const Func: IJSFunction); virtual; abstract;
    function CreateGeneratorObject(const Func: IJSFunction): TJSValue; virtual; abstract;
    procedure DefinePrototypeProperty(const Func: IJSFunction; const PrototypeObject: IJSObject;
                                      const IsWritable: Boolean); virtual; abstract;
    function FrameFor(const Node: TJSASTNode): TJSStatementFrame; virtual; abstract;
    procedure InitializeDeclarator(const Node: TJSVariableDeclaration;
                                   const Declarator: TJSVariableDeclarator); virtual; abstract;
    procedure RestoreExecutionState(const State: TJSExecutionState); virtual; abstract;
    function StartAsyncFunction(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                const Body: TJSBlockStatement): TJSValue; virtual; abstract;
    function VisitAwait(const Node: TJSAwaitExpression): TJSValue; virtual; abstract;
    function VisitRemembered(const Node: TJSASTNode): TJSValue; virtual; abstract;
    function VisitYield(const Node: TJSYieldExpression): TJSValue; virtual; abstract;
    function ResumeGenerator(const Generator: TJSGeneratorObject; const Mode: TJSResumeMode;
                             const Value: TJSValue): TJSValue; virtual; abstract;
    function AdvanceBody(const Body: IJSGenerator; const Mode: TJSResumeMode;
                         const Value: TJSValue): TJSBodyResult; virtual; abstract;
  end;

implementation

end.
