{
    Copyright (c) 2024 by J. Gareth "Kit" Moreton

    This unit implements the AArch64 assembly node

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************
}
unit narmbas;

{$i fpcdefs.inc}

interface

  uses
    nbas, ncgbas, aasmtai;

  type
    TArmGenAsmNode = class(TCGAsmNode)
{$ifdef DEBUG_NODE_XML}
      procedure XMLPrintNodeData(var T: Text); override;
    protected
      function XMLFormatOp(const Oper: POper): string; override;
      procedure XMLProcessInstruction(var T: Text; p: TAI); override;
{$endif DEBUG_NODE_XML}
    end;

implementation

{$ifdef DEBUG_NODE_XML}
  uses
    CUtils,
    cgutils,
    cgbase,
    cpubase,
    itcpugas,
    aasmcpu,
    agcpugas, { Needed for gas_shiftmode2str }
    Verbose;
{$endif DEBUG_NODE_XML}

{$ifdef DEBUG_NODE_XML}
  function TArmGenAsmNode.XMLFormatOp(const Oper: POper): string;
    begin
      case Oper^.typ of
        top_const:
          begin
            case Oper^.Val of
              -15..15:
                Result := '#' + ToStr(Oper^.Val);
              $10..$FF:
                Result := '#0x' + HexStr(Oper^.Val, 2);
              $100..$FFFF:
                Result := '#0x' + HexStr(Oper^.Val, 4);
  {$ifdef CPU32}
              else
                Result := '#0x' + HexStr(Oper^.Val, 8);
  {$else CPU32}
              $10000..$FFFFFFFF:
                Result := '#0x' + HexStr(Oper^.Val, 8);
              else
                Result := '#0x' + HexStr(Oper^.Val, 16);
  {$endif CPU32}
            end;
          end;

        top_ref:
          with Oper^.Ref^ do
            begin
              if Assigned(symbol) then
                begin
                  Result := symbol.Name;
                  if (offset <> 0) then
                    begin
                      if (offset < 0) then
                        Result := Result + ' - ' + ToStr(-offset)
                      else
                        Result := Result + ' + ' + ToStr(offset);
                    end;
                end
              else
                begin
                  if (base <> NR_NO) then
                    begin
                      Result := '[' + gas_regname(base);
                      if AddressMode = AM_POSTINDEXED then
                        Result := Result + '], '
                      else if (offset <> 0) or (ShiftMode <> SM_None) then
                        Result := Result + ', ';
                    end
                  else { Usually a special kind of reference used by ldm/stm instructions }
                    Result := '';

                  if index <> NR_NO then
                    Result := Result + gas_regname(index)
                  else if (offset <> 0) or (ShiftMode <> SM_None) or (AddressMode = AM_POSTINDEXED) then
                    Result := Result + '#' + ToStr(offset);
                  if ShiftMode <> SM_None then
                    Result := Result + ', ' + gas_shiftmode2str[ShiftMode] + ' #' + ToStr(ShiftImm);

                  if AddressMode <> AM_POSTINDEXED then
                    begin
                      if (base <> NR_NO) then
                        Result := Result + ']';

                      if AddressMode = AM_PREINDEXED then
                        Result := Result + '!';
                    end;
                end;
            end;
        top_indexedreg:
          with Oper^ do
            Result := gas_regname(indexedreg)+'['+ToStr(RegIndex)+']';
        top_conditioncode:
          Result := cond2str[Oper^.cc];

        top_realconst:
          Result := '#' + RealToStr(Oper^.val_real);

        top_shifterop:
          with Oper^.shifterop^ do
            begin
              Result := gas_shiftmode2str[ShiftMode] + ' #' + ToStr(ShiftImm);
            end;
        else
          Result := inherited XMLFormatOp(Oper);
      end;
    end;


  procedure TArmGenAsmNode.XMLProcessInstruction(var T: Text; p: TAI);
    var
      ThisOp, ThisOper: string;
      X: Integer;
    begin
      if p.typ = ait_instruction then
        begin
          ThisOp := gas_op2str[TAICPU(p).opcode] + cond2str[TAICPU(p).condition] + oppostfix2str[TAICPU(p).oppostfix];

          { Pad the opcode with spaces so the succeeding operands are aligned }
          XMLPadString(ThisOp, 7);

          Write(T, PrintNodeIndention, '  ', ThisOp); { Extra indentation to account for label formatting }
          for X := 0 to TAICPU(p).ops - 1 do
            begin
              Write(T, ' ');

              ThisOper := XMLFormatOp(TAICPU(p).oper[X]);
              if X < TAICPU(p).ops - 1 then
                begin
                  ThisOper := ThisOper + ',';

                  XMLPadString(ThisOper, 4);
                end;

              Write(T, ThisOper);
            end;
          WriteLn(T);
        end
      else
        inherited XMLProcessInstruction(T, p);
    end;


  procedure TArmGenAsmNode.XMLPrintNodeData(var T: Text);
    var
      hp: TAI;
    begin
      if not Assigned(p_asm) then
        Exit;

      hp := TAI(p_asm.First);
      while Assigned(hp) do
        begin
          XMLProcessInstruction(T, hp);
          hp := TAI(hp.Next);
        end;
    end;
{$endif DEBUG_NODE_XML}

initialization
  CAsmNode := TArmGenAsmNode;

end.

