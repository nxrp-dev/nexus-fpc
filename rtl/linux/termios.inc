{
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2004 by Marco van de Voort
    member of the Free Pascal development team

    ioctls constants for linux

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{********************
   IOCtl(TermIOS)
********************}

Const
  { Amount of Control Chars }
  NCCS = 32;
  NCC = 8;

{$ifdef cpuaarch64}

{ from Linux 4.0, include/uapi/asm-generic/ioctls.h }

  { For Terminal handling }
  TCGETS          = $5401;
  TCSETS          = $5402;
  TCSETSW         = $5403;
  TCSETSF         = $5404;
  TCGETA          = $5405;
  TCSETA          = $5406;
  TCSETAW         = $5407;
  TCSETAF         = $5408;
  TCSBRK          = $5409;
  TCXONC          = $540A;
  TCFLSH          = $540B;
  TIOCEXCL        = $540C;
  TIOCNXCL        = $540D;
  TIOCSCTTY       = $540E;
  TIOCGPGRP       = $540F;
  TIOCSPGRP       = $5410;
  TIOCOUTQ        = $5411;
  TIOCSTI         = $5412;
  TIOCGWINSZ      = $5413;
  TIOCSWINSZ      = $5414;
  TIOCMGET        = $5415;
  TIOCMBIS        = $5416;
  TIOCMBIC        = $5417;
  TIOCMSET        = $5418;
  TIOCGSOFTCAR    = $5419;
  TIOCSSOFTCAR    = $541A;
  FIONREAD        = $541B;
  TIOCINQ         = FIONREAD;
  TIOCLINUX       = $541C;
  TIOCCONS        = $541D;
  TIOCGSERIAL     = $541E;
  TIOCSSERIAL     = $541F;
  TIOCPKT         = $5420;
  FIONBIO         = $5421;
  TIOCNOTTY       = $5422;
  TIOCSETD        = $5423;
  TIOCGETD        = $5424;
  TCSBRKP         = $5425;

  TIOCSBRK        = $5427;
  TIOCCBRK        = $5428;
  TIOCGSID        = $5429;

  TIOCGRS485      = $542E;
  TIOCSRS485      = $542F;

  TCGETX          = $5432;
  TCSETX          = $5433;
  TCSETXF         = $5434;
  TCSETXW         = $5435;
  TIOCVHANGUP     = $5437;

  FIONCLEX        = $5450;
  FIOCLEX         = $5451;
  FIOASYNC        = $5452;
  TIOCSERCONFIG   = $5453;
  TIOCSERGWILD    = $5454;
  TIOCSERSWILD    = $5455;
  TIOCGLCKTRMIOS  = $5456;
  TIOCSLCKTRMIOS  = $5457;
  TIOCSERGSTRUCT  = $5458;
  TIOCSERGETLSR   = $5459;
  TIOCSERGETMULTI = $545A;
  TIOCSERSETMULTI = $545B;
  TIOCMIWAIT      = $545C;
  TIOCGICOUNT     = $545D;

  FIOQSIZE        = $5460;

  TIOCPKT_DATA       = 0;
  TIOCPKT_FLUSHREAD  = 1;
  TIOCPKT_FLUSHWRITE = 2;
  TIOCPKT_STOP       = 4;
  TIOCPKT_START      = 8;
  TIOCPKT_NOSTOP     = 16;
  TIOCPKT_DOSTOP     = 32;
  TIOCPKT_IOCTL      = 64;

  TIOCSER_TEMT       = $01;

{ from Linux 4.0, include/uapi/asm-generic/termbits.h }

  { c_cc characters }
  VINTR    = 0;
  VQUIT    = 1;
  VERASE   = 2;
  VKILL    = 3;
  VEOF     = 4;
  VTIME    = 5;
  VMIN     = 6;
  VSWTC    = 7;
  VSTART   = 8;
  VSTOP    = 9;
  VSUSP    = 10;
  VEOL     = 11;
  VREPRINT = 12;
  VDISCARD = 13;
  VWERASE  = 14;
  VLNEXT   = 15;
  VEOL2    = 16;

  { c_iflag bits }
  IGNBRK  = &0000001;
  BRKINT  = &0000002;
  IGNPAR  = &0000004;
  PARMRK  = &0000010;
  INPCK   = &0000020;
  ISTRIP  = &0000040;
  INLCR   = &0000100;
  IGNCR   = &0000200;
  ICRNL   = &0000400;
  IUCLC   = &0001000;
  IXON    = &0002000;
  IXANY   = &0004000;
  IXOFF   = &0010000;
  IMAXBEL = &0020000;
  IUTF8   = &0040000;

  { c_oflag bits }
  OPOST  = &0000001;
  OLCUC  = &0000002;
  ONLCR  = &0000004;
  OCRNL  = &0000010;
  ONOCR  = &0000020;
  ONLRET = &0000040;
  OFILL  = &0000100;
  OFDEL  = &0000200;
  NLDLY  = &0000400;
  NL0    = &0000000;
  NL1    = &0000400;
  CRDLY  = &0003000;
  CR0    = &0000000;
  CR1    = &0001000;
  CR2    = &0002000;
  CR3    = &0003000;
  TABDLY = &0014000;
  TAB0   = &0000000;
  TAB1   = &0004000;
  TAB2   = &0010000;
  TAB3   = &0014000;
  XTABS  = &0014000;
  BSDLY  = &0020000;
  BS0    = &0000000;
  BS1    = &0020000;
  VTDLY  = &0040000;
  VT0    = &0000000;
  VT1    = &0040000;
  FFDLY  = &0100000;
  FF0    = &0000000;
  FF1    = &0100000;

  { c_cflag bits }
  CBAUD    = &0010017;
  B0       = &0000000;
  B50      = &0000001;
  B75      = &0000002;
  B110     = &0000003;
  B134     = &0000004;
  B150     = &0000005;
  B200     = &0000006;
  B300     = &0000007;
  B600     = &0000010;
  B1200    = &0000011;
  B1800    = &0000012;
  B2400    = &0000013;
  B4800    = &0000014;
  B9600    = &0000015;
  B19200   = &0000016;
  B38400   = &0000017;
  EXTA     = B19200;
  EXTB     = B38400;
  CSIZE    = &0000060;
  CS5      = &0000000;
  CS6      = &0000020;
  CS7      = &0000040;
  CS8      = &0000060;
  CSTOPB   = &0000100;
  CREAD    = &0000200;
  PARENB   = &0000400;
  PARODD   = &0001000;
  HUPCL    = &0002000;
  CLOCAL   = &0004000;
  CBAUDEX  = &0010000;
  BOTHER   = &0010000;
  B57600   = &0010001;
  B115200  = &0010002;
  B230400  = &0010003;
  B460800  = &0010004;
  B500000  = &0010005;
  B576000  = &0010006;
  B921600  = &0010007;
  B1000000 = &0010010;
  B1152000 = &0010011;
  B1500000 = &0010012;
  B2000000 = &0010013;
  B2500000 = &0010014;
  B3000000 = &0010015;
  B3500000 = &0010016;
  B4000000 = &0010017;
  __MAX_BAUD =  B4000000;

  CIBAUD   = &002003600000;
  CMSPAR   = &010000000000;
  CRTSCTS  = &020000000000;

  IBSHIFT  = 16;

  { c_lflag bits }
  ISIG    = &0000001;
  ICANON  = &0000002;
  XCASE   = &0000004;
  ECHO    = &0000010;
  ECHOE   = &0000020;
  ECHOK   = &0000040;
  ECHONL  = &0000100;
  NOFLSH  = &0000200;
  TOSTOP  = &0000400;
  ECHOCTL = &0001000;
  ECHOPRT = &0002000;
  ECHOKE  = &0004000;
  FLUSHO  = &0010000;
  PENDIN  = &0040000;
  IEXTEN  = &0100000;
  EXTPROC = &0200000;

  { TCFlow }
  TCOOFF = 0;
  TCOON  = 1;
  TCIOFF = 2;
  TCION  = 3;

  { TCFlush }
  TCIFLUSH  = 0;
  TCOFLUSH  = 1;
  TCIOFLUSH = 2;

  { TCSetAttr }
  TCSANOW   = 0;
  TCSADRAIN = 1;
  TCSAFLUSH = 2;

{ from Linux 4.0, include/uapi/asm-generic/termios.h }

  { c_line bits }
  TIOCM_LE   = $001;
  TIOCM_DTR  = $002;
  TIOCM_RTS  = $004;
  TIOCM_ST   = $008;
  TIOCM_SR   = $010;
  TIOCM_CTS  = $020;
  TIOCM_CAR  = $040;
  TIOCM_RNG  = $080;
  TIOCM_DSR  = $100;
  TIOCM_CD   = TIOCM_CAR;
  TIOCM_RI   = TIOCM_RNG;
  TIOCM_OUT1 = $2000;
  TIOCM_OUT2 = $4000;
  TIOCM_LOOP = $8000;

{$endif cpuaarch64}




{$ifdef cpui386}
  { For Terminal handling }
  TCGETS          = $5401;
  TCSETS          = $5402;
  TCSETSW         = $5403;
  TCSETSF         = $5404;
  TCGETA          = $5405;
  TCSETA          = $5406;
  TCSETAW         = $5407;
  TCSETAF         = $5408;
  TCSBRK          = $5409;
  TCXONC          = $540A;
  TCFLSH          = $540B;
  TIOCEXCL        = $540C;
  TIOCNXCL        = $540D;
  TIOCSCTTY       = $540E;
  TIOCGPGRP       = $540F;
  TIOCSPGRP       = $5410;
  TIOCOUTQ        = $5411;
  TIOCSTI         = $5412;
  TIOCGWINSZ      = $5413;
  TIOCSWINSZ      = $5414;
  TIOCMGET        = $5415;
  TIOCMBIS        = $5416;
  TIOCMBIC        = $5417;
  TIOCMSET        = $5418;
  TIOCGSOFTCAR    = $5419;
  TIOCSSOFTCAR    = $541A;
  FIONREAD        = $541B;
  TIOCINQ         = FIONREAD;
  TIOCLINUX       = $541C;
  TIOCCONS        = $541D;
  TIOCGSERIAL     = $541E;
  TIOCSSERIAL     = $541F;
  TIOCPKT         = $5420;
  FIONBIO         = $5421;
  TIOCNOTTY       = $5422;
  TIOCSETD        = $5423;
  TIOCGETD        = $5424;
  TCSBRKP         = $5425;
  TIOCTTYGSTRUCT  = $5426;
  FIONCLEX        = $5450;
  FIOCLEX         = $5451;
  FIOASYNC        = $5452;
  TIOCSERCONFIG   = $5453;
  TIOCSERGWILD    = $5454;
  TIOCSERSWILD    = $5455;
  TIOCGLCKTRMIOS  = $5456;
  TIOCSLCKTRMIOS  = $5457;
  TIOCSERGSTRUCT  = $5458;
  TIOCSERGETLSR   = $5459;
  TIOCSERGETMULTI = $545A;
  TIOCSERSETMULTI = $545B;

  TIOCMIWAIT      = $545C;
  TIOCGICOUNT     = $545D;
  TIOCGHAYESESP   = $545E;
  TIOCSHAYESESP   = $545F;
  FIOQSIZE        = $5460;


  TIOCPKT_DATA       = 0;
  TIOCPKT_FLUSHREAD  = 1;
  TIOCPKT_FLUSHWRITE = 2;
  TIOCPKT_STOP       = 4;
  TIOCPKT_START      = 8;
  TIOCPKT_NOSTOP     = 16;
  TIOCPKT_DOSTOP     = 32;

{c_cc characters}
  VINTR    = 0;
  VQUIT    = 1;
  VERASE   = 2;
  VKILL    = 3;
  VEOF     = 4;
  VTIME    = 5;
  VMIN     = 6;
  VSWTC    = 7;
  VSTART   = 8;
  VSTOP    = 9;
  VSUSP    = 10;
  VEOL     = 11;
  VREPRINT = 12;
  VDISCARD = 13;
  VWERASE  = 14;
  VLNEXT   = 15;
  VEOL2    = 16;

{c_iflag bits}
   IGNBRK  = $0000001;
   BRKINT  = $0000002;
   IGNPAR  = $0000004;
   PARMRK  = $0000008;
   INPCK   = $0000010;
   ISTRIP  = $0000020;
   INLCR   = $0000040;
   IGNCR   = $0000080;
   ICRNL   = $0000100;
   IUCLC   = $0000200;
   IXON    = $0000400;
   IXANY   = $0000800;
   IXOFF   = $0001000;
   IMAXBEL = $0002000;
   IUTF8   = $0004000;

{c_oflag bits}
   OPOST  = $0000001;
   OLCUC  = $0000002;
   ONLCR  = $0000004;
   OCRNL  = $0000008;
   ONOCR  = $0000010;
   ONLRET = $0000020;
   OFILL  = $0000040;
   OFDEL  = $0000080;
   NLDLY  = $0000100;
     NL0  = $0000000;
     NL1  = $0000100;
   CRDLY  = $0000600;
     CR0  = $0000000;
     CR1  = $0000200;
     CR2  = $0000400;
     CR3  = $0000600;
   TABDLY = $0001800;
     TAB0 = $0000000;
     TAB1 = $0000800;
     TAB2 = $0001000;
     TAB3 = $0001800;
    XTABS = $0001800;
   BSDLY  = $0002000;
     BS0  = $0000000;
     BS1  = $0002000;
   VTDLY  = $0004000;
     VT0  = $0000000;
     VT1  = $0004000;
   FFDLY  = $0008000;
     FF0  = $0000000;
     FF1  = $0008000;

{c_cflag bits}
   CBAUD   = $000100F;
   B0      = $0000000;
   B50     = $0000001;
   B75     = $0000002;
   B110    = $0000003;
   B134    = $0000004;
   B150    = $0000005;
   B200    = $0000006;
   B300    = $0000007;
   B600    = $0000008;
   B1200   = $0000009;
   B1800   = $000000A;
   B2400   = $000000B;
   B4800   = $000000C;
   B9600   = $000000D;
   B19200  = $000000E;
   B38400  = $000000F;
   EXTA    = B19200;
   EXTB    = B38400;
   CSIZE   = $0000030;
     CS5   = $0000000;
     CS6   = $0000010;
     CS7   = $0000020;
     CS8   = $0000030;
   CSTOPB  = $0000040;
   CREAD   = $0000080;
   PARENB  = $0000100;
   PARODD  = $0000200;
   HUPCL   = $0000400;
   CLOCAL  = $0000800;
   CBAUDEX = $0001000;
   B57600  = $0001001;
   B115200 = $0001002;
   B230400 = $0001003;
   B460800 = $0001004;
   B500000 = $0001005;
   B576000 = $0001006;
   B921600 = $0001007;
   B1000000= $0001008;
   B1152000= $0001009;
   B1500000= $000100A;
   B2000000= $000100B;
   B2500000= $000100C;
   B3000000= $000100D;
   B3500000= $000100E;
   B4000000= $000100F;
   __MAX_BAUD=  B4000000;

   CIBAUD  = $100F0000;
   CMSPAR  = $40000000;
   CRTSCTS = $80000000;

{c_lflag bits}
   ISIG    = $0000001;
   ICANON  = $0000002;
   XCASE   = $0000004;
   ECHO    = $0000008;
   ECHOE   = $0000010;
   ECHOK   = $0000020;
   ECHONL  = $0000040;
   NOFLSH  = $0000080;
   TOSTOP  = $0000100;
   ECHOCTL = $0000200;
   ECHOPRT = $0000400;
   ECHOKE  = $0000800;
   FLUSHO  = $0001000;
   PENDIN  = $0004000;
   IEXTEN  = $0008000;

{c_line bits}
   TIOCM_LE   = $001;
   TIOCM_DTR  = $002;
   TIOCM_RTS  = $004;
   TIOCM_ST   = $008;
   TIOCM_SR   = $010;
   TIOCM_CTS  = $020;
   TIOCM_CAR  = $040;
   TIOCM_RNG  = $080;
   TIOCM_DSR  = $100;
   TIOCM_CD   = TIOCM_CAR;
   TIOCM_RI   = TIOCM_RNG;
   TIOCM_OUT1 = $2000;
   TIOCM_OUT2 = $4000;

{TCSetAttr}
   TCSANOW   = 0;
   TCSADRAIN = 1;
   TCSAFLUSH = 2;

{TCFlow}
   TCOOFF = 0;
   TCOON  = 1;
   TCIOFF = 2;
   TCION  = 3;

{TCFlush}
   TCIFLUSH  = 0;
   TCOFLUSH  = 1;
   TCIOFLUSH = 2;

{$endif cpui386}


{$ifdef cpux86_64}
  TCGETS =              $5401;
  TCSETS =              $5402;
  TCSETSW =             $5403;
  TCSETSF =             $5404;
  TCGETA =              $5405;
  TCSETA =              $5406;
  TCSETAW =             $5407;
  TCSETAF =             $5408;
  TCSBRK =              $5409;
  TCXONC =              $540A;
  TCFLSH =              $540B;
  TIOCEXCL =    $540C;
  TIOCNXCL =    $540D;
  TIOCSCTTY =   $540E;
  TIOCGPGRP =   $540F;
  TIOCSPGRP =   $5410;
  TIOCOUTQ =    $5411;
  TIOCSTI =             $5412;
  TIOCGWINSZ =  $5413;
  TIOCSWINSZ =  $5414;
  TIOCMGET =    $5415;
  TIOCMBIS =    $5416;
  TIOCMBIC =    $5417;
  TIOCMSET =    $5418;
  TIOCGSOFTCAR =        $5419;
  TIOCSSOFTCAR =        $541A;
  FIONREAD =    $541B;
  TIOCINQ =             FIONREAD;
  TIOCLINUX =   $541C;
  TIOCCONS =    $541D;
  TIOCGSERIAL = $541E;
  TIOCSSERIAL = $541F;
  TIOCPKT =             $5420;
  FIONBIO =             $5421;
  TIOCNOTTY =   $5422;
  TIOCSETD =    $5423;
  TIOCGETD =    $5424;
  TCSBRKP =             $5425;
  TIOCSBRK =    $5427;
  TIOCCBRK =    $5428;
  TIOCGSID =    $5429;
  FIONCLEX =    $5450;
  FIOCLEX =             $5451;
  FIOASYNC =    $5452;
  TIOCSERCONFIG =       $5453;
  TIOCSERGWILD =        $5454;
  TIOCSERSWILD =        $5455;
  TIOCGLCKTRMIOS =      $5456;
  TIOCSLCKTRMIOS =      $5457;
  TIOCSERGSTRUCT =      $5458;
  TIOCSERGETLSR =   $5459;
  TIOCSERGETMULTI = $545A;
  TIOCSERSETMULTI = $545B;
  TIOCMIWAIT =  $545C;
  TIOCGICOUNT = $545D;
  TIOCGHAYESESP =   $545E;
  TIOCSHAYESESP =   $545F;
  FIOQSIZE =       $5460;
  TIOCPKT_DATA =                 0;
  TIOCPKT_FLUSHREAD =    1;
  TIOCPKT_FLUSHWRITE =   2;
  TIOCPKT_STOP =                 4;
  TIOCPKT_START =                8;
  TIOCPKT_NOSTOP =              16;
  TIOCPKT_DOSTOP =              32;
  TIOCSER_TEMT =    $01;

{c_cc characters}
  VINTR    = 0;
  VQUIT    = 1;
  VERASE   = 2;
  VKILL    = 3;
  VEOF     = 4;
  VTIME    = 5;
  VMIN     = 6;
  VSWTC    = 7;
  VSTART   = 8;
  VSTOP    = 9;
  VSUSP    = 10;
  VEOL     = 11;
  VREPRINT = 12;
  VDISCARD = 13;
  VWERASE  = 14;
  VLNEXT   = 15;
  VEOL2    = 16;

{c_iflag bits}
   IGNBRK  = $0000001;
   BRKINT  = $0000002;
   IGNPAR  = $0000004;
   PARMRK  = $0000008;
   INPCK   = $0000010;
   ISTRIP  = $0000020;
   INLCR   = $0000040;
   IGNCR   = $0000080;
   ICRNL   = $0000100;
   IUCLC   = $0000200;
   IXON    = $0000400;
   IXANY   = $0000800;
   IXOFF   = $0001000;
   IMAXBEL = $0002000;

{c_oflag bits}
   OPOST  = $0000001;
   OLCUC  = $0000002;
   ONLCR  = $0000004;
   OCRNL  = $0000008;
   ONOCR  = $0000010;
   ONLRET = $0000020;
   OFILL  = $0000040;
   OFDEL  = $0000080;
   NLDLY  = $0000100;
     NL0  = $0000000;
     NL1  = $0000100;
   CRDLY  = $0000600;
     CR0  = $0000000;
     CR1  = $0000200;
     CR2  = $0000400;
     CR3  = $0000600;
   TABDLY = $0001800;
     TAB0 = $0000000;
     TAB1 = $0000800;
     TAB2 = $0001000;
     TAB3 = $0001800;
    XTABS = $0001800;
   BSDLY  = $0002000;
     BS0  = $0000000;
     BS1  = $0002000;
   VTDLY  = $0004000;
     VT0  = $0000000;
     VT1  = $0004000;
   FFDLY  = $0008000;
     FF0  = $0000000;
     FF1  = $0008000;

{c_cflag bits}
   CBAUD   = $000100F;
   B0      = $0000000;
   B50     = $0000001;
   B75     = $0000002;
   B110    = $0000003;
   B134    = $0000004;
   B150    = $0000005;
   B200    = $0000006;
   B300    = $0000007;
   B600    = $0000008;
   B1200   = $0000009;
   B1800   = $000000A;
   B2400   = $000000B;
   B4800   = $000000C;
   B9600   = $000000D;
   B19200  = $000000E;
   B38400  = $000000F;
   EXTA    = B19200;
   EXTB    = B38400;
   CSIZE   = $0000030;
     CS5   = $0000000;
     CS6   = $0000010;
     CS7   = $0000020;
     CS8   = $0000030;
   CSTOPB  = $0000040;
   CREAD   = $0000080;
   PARENB  = $0000100;
   PARODD  = $0000200;
   HUPCL   = $0000400;
   CLOCAL  = $0000800;
   CBAUDEX = $0001000;
   B57600  = $0001001;
   B115200 = $0001002;
   B230400 = $0001003;
   B460800 = $0001004;
   CIBAUD  = $100F0000;
   CMSPAR  = $40000000;
   CRTSCTS = $80000000;
   B500000 = $0001005;
   B576000 = $0001006;
   B921600 = $0001007;
   B1000000= $0001008;
   B1152000= $0001009;
   B1500000= $000100A;
   B2000000= $000100B;
   B2500000= $000100C;
   B3000000= $000100D;
   B3500000= $000100E;
   B4000000= $000100F;
   __MAX_BAUD=  B4000000;

{c_lflag bits}
   ISIG    = $0000001;
   ICANON  = $0000002;
   XCASE   = $0000004;
   ECHO    = $0000008;
   ECHOE   = $0000010;
   ECHOK   = $0000020;
   ECHONL  = $0000040;
   NOFLSH  = $0000080;
   TOSTOP  = $0000100;
   ECHOCTL = $0000200;
   ECHOPRT = $0000400;
   ECHOKE  = $0000800;
   FLUSHO  = $0001000;
   PENDIN  = $0004000;
   IEXTEN  = $0008000;

{c_line bits}
   TIOCM_LE   = $001;
   TIOCM_DTR  = $002;
   TIOCM_RTS  = $004;
   TIOCM_ST   = $008;
   TIOCM_SR   = $010;
   TIOCM_CTS  = $020;
   TIOCM_CAR  = $040;
   TIOCM_RNG  = $080;
   TIOCM_DSR  = $100;
   TIOCM_CD   = TIOCM_CAR;
   TIOCM_RI   = TIOCM_RNG;
   TIOCM_OUT1 = $2000;
   TIOCM_OUT2 = $4000;

{TCSetAttr}
   TCSANOW   = 0;
   TCSADRAIN = 1;
   TCSAFLUSH = 2;

{TCFlow}
   TCOOFF = 0;
   TCOON  = 1;
   TCIOFF = 2;
   TCION  = 3;

{TCFlush}
   TCIFLUSH  = 0;
   TCOFLUSH  = 1;
   TCIOFLUSH = 2;

{$endif cpux86_64}

{$ifdef cpuarm}
  { For Terminal handling }
  TCGETS          = $5401;
  TCSETS          = $5402;
  TCSETSW         = $5403;
  TCSETSF         = $5404;
  TCGETA          = $5405;
  TCSETA          = $5406;
  TCSETAW         = $5407;
  TCSETAF         = $5408;
  TCSBRK          = $5409;
  TCXONC          = $540A;
  TCFLSH          = $540B;
  TIOCEXCL        = $540C;
  TIOCNXCL        = $540D;
  TIOCSCTTY       = $540E;
  TIOCGPGRP       = $540F;
  TIOCSPGRP       = $5410;
  TIOCOUTQ        = $5411;
  TIOCSTI         = $5412;
  TIOCGWINSZ      = $5413;
  TIOCSWINSZ      = $5414;
  TIOCMGET        = $5415;
  TIOCMBIS        = $5416;
  TIOCMBIC        = $5417;
  TIOCMSET        = $5418;
  TIOCGSOFTCAR    = $5419;
  TIOCSSOFTCAR    = $541A;
  FIONREAD        = $541B;
  TIOCINQ         = FIONREAD;
  TIOCLINUX       = $541C;
  TIOCCONS        = $541D;
  TIOCGSERIAL     = $541E;
  TIOCSSERIAL     = $541F;
  TIOCPKT         = $5420;
  FIONBIO         = $5421;
  TIOCNOTTY       = $5422;
  TIOCSETD        = $5423;
  TIOCGETD        = $5424;
  TCSBRKP         = $5425;
  TIOCTTYGSTRUCT  = $5426;
  FIONCLEX        = $5450;
  FIOCLEX         = $5451;
  FIOASYNC        = $5452;
  TIOCSERCONFIG   = $5453;
  TIOCSERGWILD    = $5454;
  TIOCSERSWILD    = $5455;
  TIOCGLCKTRMIOS  = $5456;
  TIOCSLCKTRMIOS  = $5457;
  TIOCSERGSTRUCT  = $5458;
  TIOCSERGETLSR   = $5459;
  TIOCSERGETMULTI = $545A;
  TIOCSERSETMULTI = $545B;

  TIOCMIWAIT      = $545C;
  TIOCGICOUNT     = $545D;
  FIOQSIZE        = $545E;

  TIOCPKT_DATA       = 0;
  TIOCPKT_FLUSHREAD  = 1;
  TIOCPKT_FLUSHWRITE = 2;
  TIOCPKT_STOP       = 4;
  TIOCPKT_START      = 8;
  TIOCPKT_NOSTOP     = 16;
  TIOCPKT_DOSTOP     = 32;

{c_cc characters}
  VINTR    = 0;
  VQUIT    = 1;
  VERASE   = 2;
  VKILL    = 3;
  VEOF     = 4;
  VTIME    = 5;
  VMIN     = 6;
  VSWTC    = 7;
  VSTART   = 8;
  VSTOP    = 9;
  VSUSP    = 10;
  VEOL     = 11;
  VREPRINT = 12;
  VDISCARD = 13;
  VWERASE  = 14;
  VLNEXT   = 15;
  VEOL2    = 16;

{c_iflag bits}
   IGNBRK  = $0000001;
   BRKINT  = $0000002;
   IGNPAR  = $0000004;
   PARMRK  = $0000008;
   INPCK   = $0000010;
   ISTRIP  = $0000020;
   INLCR   = $0000040;
   IGNCR   = $0000080;
   ICRNL   = $0000100;
   IUCLC   = $0000200;
   IXON    = $0000400;
   IXANY   = $0000800;
   IXOFF   = $0001000;
   IMAXBEL = $0002000;

{c_oflag bits}
   OPOST  = $0000001;
   OLCUC  = $0000002;
   ONLCR  = $0000004;
   OCRNL  = $0000008;
   ONOCR  = $0000010;
   ONLRET = $0000020;
   OFILL  = $0000040;
   OFDEL  = $0000080;
   NLDLY  = $0000100;
     NL0  = $0000000;
     NL1  = $0000100;
   CRDLY  = $0000600;
     CR0  = $0000000;
     CR1  = $0000200;
     CR2  = $0000400;
     CR3  = $0000600;
   TABDLY = $0001800;
     TAB0 = $0000000;
     TAB1 = $0000800;
     TAB2 = $0001000;
     TAB3 = $0001800;
    XTABS = $0001800;
   BSDLY  = $0002000;
     BS0  = $0000000;
     BS1  = $0002000;
   VTDLY  = $0004000;
     VT0  = $0000000;
     VT1  = $0004000;
   FFDLY  = $0008000;
     FF0  = $0000000;
     FF1  = $0008000;

{c_cflag bits}
   CBAUD   = $000100F;
   B0      = $0000000;
   B50     = $0000001;
   B75     = $0000002;
   B110    = $0000003;
   B134    = $0000004;
   B150    = $0000005;
   B200    = $0000006;
   B300    = $0000007;
   B600    = $0000008;
   B1200   = $0000009;
   B1800   = $000000A;
   B2400   = $000000B;
   B4800   = $000000C;
   B9600   = $000000D;
   B19200  = $000000E;
   B38400  = $000000F;
   EXTA    = B19200;
   EXTB    = B38400;
   CSIZE   = $0000030;
     CS5   = $0000000;
     CS6   = $0000010;
     CS7   = $0000020;
     CS8   = $0000030;
   CSTOPB  = $0000040;
   CREAD   = $0000080;
   PARENB  = $0000100;
   PARODD  = $0000200;
   HUPCL   = $0000400;
   CLOCAL  = $0000800;
   CBAUDEX = $0001000;
   B57600  = $0001001;
   B115200 = $0001002;
   B230400 = $0001003;
   B460800 = $0001004;
   B500000 = $1005;
   B576000 = $1006;
   B921600 = $1007;
   B1000000= $1008;
   B1152000= $1009;
   B1500000= $100a;
   B2000000= $100b;
   B2500000= $100c;
   B3000000= $100d;
   B3500000= $100e;
   B4000000= $100f;
   __MAX_BAUD=  B4000000;

   CIBAUD  = $100F0000;
   CMSPAR  = $40000000;
   CRTSCTS = $80000000;

{c_lflag bits}
   ISIG    = $0000001;
   ICANON  = $0000002;
   XCASE   = $0000004;
   ECHO    = $0000008;
   ECHOE   = $0000010;
   ECHOK   = $0000020;
   ECHONL  = $0000040;
   NOFLSH  = $0000080;
   TOSTOP  = $0000100;
   ECHOCTL = $0000200;
   ECHOPRT = $0000400;
   ECHOKE  = $0000800;
   FLUSHO  = $0001000;
   PENDIN  = $0004000;
   IEXTEN  = $0008000;

{c_line bits}
   TIOCM_LE   = $001;
   TIOCM_DTR  = $002;
   TIOCM_RTS  = $004;
   TIOCM_ST   = $008;
   TIOCM_SR   = $010;
   TIOCM_CTS  = $020;
   TIOCM_CAR  = $040;
   TIOCM_RNG  = $080;
   TIOCM_DSR  = $100;
   TIOCM_CD   = TIOCM_CAR;
   TIOCM_RI   = TIOCM_RNG;
   TIOCM_OUT1 = $2000;
   TIOCM_OUT2 = $4000;

{TCSetAttr}
   TCSANOW   = 0;
   TCSADRAIN = 1;
   TCSAFLUSH = 2;

{TCFlow}
   TCOOFF = 0;
   TCOON  = 1;
   TCIOFF = 2;
   TCION  = 3;

{TCFlush}
   TCIFLUSH  = 0;
   TCOFLUSH  = 1;
   TCIOFLUSH = 2;

{$endif cpuarm}



{$ifdef CPUM68K}

const
  TCGETS = $5401;
  TCSETS = $5402;
  TCSETSW = $5403;
  TCSETSF = $5404;
  TCGETA = $5405;
  TCSETA = $5406;
  TCSETAW = $5407;
  TCSETAF = $5408;
  TCSBRK = $5409;
  TCXONC = $540A;
  TCFLSH = $540B;
  TIOCEXCL = $540C;
  TIOCNXCL = $540D;
  TIOCSCTTY = $540E;
  TIOCGPGRP = $540F;
  TIOCSPGRP = $5410;
  TIOCOUTQ = $5411;
  TIOCSTI = $5412;
  TIOCGWINSZ = $5413;
  TIOCSWINSZ = $5414;
  TIOCMGET = $5415;
  TIOCMBIS = $5416;
  TIOCMBIC = $5417;
  TIOCMSET = $5418;
  TIOCGSOFTCAR = $5419;
  TIOCSSOFTCAR = $541A;
  FIONREAD = $541B;
  TIOCINQ = FIONREAD;
  TIOCLINUX = $541C;
  TIOCCONS = $541D;
  TIOCGSERIAL = $541E;
  TIOCSSERIAL = $541F;
  TIOCPKT = $5420;
  FIONBIO = $5421;
  TIOCNOTTY = $5422;
  TIOCSETD = $5423;
  TIOCGETD = $5424;
  TCSBRKP = $5425;
  TIOCSBRK = $5427;
  TIOCCBRK = $5428;
  TIOCGSID = $5429;
  TIOCGRS485 = $542E;
  TIOCSRS485 = $542F;
  TCGETX = $5432;
  TCSETX = $5433;
  TCSETXF = $5434;
  TCSETXW = $5435;
  TIOCVHANGUP = $5437;
  FIONCLEX = $5450;
  FIOCLEX = $5451;
  FIOASYNC = $5452;
  TIOCSERCONFIG = $5453;
  TIOCSERGWILD = $5454;
  TIOCSERSWILD = $5455;
  TIOCGLCKTRMIOS = $5456;
  TIOCSLCKTRMIOS = $5457;
  TIOCSERGSTRUCT = $5458;
  TIOCSERGETLSR = $5459;
  TIOCSERGETMULTI = $545A;
  TIOCSERSETMULTI = $545B;
  TIOCMIWAIT = $545C;
  TIOCGICOUNT = $545D;

  { c_cc characters  }
  VINTR = 0;
  VQUIT = 1;
  VERASE = 2;
  VKILL = 3;
  VEOF = 4;
  VTIME = 5;
  VMIN = 6;
  VSWTC = 7;
  VSTART = 8;
  VSTOP = 9;
  VSUSP = 10;
  VEOL = 11;
  VREPRINT = 12;
  VDISCARD = 13;
  VWERASE = 14;
  VLNEXT = 15;
  VEOL2 = 16;

  { c_iflag bits  }
  IGNBRK = &000001;
  BRKINT = &000002;
  IGNPAR = &000004;
  PARMRK = &000010;
  INPCK = &000020;
  ISTRIP = &000040;
  INLCR = &000100;
  IGNCR = &000200;
  ICRNL = &000400;
  IUCLC = &001000;
  IXON = &002000;
  IXANY = &004000;
  IXOFF = &010000;
  IMAXBEL = &020000;
  IUTF8 = &040000;

  { c_oflag bits  }
  OPOST = &000001;
  OLCUC = &000002;
  ONLCR = &000004;
  OCRNL = &000010;
  ONOCR = &000020;
  ONLRET = &000040;
  OFILL = &000100;
  OFDEL = &000200;
  NLDLY = &000400;
  NL0 = &000000;
  NL1 = &000400;
  CRDLY = &003000;
  CR0 = &000000;
  CR1 = &001000;
  CR2 = &002000;
  CR3 = &003000;
  TABDLY = &014000;
  TAB0 = &000000;
  TAB1 = &004000;
  TAB2 = &010000;
  TAB3 = &014000;
  XTABS = &014000;
  BSDLY = &020000;
  BS0 = &000000;
  BS1 = &020000;
  VTDLY = &040000;
  VT0 = &000000;
  VT1 = &040000;
  FFDLY = &100000;
  FF0 = &000000;
  FF1 = &100000;

  { c_cflag bit meaning  }
  CBAUD = &010017;

  { hang up  }
  B0 = &000000;
  B50 = &000001;
  B75 = &000002;
  B110 = &000003;
  B134 = &000004;
  B150 = &000005;
  B200 = &000006;
  B300 = &000007;
  B600 = &000010;
  B1200 = &000011;
  B1800 = &000012;
  B2400 = &000013;
  B4800 = &000014;
  B9600 = &000015;
  B19200 = &000016;
  B38400 = &000017;
  EXTA = B19200;
  EXTB = B38400;
  CSIZE = &000060;
  CS5 = &000000;
  CS6 = &000020;
  CS7 = &000040;
  CS8 = &000060;
  CSTOPB = &000100;
  CREAD = &000200;
  PARENB = &000400;
  PARODD = &001000;
  HUPCL = &002000;
  CLOCAL = &004000;
  CBAUDEX = &010000;
  BOTHER = &010000;
  B57600 = &010001;
  B115200 = &010002;
  B230400 = &010003;
  B460800 = &010004;
  B500000 = &010005;
  B576000 = &010006;
  B921600 = &010007;
  B1000000 = &010010;
  B1152000 = &010011;
  B1500000 = &010012;
  B2000000 = &010013;
  B2500000 = &010014;
  B3000000 = &010015;
  B3500000 = &010016;
  B4000000 = &010017;
  __MAX_BAUD=  B4000000;

  CIBAUD = &02003600000;
  CMSPAR = &10000000000;
  CRTSCTS = &20000000000;
  IBSHIFT = 16;

  { c_lflag bits  }
  ISIG = &000001;
  ICANON = &000002;
  XCASE = &000004;
  ECHO = &000010;
  ECHOE = &000020;
  ECHOK = &000040;
  ECHONL = &000100;
  NOFLSH = &000200;
  TOSTOP = &000400;
  ECHOCTL = &001000;
  ECHOPRT = &002000;
  ECHOKE = &004000;
  FLUSHO = &010000;
  PENDIN = &040000;
  IEXTEN = &100000;
  EXTPROC = &200000;

  TCOOFF = 0;
  TCOON = 1;
  TCIOFF = 2;
  TCION = 3;

  TCIFLUSH = 0;
  TCOFLUSH = 1;
  TCIOFLUSH = 2;

  TCSANOW = 0;
  TCSADRAIN = 1;
  TCSAFLUSH = 2;

  { modem lines }
  TIOCM_LE = $001;
  TIOCM_DTR = $002;
  TIOCM_RTS = $004;
  TIOCM_ST = $008;
  TIOCM_SR = $010;
  TIOCM_CTS = $020;
  TIOCM_CAR = $040;
  TIOCM_RNG = $080;
  TIOCM_DSR = $100;
  TIOCM_CD = TIOCM_CAR;
  TIOCM_RI = TIOCM_RNG;
  TIOCM_OUT1 = $2000;
  TIOCM_OUT2 = $4000;
  TIOCM_LOOP = $8000;

{$endif CPUM68K}




Type
  winsize = record
    ws_row,
    ws_col,
    ws_xpixel,
    ws_ypixel : word;
  end;
  TWinSize=winsize;

{$PACKRECORDS C}
  Termios = record
    c_iflag,
    c_oflag,
    c_cflag,
    c_lflag  : cardinal;
    c_line   : AnsiChar;
    c_cc     : array[0..NCCS-1] of byte;
    c_ispeed,
    c_ospeed : cardinal;
  end;
  TTermios=Termios;
{$PACKRECORDS Default}

