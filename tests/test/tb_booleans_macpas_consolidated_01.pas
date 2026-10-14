{ Consolidated booleans regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode macpas}

{ Case tmacbool.pas }
{$push}




{ checks boolean evaluation in macpas mode }

var
  tmacbool_ftruecalled, tmacbool_ffalsecalled: boolean;

function tmacbool_ftrue: boolean;
begin
  tmacbool_ftruecalled := true;
  tmacbool_ftrue := true;
end;

function tmacbool_ffalse: boolean;
begin
  tmacbool_ffalsecalled := true;
  tmacbool_ffalse := false;
end;



{$pop}

{ Case tmaclocalprocparam1.pas }
{$push}



	var
		tmaclocalprocparam1_failed: Boolean;


	procedure tmaclocalprocparam1_Outside (procedure P);
	begin
		P;
	end;

	procedure tmaclocalprocparam1_Global;

		var
			nonlocalvar: integer;

		procedure Local;
		begin
			nonlocalvar := 42;
		end;

	begin
		nonlocalvar := 24;
		tmaclocalprocparam1_Outside(Local);
		tmaclocalprocparam1_failed := (nonlocalvar <> 42);
	end;




{$pop}

{ Case tmaclocalprocparam1a.pas }
{$push}



        type
                tmaclocalprocparam1a_tnestedproc = procedure is nested;

	var
		tmaclocalprocparam1a_failed: Boolean;


	procedure tmaclocalprocparam1a_Outside (P: tmaclocalprocparam1a_tnestedproc);
	begin
		P;
	end;

	procedure tmaclocalprocparam1a_Global;

		var
			nonlocalvar: integer;

		procedure Local;
		begin
			nonlocalvar := 42;
		end;

	begin
		nonlocalvar := 24;
		tmaclocalprocparam1a_Outside(Local);
		tmaclocalprocparam1a_failed := (nonlocalvar <> 42);
	end;




{$pop}

{ Case tmacnonlocalexit1.pas }
{$push}



	var
		tmacnonlocalexit1_failed: Boolean;

	procedure tmacnonlocalexit1_Global;

		procedure Local;
		begin
			Exit(tmacnonlocalexit1_Global);
			tmacnonlocalexit1_failed := true;
		end;

	begin
		Local;
		tmacnonlocalexit1_failed := true;
	end;



{$pop}

{ Case tmacpas2.pas }
{$push}


{Tests of mac pascal constructs}



var
  tmacpas2_success: Boolean = true;

type
  {Since we do not want to compile in the whole mac api, we
   simulate decl of FourCharCode here:}

  tmacpas2_MyFourCharCodeType = Longword;

procedure tmacpas2_Proc;

begin
  {** Exit with proc name as argument **}
  Exit(tmacpas2_Proc);
end;

procedure tmacpas2_TestFourCharCode(myFCC: tmacpas2_MyFourCharCodeType);

begin
  Writeln('FPC creator code as number: ', hexstr(myFCC,8));
  if myFCC <> $46506173 then
    tmacpas2_success := false;
end;

const
  tmacpas2_myFCCconst = 'FPas'; {Free Pascals Creator code :) }

var
  tmacpas2_p: pointer;
  tmacpas2_l,tmacpas2_i: longint;
  tmacpas2_a,tmacpas2_b,tmacpas2_c : Boolean;


{$pop}

begin

{ Case tmacbool.pas }
{$push}

