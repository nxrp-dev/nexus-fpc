{$IFNDEF FPC_DOTTEDUNITS}
unit cpall;
{$ENDIF FPC_DOTTEDUNITS}

interface

{$IFDEF FPC_DOTTEDUNITS}
uses
  { cyrillic code pages }
  System.CodePages.CP1251,System.CodePages.CP855,System.CodePages.CP866,System.CodePages.CP8859_5,System.CodePages.CP3021,System.CodePages.CPkoi8_r,System.CodePages.CPkoi8_u,
  { greek code pages }
  System.CodePages.CP1253,System.CodePages.CP737,System.CodePages.CP869,System.CodePages.CP8859_7,
  { other code pages }
  System.CodePages.CP8859_1,System.CodePages.CP850,System.CodePages.CP437,System.CodePages.CP1252,System.CodePages.CP646,System.CodePages.CP775,
  System.CodePages.CP874,System.CodePages.CP856,System.CodePages.CP857,System.CodePages.CP860,System.CodePages.CP861,System.CodePages.CP862,System.CodePages.CP863,System.CodePages.CP864,System.CodePages.CP865,

  { these are too big for a 16-bit System.CPU }
  {  cp932,cp936,cp949,cp950, -> to rtl-unicode}

  System.CodePages.CP1250,System.CodePages.CP1254,System.CodePages.CP1255,System.CodePages.CP1256,System.CodePages.CP1257,System.CodePages.CP1258,System.CodePages.CP852,System.CodePages.CP8859_2,System.CodePages.CP8859_3,System.CodePages.CP8859_4,
  System.CodePages.CP8859_6,System.CodePages.CP8859_8,System.CodePages.CP8859_9,System.CodePages.CP8859_10,System.CodePages.CP8859_11,System.CodePages.CP8859_13,System.CodePages.CP8859_14,System.CodePages.CP8859_15,
  System.CodePages.CP8859_16;
{$ELSE FPC_DOTTEDUNITS}
uses
  { cyrillic code pages }
  CP1251,CP855,CP866,CP8859_5,CP3021,CPKOI8_R,CPKOI8_U,
  { greek code pages }
  CP1253,CP737,CP869,CP8859_7,
  { other code pages }
  CP8859_1,CP850,CP437,CP1252,CP646,CP775,
  CP874,CP856,CP857,CP860,CP861,CP862,CP863,CP864,CP865,

  { these are too big for a 16-bit CPU }
  {  cp932,cp936,cp949,cp950, -> to rtl-unicode}

  CP1250,CP1254,CP1255,CP1256,CP1257,CP1258,CP852,CP8859_2,CP8859_3,CP8859_4,
  CP8859_6,CP8859_8,CP8859_9,CP8859_10,CP8859_11,CP8859_13,CP8859_14,CP8859_15,
  CP8859_16;
{$ENDIF FPC_DOTTEDUNITS}


implementation

end.
