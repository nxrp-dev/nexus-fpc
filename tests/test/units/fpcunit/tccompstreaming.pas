Unit tccompstreaming;

{$mode objfpc}

interface

Uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, SysUtils,Classes,tcstreaming;

Type

{ TTestComponentStream }

TTestComponentStream = Class(TTestStreaming)
  public
    Procedure TestTEmptyComponent;
    Procedure TestTIntegerComponent;
    Procedure TestTIntegerComponent2;
    Procedure TestTIntegerComponent3;
    Procedure TestTIntegerComponent4;
    Procedure TestTIntegerComponent5;
    Procedure TestTInt64Component;
    Procedure TestTInt64Component2;
    Procedure TestTInt64Component3;
    Procedure TestTInt64Component4;
    Procedure TestTInt64Component5;
    Procedure TestTInt64Component6;
    Procedure TestTStringComponent;
    Procedure TestTStringComponent2;
    Procedure TestTWideStringComponent;
    Procedure TestTWideStringComponent2;
    Procedure TestTSingleComponent;
    Procedure TestTDoubleComponent;
    Procedure TestTExtendedComponent;
    Procedure TestTCompComponent;
    Procedure TestTCurrencyComponent;
    Procedure TestTDateTimeComponent;
    Procedure TestTDateTimeComponent2;
    Procedure TestTDateTimeComponent3;
    Procedure TestTEnumComponent;
    Procedure TestTEnumComponent2;
    Procedure TestTEnumComponent3;
    Procedure TestTEnumComponent4;
    Procedure TestTEnumComponent5;
    Procedure TestTSetComponent;
    Procedure TestTSetComponent2;
    Procedure TestTSetComponent3;
    Procedure TestTSetComponent4;
    Procedure TestTMultipleComponent;
    Procedure TestTPersistentComponent;
    Procedure TestTCollectionComponent;
    Procedure TestTCollectionComponent2;
    Procedure TestTCollectionComponent3;
    Procedure TestTCollectionComponent4;
    Procedure TestTCollectionComponent5;
    Procedure TestTOwnedComponent;
    Procedure TestTStreamedOwnedComponent;
    Procedure TestTStreamedOwnedComponents;
    Procedure TestTMethodComponent;
    Procedure TestTMethodComponent2;
    Procedure TestTOwnedInterface;
  end;
  { TMyItem }

  TMyItem = Class(TCollectionItem)
  private
    FNR: Integer;
    FStr: String;
  Public
    Procedure Assign(Source : TPersistent); override;
  Published
    Property Nr : Integer Read FNR Write FNR;
    Property Str: String Read FStr Write FStr;
  end;

  { TMyColl }

  TMyColl = Class(TCollection)
  private
    function GetIt(index : Integer): TMyItem;
    procedure SetIt(index : Integer; const AValue: TMyItem);
  Public
    Property It[index : Integer] : TMyItem Read GetIt Write SetIt; default;
  end;

  { TCollComp }

  TCollComp = Class(TComponent)
  private
    FMyColl: TMyColl;
    procedure SetMyColl(const AValue: TMyColl);
  Public
    Constructor Create(AOwner : TComponent); override;
    Destructor Destroy; override;
    Function ToStream : TStream;
    Procedure FromStream(AStream : TStream);
  Published
    Property MyColl : TMyColl Read FMyColl Write SetMyColl;
  end;


  { TTestCollectionStream }

  TTestCollectionStream = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);

  private
    procedure CompareColl(CA, CB: TMyColl);
    function CreateColl(Anr: Integer): TCollComp;
    function EmptyComp: TCollComp;
    procedure TestNr(ACount: Integer);
  public
    procedure Test1;
    procedure Test2;
    procedure Test3;
    procedure TestClear;
    procedure TestEmpty;
  end;

procedure RegistertccompstreamingTests(ARegistry: TNXTestRegistry);

Implementation

uses testcomps;


Procedure TTestComponentStream.TestTEmptyComponent;

Var
  C : TComponent;

begin
  C:=TEmptyComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TEmptyComponent');
    ExpectBareString('TestTEmptyComponent');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTIntegerComponent;

Var
  C : TComponent;

begin
  C:=TIntegerComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TIntegerComponent');
    ExpectBareString('TestTIntegerComponent');
    ExpectBareString('IntProp');
    ExpectInteger(3);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTIntegerComponent2;

