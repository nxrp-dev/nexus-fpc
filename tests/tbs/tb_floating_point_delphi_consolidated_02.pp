{ Consolidated floating point regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}
uses sysutils;

{ Case tw13622.pp }
{$push}





type
    tw13622_TReal1DArray        = array of Double;
    tw13622_TReal2DArray        = array of array of Double;

function tw13622_TestSST(Silent : Boolean):Boolean;
var
    MaxMN : Integer;
    PassCount : Integer;
    Threshold : Double;
    AEffective : tw13622_TReal2DArray;
    AParam : tw13622_TReal2DArray;
    XE : tw13622_TReal1DArray;
    B : tw13622_TReal1DArray;
    N : Integer;
    Pass : Integer;
    I : Integer;
    J : Integer;
    CntS : Integer;
    CntU : Integer;
    CntT : Integer;
    CntM : Integer;
    WasErrors : Boolean;
    IsUpper : Boolean;
    IsTrans : Boolean;
    IsUnit : Boolean;
    V : Double;
    S : Double;
begin
    WriteLn('Trying to call SetLength()'); // this line is executed
    SetLength(AEffective, 2, 2);           // crash occurs at this line
    WriteLn('OK');                         // this line is never executed
    Result:=False;
    EXit;

    //
    // This code NEVER executed but it is necessary to cause a crash
    //
    WasErrors := False;
    MaxMN := 15;
    PassCount := 15;
    N:=1;
    while N<=MaxMN do
    begin
        SetLength(AEffective, N-1+1, N-1+1);
        SetLength(AParam, N-1+1, N-1+1);
        SetLength(XE, N-1+1);
        SetLength(B, N-1+1);
        Pass:=1;
        while Pass<=PassCount do
        begin
            CntS:=0;
            while CntS<=1 do
            begin
                CntU:=0;
                while CntU<=1 do
                begin
                    CntT:=0;
                    while CntT<=1 do
                    begin
                        CntM:=0;
                        while CntM<=2 do
                        begin
                            //
                            // Clear matrices
                            //
                            I:=0;
                            while I<=N-1 do
                            begin
                                J:=0;
                                while J<=N-1 do
                                begin
                                    AEffective[I,J] := 0;
                                    AParam[I,J] := 0;
                                    Inc(J);
                                end;
                                Inc(I);
                            end;

                            //
                            // Prepare matrices
                            //
                            if IsUpper then
                            begin
                                I:=0;
                                while I<=N-1 do
                                begin
                                    J:=I;
                                    while J<=N-1 do
                                    begin
                                        AParam[I,J] := AEffective[I,J];
                                        Inc(J);
                                    end;
                                    AParam[I,I] := AEffective[I,I];
                                    Inc(I);
                                end;
                            end
                            else
                            begin
                                I:=0;
                                while I<=N-1 do
                                begin
                                    J:=0;
                                    while J<=I do
                                    begin
                                        AEffective[I,J] := 0.9*(2*Random()-1);
                                        AParam[I,J] := AEffective[I,J];
                                        Inc(J);
                                    end;
                                    AParam[I,I] := AEffective[I,I];
                                    Inc(I);
                                end;
                            end;
                            if IsUnit then
                            begin
                                I:=0;
                                while I<=N-1 do
                                begin
                                    AEffective[I,I] := 1;
                                    AParam[I,I] := 0;
                                    Inc(I);
                                end;
                            end;
                            if IsTrans then
                            begin
                                if IsUpper then
                                begin
                                    I:=0;
                                    while I<=N-1 do
                                    begin
                                        J:=I+1;
                                        while J<=N-1 do
                                        begin
                                            AEffective[J,I] := AEffective[I,J];
                                            AEffective[I,J] := 0;
                                            Inc(J);
                                        end;
                                        Inc(I);
                                    end;
                                end
                                else
                                begin
                                    I:=0;
                                    while I<=N-1 do
                                    begin
                                        J:=I+1;
                                        while J<=N-1 do
                                        begin
                                            AEffective[I,J] := AEffective[J,I];
                                            AEffective[J,I] := 0;
                                            Inc(J);
                                        end;
                                        Inc(I);
                                    end;
                                end;
                            end;
                        end;
                        Inc(CntT);
                    end;
                    Inc(CntU);
                end;
                Inc(CntS);
            end;
            Inc(Pass);
        end;
        Inc(N);
    end;

    Result :=  False;
end;


{$pop}

{ Case tw22809.pp }
{$push}






var
   tw22809_v : Double;

{$pop}

{ Case tw35886.pp }
{$push}






var
  tw35886_f: Double;
  tw35886_n: Int64;


{$pop}

begin

{ Case tw13622.pp }
{$push}

begin
  tw13622_TestSST(False);
end;
{$pop}

{ Case tw22809.pp }
{$push}

begin
  try
    TryStrToFloat('9e9999', tw22809_v);
  except
    on e: Exception do begin
      writeln('Unexpected exception thrown: ',e.ClassName);
      halt(1);
    end;
  end;
  writeln('ok')
end;
{$pop}

{ Case tw35886.pp }
{$push}

begin
  tw35886_n := 9876543210;
  tw35886_f := Double(tw35886_n);
  if tw35886_f<>9876543210.0 then
    halt(1);
end;
{$pop}

end.
