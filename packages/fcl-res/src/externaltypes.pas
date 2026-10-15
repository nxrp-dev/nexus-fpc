{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2008 by Giulio Bernardi

    Types and constants used by external resource reader and writer

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

{$IFNDEF FPC_DOTTEDUNITS}
unit externaltypes;
{$ENDIF FPC_DOTTEDUNITS}

{$MODE OBJFPC} {$H+}

interface

type
  TExternalResMagic = array[1..6] of AnsiChar;

type
  TExtHeader = packed record
    Magic : TExternalResMagic;  //'FPCRES'
    Version : Byte;             //EXT_CURRENT_VERSION
    Endianess : Byte;           //EXT_ENDIAN_BIG or EXT_ENDIAN_LITTLE
    Count : LongWord;           //resource count
    NodeSize : LongWord;        //size of header (up to string table, excluded)
    HdrSize  : LongWord;        //size of header (up to string table, included)
    Reserved1 : LongWord;
    Reserved2 : LongWord;
    Reserved3 : LongWord;
  end;

  TResInfoNode = packed record
    NameID : LongWord;          //name offset / integer ID / languageID
    NCount : LongWord;          //named sub-entries count
    IDCountSize : LongWord;     //id sub-entries count / resource size
    SubPtr : LongWord;          //first sub-entry offset
  end;

const
  External_ResMagic : TExternalResMagic = 'FPCRES';

  ExtCurrentVersion = 1;

  ExtEndianBig = 1;
  ExtEndianLittle = 2;


implementation

end.