Var
  C : TComponent;

begin
  C:=TIntegerComponent2.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TIntegerComponent2');
    ExpectBareString('TestTIntegerComponent2');
    ExpectBareString('IntProp');
    ExpectInteger(1024);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTIntegerComponent3;

Var
  C : TComponent;

begin
  C:=TIntegerComponent3.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TIntegerComponent3');
    ExpectBareString('TestTIntegerComponent3');
    ExpectBareString('IntProp');
    ExpectInteger(262144);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTIntegerComponent4;

Var
  C : TComponent;

begin
  C:=TIntegerComponent4.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TIntegerComponent4');
    ExpectBareString('TestTIntegerComponent4');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTIntegerComponent5;

Var
  C : TComponent;

begin
  C:=TIntegerComponent5.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TIntegerComponent5');
    ExpectBareString('TestTIntegerComponent5');
    ExpectBareString('IntProp');
    ExpectInteger(5);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTInt64Component;

Var
  C : TComponent;

begin
  C:=TInt64Component.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TInt64Component');
    ExpectBareString('TestTInt64Component');
    ExpectBareString('Int64Prop');
    ExpectInteger(4);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTInt64Component2;

Var
  C : TComponent;

begin
  C:=TInt64Component2.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TInt64Component2');
    ExpectBareString('TestTInt64Component2');
    ExpectBareString('Int64Prop');
    ExpectInteger(1024);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTInt64Component3;

Var
  C : TComponent;

begin
  C:=TInt64Component3.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TInt64Component3');
    ExpectBareString('TestTInt64Component3');
    ExpectBareString('Int64Prop');
    ExpectInteger(262144);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTInt64Component4;

Var
  C : TComponent;

begin
  C:=TInt64Component4.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TInt64Component4');
    ExpectBareString('TestTInt64Component4');
    ExpectBareString('Int64Prop');
    ExpectInt64(2147745791);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTInt64Component5;

Var
  C : TComponent;

begin
  C:=TInt64Component5.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TInt64Component5');
    ExpectBareString('TestTInt64Component5');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTInt64Component6;

Var
  C : TComponent;

begin
  C:=TInt64Component6.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TInt64Component6');
    ExpectBareString('TestTInt64Component6');
    ExpectBareString('Int64Prop');
    ExpectInteger(8);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTStringComponent;

Var
  C : TComponent;

begin
  C:=TStringComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TStringComponent');
    ExpectBareString('TestTStringComponent');
    ExpectBareString('StringProp');
    ExpectString('A string');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTStringComponent2;

Var
  C : TComponent;

begin
  C:=TStringComponent2.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TStringComponent2');
    ExpectBareString('TestTStringComponent2');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTWideStringComponent;

Var
  C : TComponent;

begin
  C:=TWideStringComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TWideStringComponent');
    ExpectBareString('TestTWideStringComponent');
    ExpectBareString('WideStringProp');
    ExpectString('Some WideString');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTWideStringComponent2;

Var
  C : TComponent;

begin
  C:=TWideStringComponent2.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TWideStringComponent2');
    ExpectBareString('TestTWideStringComponent2');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTSingleComponent;

Var
  C : TComponent;

begin
  C:=TSingleComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TSingleComponent');
    ExpectBareString('TestTSingleComponent');
    ExpectBareString('SingleProp');
    ExpectExtended(1.23);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTDoubleComponent;

Var
  C : TComponent;

begin
  C:=TDoubleComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TDoubleComponent');
    ExpectBareString('TestTDoubleComponent');
    ExpectBareString('DoubleProp');
    ExpectExtended(2.34);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTExtendedComponent;

Var
  C : TComponent;

begin
  C:=TExtendedComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TExtendedComponent');
    ExpectBareString('TestTExtendedComponent');
    ExpectBareString('ExtendedProp');
    ExpectExtended(3.45);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTCompComponent;

Var
  C : TComponent;

begin
  C:=TCompComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TCompComponent');
    ExpectBareString('TestTCompComponent');
    ExpectBareString('ExtendedProp');
    ExpectExtended(5.00);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTCurrencyComponent;

Var
  C : TComponent;

begin
  C:=TCurrencyComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TCurrencyComponent');
    ExpectBareString('TestTCurrencyComponent');
    ExpectBareString('CurrencyProp');
    ExpectExtended(5.67);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTDateTimeComponent;