begin
  { OR and |, short circuit }
{$b-}
  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if (tmacbool_ftrue or tmacbool_ffalse) then
    begin
      if not(tmacbool_ftruecalled) then
        halt(1);
      if tmacbool_ffalsecalled then
        halt(2);
    end
  else
    halt(128);

  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if not(tmacbool_ffalse or tmacbool_ftrue) then
    halt(3);
  if not(tmacbool_ffalsecalled) then
    halt(4);
  if not(tmacbool_ftruecalled) then
    halt(5);

  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if (tmacbool_ftrue | tmacbool_ffalse) then
    begin
      if not(tmacbool_ftruecalled) then
        halt(6);
      if tmacbool_ffalsecalled then
        halt(7);
    end
  else
    halt(129);

  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if not(tmacbool_ffalse | tmacbool_ftrue) then
    halt(8);
  if not(tmacbool_ffalsecalled) then
    halt(9);
  if not(tmacbool_ftruecalled) then
    halt(10);


  { OR and |, full evaluation }
{$b+}
  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if (tmacbool_ftrue or tmacbool_ffalse) then
    begin
      if not(tmacbool_ftruecalled) then
        halt(11);
      if not(tmacbool_ffalsecalled) then
        halt(12);
    end
  else
    halt(130);

  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if not(tmacbool_ffalse or tmacbool_ftrue) then
    halt(13);
  if not(tmacbool_ffalsecalled) then
    halt(14);
  if not(tmacbool_ftruecalled) then
    halt(15);

  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if (tmacbool_ftrue | tmacbool_ffalse) then
    begin
      if not(tmacbool_ftruecalled) then
        halt(16);
      if tmacbool_ffalsecalled then
        halt(17);
    end
  else
    halt(131);

  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if not(tmacbool_ffalse | tmacbool_ftrue) then
    halt(18);
  if not(tmacbool_ffalsecalled) then
    halt(19);
  if not(tmacbool_ftruecalled) then
    halt(20);

  { AND and &, short circuit }
{$b-}
  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if (tmacbool_ftrue and tmacbool_ffalse) then
    halt(21);
   if not(tmacbool_ftruecalled) then
     halt(211);
   if not(tmacbool_ffalsecalled) then
     halt(22);

  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if (tmacbool_ffalse and tmacbool_ftrue) then
    halt(23);
  if not(tmacbool_ffalsecalled) then
    halt(24);
  if (tmacbool_ftruecalled) then
    halt(25);

  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if (tmacbool_ftrue & tmacbool_ffalse) then
    halt(206);
  if not(tmacbool_ftruecalled) then
    halt(26);
  if not(tmacbool_ffalsecalled) then
    halt(27);

  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if (tmacbool_ffalse & tmacbool_ftrue) then
    halt(28);
  if not(tmacbool_ffalsecalled) then
    halt(29);
  if (tmacbool_ftruecalled) then
    halt(30);


  { AND and &, full evaluation }
{$b+}
  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if (tmacbool_ftrue and tmacbool_ffalse) then
    halt(31);
   if not(tmacbool_ftruecalled) then
     halt(111);
   if not(tmacbool_ffalsecalled) then
     halt(32);

  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if (tmacbool_ffalse and tmacbool_ftrue) then
    halt(33);
  if not(tmacbool_ffalsecalled) then
    halt(34);
  if not(tmacbool_ftruecalled) then
    halt(35);

  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if (tmacbool_ftrue & tmacbool_ffalse) then
    halt(133);
  if not(tmacbool_ftruecalled) then
    halt(36);
  if not(tmacbool_ffalsecalled) then
    halt(37);

  tmacbool_ffalsecalled := false;
  tmacbool_ftruecalled := false;
  if (tmacbool_ffalse & tmacbool_ftrue) then
    halt(38);
  if not(tmacbool_ffalsecalled) then
    halt(39);
  if (tmacbool_ftruecalled) then
    halt(40);
end;
{$pop}

{ Case tmaclocalprocparam1.pas }
{$push}

begin
	tmaclocalprocparam1_Global;

	if tmaclocalprocparam1_failed then
		writeln('Failed')
	else
		writeln('Succeeded');

   {$IFC UNDEFINED THINK_Pascal}
	if tmaclocalprocparam1_failed then
		Halt(1);
   {$ENDC}
end;
{$pop}

{ Case tmaclocalprocparam1a.pas }
{$push}

begin
	tmaclocalprocparam1a_Global;

	if tmaclocalprocparam1a_failed then
		writeln('Failed')
	else
		writeln('Succeeded');

   {$IFC UNDEFINED THINK_Pascal}
	if tmaclocalprocparam1a_failed then
		Halt(1);
   {$ENDC}
end;
{$pop}

{ Case tmacnonlocalexit1.pas }
{$push}

begin
	tmacnonlocalexit1_failed := false;

	tmacnonlocalexit1_Global;

	if tmacnonlocalexit1_failed then
		writeln('Failed')
	else
		writeln('Succeeded');

  {$IFC NOT UNDEFINED FPC}
	if tmacnonlocalexit1_failed then
		Halt(1);
  {$ENDC}
end;
{$pop}

{ Case tmacpas2.pas }
{$push}

begin
  tmacpas2_a := true;
  tmacpas2_b := true;
  tmacpas2_c := false;

  {** Test & and | as alias for AND and OR **}
  if not (tmacpas2_a & tmacpas2_b) then
    tmacpas2_success:= false;
  if not (tmacpas2_c | tmacpas2_b) then
    tmacpas2_success:= false;

  {** Test that Ord() can take pointer values **}
  tmacpas2_p:= pointer(4711);
  tmacpas2_l:= Ord(tmacpas2_p);
  if tmacpas2_l <> 4711 then
    tmacpas2_success:= false;

  {** Test cycle and leave **}
  tmacpas2_i:= 0;
  while true do
    begin
      tmacpas2_i:= tmacpas2_i+1;
      if tmacpas2_i = 1 then
        Cycle;
      Leave;
    end;
  if tmacpas2_i<> 2 then
    tmacpas2_success:= false;

  {** Does literal four char codes work**}
  {Both directly and indirectly}
  tmacpas2_TestFourCharCode('FPas');
  tmacpas2_TestFourCharCode(tmacpas2_myFCCconst);

  if tmacpas2_success then
    Writeln('Whole test succeeded')
  else
    begin
      Writeln('Whole test failed');
      halt(1);
    end;
end;
{$pop}

end.
