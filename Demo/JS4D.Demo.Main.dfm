object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'JavaScript4D Demo - ES5.1 JavaScript Interpreter for Delphi'
  ClientHeight = 700
  ClientWidth = 1100
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    1100
    700)
  TextHeight = 15
  object SplitterMain: TSplitter
    Left = 0
    Top = 420
    Width = 1100
    Height = 5
    Cursor = crVSplit
    Align = alBottom
    ExplicitTop = 400
    ExplicitWidth = 1000
  end
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 1100
    Height = 420
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object PageControlMain: TPageControl
      Left = 0
      Top = 0
      Width = 1100
      Height = 420
      ActivePage = TabSheetExamples
      Align = alClient
      TabOrder = 0
      object TabSheetExamples: TTabSheet
        Caption = 'Examples'
        object SplitterExamples: TSplitter
          Left = 225
          Top = 0
          Height = 390
          ExplicitLeft = 200
          ExplicitTop = 8
          ExplicitHeight = 382
        end
        object PanelExampleLeft: TPanel
          Left = 0
          Top = 0
          Width = 225
          Height = 390
          Align = alLeft
          BevelOuter = bvNone
          TabOrder = 0
          object LabelExamples: TLabel
            Left = 8
            Top = 8
            Width = 101
            Height = 15
            Caption = 'Select an example:'
          end
          object ListBoxExamples: TListBox
            Left = 8
            Top = 27
            Width = 209
            Height = 318
            Anchors = [akLeft, akTop, akBottom]
            ItemHeight = 15
            TabOrder = 0
            OnClick = ListBoxExamplesClick
          end
          object ButtonRunExample: TButton
            Left = 8
            Top = 351
            Width = 209
            Height = 30
            Anchors = [akLeft, akBottom]
            Caption = 'Run Example'
            TabOrder = 1
            OnClick = ButtonRunExampleClick
          end
        end
        object PanelExampleRight: TPanel
          Left = 228
          Top = 0
          Width = 856
          Height = 390
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 1
          object LabelExampleCode: TLabel
            Left = 8
            Top = 8
            Width = 80
            Height = 15
            Caption = 'Example Code:'
          end
          object MemoExampleCode: TMemo
            Left = 8
            Top = 27
            Width = 840
            Height = 355
            Anchors = [akLeft, akTop, akRight, akBottom]
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -13
            Font.Name = 'Consolas'
            Font.Style = []
            ParentFont = False
            ScrollBars = ssBoth
            TabOrder = 0
            WordWrap = False
          end
        end
      end
      object TabSheetDelphi: TTabSheet
        Caption = 'Delphi Integration'
        ImageIndex = 1
        object LabelDelphiOutput: TLabel
          Left = 8
          Top = 200
          Width = 40
          Height = 15
          Caption = 'Output:'
        end
        object MemoDelphiInfo: TMemo
          Left = 8
          Top = 8
          Width = 1064
          Height = 145
          Anchors = [akLeft, akTop, akRight]
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Consolas'
          Font.Style = []
          Lines.Strings = (
            '=== JavaScript4D - Delphi Integration Demo ==='
            ''
            'This demo shows how to use JavaScript4D in your Delphi application:'
            ''
            '1. SET VARIABLES from Delphi:'
            '   Engine.SetNumber('#39'number'#39', 42);'
            '   Engine.SetString('#39'text'#39', '#39'Hello'#39');'
            '   Engine.SetBoolean('#39'active'#39', True);'
            ''
            '2. READ VARIABLES in Delphi:'
            '   var Value := Engine.GetNumber('#39'jsVariable'#39');'
            '   var Text := Engine.GetString('#39'jsString'#39');'
            ''
            '3. REGISTER CUSTOM FUNCTIONS:'
            '   Engine.RegisterFunction('#39'myFunction'#39','
            '     function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue'
            '     begin'
            '       // Delphi code here'
            '       Result := TJSValue.CreateString('#39'Result'#39');'
            '     end);'
            ''
            '4. CAPTURE CONSOLE OUTPUT:'
            '   Engine.OnConsoleOutput := procedure(const Output: string)'
            '   begin'
            '     Memo1.Lines.Add(Output);'
            '   end;'
            ''
            'Click "Run Delphi Demo" to see all integration options!')
          ParentFont = False
          ReadOnly = True
          ScrollBars = ssVertical
          TabOrder = 0
        end
        object ButtonRunDelphiDemo: TButton
          Left = 8
          Top = 159
          Width = 150
          Height = 35
          Caption = 'Run Delphi Demo'
          TabOrder = 1
          OnClick = ButtonRunDelphiDemoClick
        end
        object PanelDelphiBottom: TPanel
          Left = 0
          Top = 219
          Width = 1084
          Height = 171
          Anchors = [akLeft, akTop, akRight, akBottom]
          BevelOuter = bvNone
          TabOrder = 2
          object MemoDelphiOutput: TMemo
            Left = 8
            Top = 0
            Width = 1064
            Height = 163
            Anchors = [akLeft, akTop, akRight, akBottom]
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -13
            Font.Name = 'Consolas'
            Font.Style = []
            ParentFont = False
            ScrollBars = ssBoth
            TabOrder = 0
            WordWrap = False
          end
        end
      end
    end
  end
  object PanelBottom: TPanel
    Left = 0
    Top = 425
    Width = 1100
    Height = 275
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object LabelOutput: TLabel
      Left = 8
      Top = 8
      Width = 42
      Height = 15
      Caption = 'Output:'
    end
    object MemoOutput: TMemo
      Left = 8
      Top = 27
      Width = 1084
      Height = 240
      Anchors = [akLeft, akTop, akRight, akBottom]
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssBoth
      TabOrder = 0
      WordWrap = False
    end
  end
end