Var
  C : TComponent;

begin
  C:=TDateTimeComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TDateTimeComponent');
    ExpectBareString('TestTDateTimeComponent');
    ExpectBareString('DateTimeProp');
    ExpectExtended(35278.00);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTDateTimeComponent2;

Var
  C : TComponent;

begin
  C:=TDateTimeComponent2.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TDateTimeComponent2');
    ExpectBareString('TestTDateTimeComponent2');
    ExpectBareString('DateTimeProp');
    ExpectExtended(0.97);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTDateTimeComponent3;

Var
  C : TComponent;

begin
  C:=TDateTimeComponent3.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TDateTimeComponent3');
    ExpectBareString('TestTDateTimeComponent3');
    ExpectBareString('DateTimeProp');
    ExpectExtended(35278.97);
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTEnumComponent;

Var
  C : TComponent;

begin
  C:=TEnumComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TEnumComponent');
    ExpectBareString('TestTEnumComponent');
    ExpectBareString('Dice');
    ExpectIdent('four');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTEnumComponent2;

Var
  C : TComponent;

begin
  C:=TEnumComponent2.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TEnumComponent2');
    ExpectBareString('TestTEnumComponent2');
    ExpectBareString('Dice');
    ExpectIdent('one');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTEnumComponent3;

Var
  C : TComponent;

begin
  C:=TEnumComponent3.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TEnumComponent3');
    ExpectBareString('TestTEnumComponent3');
    ExpectBareString('Dice');
    ExpectIdent('three');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTEnumComponent4;

Var
  C : TComponent;

begin
  C:=TEnumComponent4.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TEnumComponent4');
    ExpectBareString('TestTEnumComponent4');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;

Procedure TTestComponentStream.TestTEnumComponent5;

Var
  C : TComponent;

begin
  C:=TEnumComponent5.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TEnumComponent5');
    ExpectBareString('TestTEnumComponent5');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTSetComponent;

Var
  C : TComponent;

begin
  C:=TSetComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TSetComponent');
    ExpectBareString('TestTSetComponent');
    ExpectBareString('Throw');
    ExpectValue(vaSet);
    ExpectBareString('two');
    ExpectBareString('five');
    ExpectBareString('');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTSetComponent2;

Var
  C : TComponent;

begin
  C:=TSetComponent2.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TSetComponent2');
    ExpectBareString('TestTSetComponent2');
    ExpectBareString('Throw');
    ExpectValue(vaSet);
    ExpectBareString('');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTSetComponent3;

Var
  C : TComponent;

begin
  C:=TSetComponent3.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TSetComponent3');
    ExpectBareString('TestTSetComponent3');
    ExpectBareString('Throw');
    ExpectValue(vaSet);
    ExpectBareString('one');
    ExpectBareString('four');
    ExpectBareString('');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTSetComponent4;

Var
  C : TComponent;

begin
  C:=TSetComponent4.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TSetComponent4');
    ExpectBareString('TestTSetComponent4');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTMultipleComponent;

Var
  C : TComponent;

begin
  C:=TMultipleComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TMultipleComponent');
    ExpectBareString('TestTMultipleComponent');
    ExpectBareString('IntProp');
    ExpectInteger(1);
    ExpectBareString('StringProp');
    ExpectString('A String');
    ExpectBareString('CurrencyProp');
    ExpectExtended(2.30);
    ExpectBareString('Dice');
    ExpectIdent('two');
    ExpectBareString('Throw');
    ExpectValue(vaSet);
    ExpectBareString('three');
    ExpectBareString('four');
    ExpectBareString('');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTPersistentComponent;

Var
  C : TComponent;

begin
  C:=TPersistentComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TPersistentComponent');
    ExpectBareString('TestTPersistentComponent');
    ExpectBareString('Persist.AInteger');
    ExpectInteger(3);
    ExpectBareString('Persist.AString');
    ExpectString('A persistent string');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTCollectionComponent;

Var
  C : TComponent;

begin
  C:=TCollectionComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TCollectionComponent');
    ExpectBareString('TestTCollectionComponent');
    ExpectBareString('Coll');
    ExpectValue(vaCollection);
    ExpectEndOfList;
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTCollectionComponent2;

Var
  C : TComponent;

begin
  C:=TCollectionComponent2.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TCollectionComponent2');
    ExpectBareString('TestTCollectionComponent2');
    ExpectBareString('Coll');
    ExpectValue(vaCollection);
    ExpectValue(vaList);
    ExpectBareString('StrProp');
    ExpectString('First');
    ExpectEndOfList;
    ExpectValue(vaList);
    ExpectBareString('StrProp');
    ExpectString('Second');
    ExpectEndOfList;
    ExpectValue(vaList);
    ExpectBareString('StrProp');
    ExpectString('Third');
    ExpectEndOfList;
    ExpectEndOfList;
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTCollectionComponent3;

Var
  C : TComponent;

begin
  C:=TCollectionComponent3.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TCollectionComponent3');
    ExpectBareString('TestTCollectionComponent3');
    ExpectBareString('Coll');
    ExpectValue(vaCollection);
    ExpectValue(vaList);
    ExpectBareString('StrProp');
    ExpectString('First');
    ExpectEndOfList;
    ExpectValue(vaList);
    ExpectEndOfList;
    ExpectValue(vaList);
    ExpectBareString('StrProp');
    ExpectString('Third');
    ExpectEndOfList;
    ExpectEndOfList;
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTCollectionComponent4;

Var
  C : TComponent;

begin
  C:=TCollectionComponent4.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TCollectionComponent4');
    ExpectBareString('TestTCollectionComponent4');
    ExpectBareString('Coll');
    ExpectValue(vaCollection);
    ExpectValue(vaList);
    ExpectBareString('StrProp');
    ExpectString('Something');
    ExpectEndOfList;
    ExpectEndOfList;
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;

Procedure TTestComponentStream.TestTCollectionComponent5;

Var
  C : TComponent;

begin
  C:=TCollectionComponent5.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TCollectionComponent5');
    ExpectBareString('TestTCollectionComponent5');
    ExpectBareString('Coll');
    ExpectValue(vaCollection);
    ExpectValue(vaList);
    ExpectBareString('StrProp1');
    ExpectString('Something');
    ExpectBareString('StrProp2');
    ExpectString('Otherthing');
    ExpectEndOfList;
    ExpectValue(vaList);
    ExpectBareString('StrProp1');
    ExpectString('Something 2');
    ExpectBareString('StrProp2');
    ExpectString('Otherthing 2');
    ExpectEndOfList;
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTOwnedComponent;

Var
  C : TComponent;

begin
  C:=TOwnedComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TOwnedComponent');
    ExpectBareString('TestTOwnedComponent');
    ExpectBareString('CompProp');
    ExpectIdent('SubComponent');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTStreamedOwnedComponent;

Var
  C : TComponent;

begin
  C:=TStreamedOwnedComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TStreamedOwnedComponent');
    ExpectBareString('TestTStreamedOwnedComponent');
    ExpectEndOfList;
    ExpectFlags([],0);
    ExpectBareString('TIntegerComponent');
    ExpectBareString('Sub');
    ExpectBareString('IntProp');
    ExpectInteger(3);
    ExpectEndOfList;
    ExpectEndOfList;
    ExpectEndOfList;
    ExpectEndOfStream;
  Finally
    C.Free;
    end;
end;

Procedure TTestComponentStream.TestTStreamedOwnedComponents;

Var
  C : TComponent;

begin
  C:=TStreamedOwnedComponents.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TStreamedOwnedComponents');
    ExpectBareString('TestTStreamedOwnedComponents');
    ExpectEndOfList;
    ExpectFlags([],0);
    ExpectBareString('TIntegerComponent');
    ExpectBareString('SubA');
    ExpectBareString('IntProp');
    ExpectInteger(3);
    ExpectEndOfList;
    ExpectEndOfList;
    ExpectFlags([],0);
    ExpectBareString('TStringComponent');
    ExpectBareString('SubB');
    ExpectBareString('StringProp');
    ExpectString('A string');
    ExpectEndOfList;
    ExpectEndOfList;
    ExpectEndOfList;
    ExpectEndOfStream;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTMethodComponent;

Var
  C : TComponent;

begin
  C:=TMethodComponent.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TMethodComponent');
    ExpectBareString('TestTMethodComponent');
    ExpectBareString('MethodProp');
    ExpectIdent('MyMethod');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;


Procedure TTestComponentStream.TestTMethodComponent2;

Var
  C : TComponent;

begin
  C:=TMethodComponent2.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TMethodComponent2');
    ExpectBareString('TestTMethodComponent2');
    ExpectEndOfList;
    ExpectFlags([],0);
    ExpectBareString('TMethodComponent');
    ExpectBareString('AComponent');
    ExpectBareString('MethodProp');
    ExpectIdent('MyMethod2');
    ExpectEndOfList;
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;

Procedure TTestComponentStream.TestTOwnedInterface;

Var
  C : TComponent;

begin
  C:=TOwnedInterface.Create(Nil);
  Try
    SaveToStream(C);
    ExpectSignature;
    ExpectFlags([],0);
    ExpectBareString('TOwnedInterface');
    ExpectBareString('TestTOwnedInterface');
    ExpectBareString('IntfProp');
    ExpectIdent('InterfacedComponent');
    ExpectEndOfList;
    ExpectEndOfList;
  Finally
    C.Free;
    end;
end;

{ TMyColl }

function TMyColl.GetIt(index : Integer): TMyItem;
begin
  Result:=Items[Index] as TMyItem;
end;

procedure TMyColl.SetIt(index : Integer; const AValue: TMyItem);
begin
  Items[Index]:=AValue;
end;

{ TCollComp }

procedure TCollComp.SetMyColl(const AValue: TMyColl);
begin
  if (FMyColl=AValue) then
    exit;
  FMyColl.Assign(AValue);
end;

constructor TCollComp.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMyColl:=TMyCOll.Create(TMyItem);
end;

destructor TCollComp.Destroy;
begin
  FreeAndNil(FMyColl);
  inherited Destroy;
end;

function TCollComp.ToStream: TStream;
begin
  Result:=TMemoryStream.Create;
  Result.WriteComponent(Self);
  Result.Position:=0;
end;

procedure TCollComp.FromStream(AStream: TStream);
begin
  AStream.ReadComponent(Self);
  Astream.Free;
end;

procedure TMyItem.Assign(Source: TPersistent);

Var
  I : TMyItem;

begin
  If (Source is TMyItem) then
    begin
    I:=Source as TMyItem;
    FNR:=I.NR;
    FStr:=I.Str;
    end
  else
    inherited Assign(Source);
end;

Procedure TTestCollectionStream.CompareColl(CA,CB : TMyColl);

Var
  I : Integer;

begin
  TestContext.AssertTrue((CA.Count)=(CB.Count), 'Counts differ: %d %d');
  For I:=0 to CA.Count-1 do
    begin
    TestContext.AssertTrue((CA[i].Nr)=(CB[i].Nr), Format('Nr property of element %d equals',[I]));
    TestContext.AssertTrue((CA[i].Str)=(CB[i].Str), Format('Str property of element %d equals',[I]));
    end;
end;

Function TTestCollectionStream.EmptyComp : TCollComp;

begin
  Result:=TCollComp.Create(Nil);
end;

Function TTestCollectionStream.CreateColl(Anr : Integer) : TCollComp;

Var
  I : Integer;
  T : TMyItem;

begin
  Result:=EmptyComp;
  Result.Name:='C'+IntToStr(Anr);
  For I:=0 to ANr-1 do
    begin
    T:=Result.MyColl.Add as TMyItem;
    T.Nr:=I; // not I+1, so the default value gets tested too
    T.Str:=IntToStr(I+1);
    end;
end;

Procedure TTestCollectionStream.TestEmpty;

Var
 CA,CB : TCollComp;

begin
  CA:=CreateColl(0);
  try
    CB:=EmptyComp;
    Try
      CB.FromStream(CA.ToStream);
      CompareColl(CA.MyColl,CB.MyColl);
    Finally
      CB.Free;
    end;
  Finally
    CA.Free;
  end;
end;

Procedure TTestCollectionStream.TestNr(ACount : Integer);

Var
 CA,CB : TCollComp;

begin
  CA:=CreateColl(ACount);
  try
    CB:=EmptyComp;
    Try
      CB.FromStream(CA.ToStream);
      CompareColl(CA.MyColl,CB.MyColl);
    Finally
      CB.Free;
    end;
  Finally
    CA.Free;
  end;
end;

Procedure TTestCollectionStream.TestClear;

Var
 CA,CB : TCollComp;

begin
  CA:=CreateColl(3);
  try
    CB:=CreateColl(1);
    CB.Name:='';
    Try
      // CB collection should be cleared before loading.
      CB.FromStream(CA.ToStream);
      CompareColl(CA.MyColl,CB.MyColl);
    Finally
      CB.Free;
    end;
  Finally
    CA.Free;
  end;
end;

Procedure TTestCollectionStream.Test1;

begin
  TestNr(1);
end;

Procedure TTestCollectionStream.Test2;

begin
  TestNr(2);
end;

Procedure TTestCollectionStream.Test3;

begin
  TestNr(3);
end;


constructor TTestCollectionStream.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestComponentStreamTestTEmptyComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTEmptyComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTEmptyComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTIntegerComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTIntegerComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTIntegerComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTIntegerComponent2(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTIntegerComponent2');
  try
    lFixture.SetUp;
    try lFixture.TestTIntegerComponent2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTIntegerComponent3(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTIntegerComponent3');
  try
    lFixture.SetUp;
    try lFixture.TestTIntegerComponent3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTIntegerComponent4(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTIntegerComponent4');
  try
    lFixture.SetUp;
    try lFixture.TestTIntegerComponent4; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTIntegerComponent5(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTIntegerComponent5');
  try
    lFixture.SetUp;
    try lFixture.TestTIntegerComponent5; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTInt64Component(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTInt64Component');
  try
    lFixture.SetUp;
    try lFixture.TestTInt64Component; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTInt64Component2(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTInt64Component2');
  try
    lFixture.SetUp;
    try lFixture.TestTInt64Component2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTInt64Component3(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTInt64Component3');
  try
    lFixture.SetUp;
    try lFixture.TestTInt64Component3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTInt64Component4(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTInt64Component4');
  try
    lFixture.SetUp;
    try lFixture.TestTInt64Component4; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTInt64Component5(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTInt64Component5');
  try
    lFixture.SetUp;
    try lFixture.TestTInt64Component5; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTInt64Component6(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTInt64Component6');
  try
    lFixture.SetUp;
    try lFixture.TestTInt64Component6; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTStringComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTStringComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTStringComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTStringComponent2(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTStringComponent2');
  try
    lFixture.SetUp;
    try lFixture.TestTStringComponent2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTWideStringComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTWideStringComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTWideStringComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTWideStringComponent2(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTWideStringComponent2');
  try
    lFixture.SetUp;
    try lFixture.TestTWideStringComponent2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTSingleComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTSingleComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTSingleComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTDoubleComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTDoubleComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTDoubleComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTExtendedComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTExtendedComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTExtendedComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTCompComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTCompComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTCompComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTCurrencyComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTCurrencyComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTCurrencyComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTDateTimeComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTDateTimeComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTDateTimeComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTDateTimeComponent2(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTDateTimeComponent2');
  try
    lFixture.SetUp;
    try lFixture.TestTDateTimeComponent2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTDateTimeComponent3(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTDateTimeComponent3');
  try
    lFixture.SetUp;
    try lFixture.TestTDateTimeComponent3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTEnumComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTEnumComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTEnumComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTEnumComponent2(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTEnumComponent2');
  try
    lFixture.SetUp;
    try lFixture.TestTEnumComponent2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTEnumComponent3(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTEnumComponent3');
  try
    lFixture.SetUp;
    try lFixture.TestTEnumComponent3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTEnumComponent4(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTEnumComponent4');
  try
    lFixture.SetUp;
    try lFixture.TestTEnumComponent4; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTEnumComponent5(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTEnumComponent5');
  try
    lFixture.SetUp;
    try lFixture.TestTEnumComponent5; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTSetComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTSetComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTSetComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTSetComponent2(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTSetComponent2');
  try
    lFixture.SetUp;
    try lFixture.TestTSetComponent2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTSetComponent3(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTSetComponent3');
  try
    lFixture.SetUp;
    try lFixture.TestTSetComponent3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTSetComponent4(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTSetComponent4');
  try
    lFixture.SetUp;
    try lFixture.TestTSetComponent4; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTMultipleComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTMultipleComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTMultipleComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTPersistentComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTPersistentComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTPersistentComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTCollectionComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTCollectionComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTCollectionComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTCollectionComponent2(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTCollectionComponent2');
  try
    lFixture.SetUp;
    try lFixture.TestTCollectionComponent2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTCollectionComponent3(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTCollectionComponent3');
  try
    lFixture.SetUp;
    try lFixture.TestTCollectionComponent3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTCollectionComponent4(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTCollectionComponent4');
  try
    lFixture.SetUp;
    try lFixture.TestTCollectionComponent4; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTCollectionComponent5(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTCollectionComponent5');
  try
    lFixture.SetUp;
    try lFixture.TestTCollectionComponent5; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTOwnedComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTOwnedComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTOwnedComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTStreamedOwnedComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTStreamedOwnedComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTStreamedOwnedComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTStreamedOwnedComponents(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTStreamedOwnedComponents');
  try
    lFixture.SetUp;
    try lFixture.TestTStreamedOwnedComponents; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTMethodComponent(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTMethodComponent');
  try
    lFixture.SetUp;
    try lFixture.TestTMethodComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTMethodComponent2(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTMethodComponent2');
  try
    lFixture.SetUp;
    try lFixture.TestTMethodComponent2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestComponentStreamTestTOwnedInterface(AContext: TNXTestContext);
var lFixture: TTestComponentStream;
begin
  lFixture:=TTestComponentStream.Create(AContext, 'TestTOwnedInterface');
  try
    lFixture.SetUp;
    try lFixture.TestTOwnedInterface; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestCollectionStreamTest1(AContext: TNXTestContext);
var lFixture: TTestCollectionStream;
begin
  lFixture:=TTestCollectionStream.Create(AContext, 'Test1');
  try
    lFixture.Test1;
  finally lFixture.Free; end;
end;

procedure RunTTestCollectionStreamTest2(AContext: TNXTestContext);
var lFixture: TTestCollectionStream;
begin
  lFixture:=TTestCollectionStream.Create(AContext, 'Test2');
  try
    lFixture.Test2;
  finally lFixture.Free; end;
end;

procedure RunTTestCollectionStreamTest3(AContext: TNXTestContext);
var lFixture: TTestCollectionStream;
begin
  lFixture:=TTestCollectionStream.Create(AContext, 'Test3');
  try
    lFixture.Test3;
  finally lFixture.Free; end;
end;

procedure RunTTestCollectionStreamTestClear(AContext: TNXTestContext);
var lFixture: TTestCollectionStream;
begin
  lFixture:=TTestCollectionStream.Create(AContext, 'TestClear');
  try
    lFixture.TestClear;
  finally lFixture.Free; end;
end;

procedure RunTTestCollectionStreamTestEmpty(AContext: TNXTestContext);
var lFixture: TTestCollectionStream;
begin
  lFixture:=TTestCollectionStream.Create(AContext, 'TestEmpty');
  try
    lFixture.TestEmpty;
  finally lFixture.Free; end;
end;

procedure RegistertccompstreamingTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tccompstreaming.TTestComponentStream');
  lSuite.AddTest('TestTEmptyComponent', @RunTTestComponentStreamTestTEmptyComponent);
  lSuite.AddTest('TestTIntegerComponent', @RunTTestComponentStreamTestTIntegerComponent);
  lSuite.AddTest('TestTIntegerComponent2', @RunTTestComponentStreamTestTIntegerComponent2);
  lSuite.AddTest('TestTIntegerComponent3', @RunTTestComponentStreamTestTIntegerComponent3);
  lSuite.AddTest('TestTIntegerComponent4', @RunTTestComponentStreamTestTIntegerComponent4);
  lSuite.AddTest('TestTIntegerComponent5', @RunTTestComponentStreamTestTIntegerComponent5);
  lSuite.AddTest('TestTInt64Component', @RunTTestComponentStreamTestTInt64Component);
  lSuite.AddTest('TestTInt64Component2', @RunTTestComponentStreamTestTInt64Component2);
  lSuite.AddTest('TestTInt64Component3', @RunTTestComponentStreamTestTInt64Component3);
  lSuite.AddTest('TestTInt64Component4', @RunTTestComponentStreamTestTInt64Component4);
  lSuite.AddTest('TestTInt64Component5', @RunTTestComponentStreamTestTInt64Component5);
  lSuite.AddTest('TestTInt64Component6', @RunTTestComponentStreamTestTInt64Component6);
  lSuite.AddTest('TestTStringComponent', @RunTTestComponentStreamTestTStringComponent);
  lSuite.AddTest('TestTStringComponent2', @RunTTestComponentStreamTestTStringComponent2);
  lSuite.AddTest('TestTWideStringComponent', @RunTTestComponentStreamTestTWideStringComponent);
  lSuite.AddTest('TestTWideStringComponent2', @RunTTestComponentStreamTestTWideStringComponent2);
  lSuite.AddTest('TestTSingleComponent', @RunTTestComponentStreamTestTSingleComponent);
  lSuite.AddTest('TestTDoubleComponent', @RunTTestComponentStreamTestTDoubleComponent);
  lSuite.AddTest('TestTExtendedComponent', @RunTTestComponentStreamTestTExtendedComponent);
  lSuite.AddTest('TestTCompComponent', @RunTTestComponentStreamTestTCompComponent);
  lSuite.AddTest('TestTCurrencyComponent', @RunTTestComponentStreamTestTCurrencyComponent);
  lSuite.AddTest('TestTDateTimeComponent', @RunTTestComponentStreamTestTDateTimeComponent);
  lSuite.AddTest('TestTDateTimeComponent2', @RunTTestComponentStreamTestTDateTimeComponent2);
  lSuite.AddTest('TestTDateTimeComponent3', @RunTTestComponentStreamTestTDateTimeComponent3);
  lSuite.AddTest('TestTEnumComponent', @RunTTestComponentStreamTestTEnumComponent);
  lSuite.AddTest('TestTEnumComponent2', @RunTTestComponentStreamTestTEnumComponent2);
  lSuite.AddTest('TestTEnumComponent3', @RunTTestComponentStreamTestTEnumComponent3);
  lSuite.AddTest('TestTEnumComponent4', @RunTTestComponentStreamTestTEnumComponent4);
  lSuite.AddTest('TestTEnumComponent5', @RunTTestComponentStreamTestTEnumComponent5);
  lSuite.AddTest('TestTSetComponent', @RunTTestComponentStreamTestTSetComponent);
  lSuite.AddTest('TestTSetComponent2', @RunTTestComponentStreamTestTSetComponent2);
  lSuite.AddTest('TestTSetComponent3', @RunTTestComponentStreamTestTSetComponent3);
  lSuite.AddTest('TestTSetComponent4', @RunTTestComponentStreamTestTSetComponent4);
  lSuite.AddTest('TestTMultipleComponent', @RunTTestComponentStreamTestTMultipleComponent);
  lSuite.AddTest('TestTPersistentComponent', @RunTTestComponentStreamTestTPersistentComponent);
  lSuite.AddTest('TestTCollectionComponent', @RunTTestComponentStreamTestTCollectionComponent);
  lSuite.AddTest('TestTCollectionComponent2', @RunTTestComponentStreamTestTCollectionComponent2);
  lSuite.AddTest('TestTCollectionComponent3', @RunTTestComponentStreamTestTCollectionComponent3);
  lSuite.AddTest('TestTCollectionComponent4', @RunTTestComponentStreamTestTCollectionComponent4);
  lSuite.AddTest('TestTCollectionComponent5', @RunTTestComponentStreamTestTCollectionComponent5);
  lSuite.AddTest('TestTOwnedComponent', @RunTTestComponentStreamTestTOwnedComponent);
  lSuite.AddTest('TestTStreamedOwnedComponent', @RunTTestComponentStreamTestTStreamedOwnedComponent);
  lSuite.AddTest('TestTStreamedOwnedComponents', @RunTTestComponentStreamTestTStreamedOwnedComponents);
  lSuite.AddTest('TestTMethodComponent', @RunTTestComponentStreamTestTMethodComponent);
  lSuite.AddTest('TestTMethodComponent2', @RunTTestComponentStreamTestTMethodComponent2);
  lSuite.AddTest('TestTOwnedInterface', @RunTTestComponentStreamTestTOwnedInterface);
  lSuite:=ARegistry.AddSuite('tccompstreaming.TTestCollectionStream');
  lSuite.AddTest('Test1', @RunTTestCollectionStreamTest1);
  lSuite.AddTest('Test2', @RunTTestCollectionStreamTest2);
  lSuite.AddTest('Test3', @RunTTestCollectionStreamTest3);
  lSuite.AddTest('TestClear', @RunTTestCollectionStreamTestClear);
  lSuite.AddTest('TestEmpty', @RunTTestCollectionStreamTestEmpty);
end;

end.
