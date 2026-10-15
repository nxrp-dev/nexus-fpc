{ MacPas object inheritance, With lookup, object results and explicit disposal. }
{ Original case IDs and variable scopes are retained below. }

{$mode macpas}

{ Case tb0511.pas }
{$push}
{ original: peter5a.pas from the GNU Pascal testsuite }

{ Mac Pascal objects }

        type
                tb0511_str = String[100];
                tb0511_baseobject = object
                        tb0511_v1: tb0511_str;
                        function tb0511_m1: tb0511_str;
                        function tb0511_m2: tb0511_str;
                end;
                tb0511_superobject = object(tb0511_baseobject)
                        tb0511_v2: tb0511_str;
                        tb0511_v3: tb0511_str;
                        function tb0511_m1: tb0511_str; override;
                        function tb0511_m2: tb0511_str; override;
                        function tb0511_m3: tb0511_str;
                end;

        var
                tb0511_good: Boolean;

        function tb0511_baseobject.tb0511_m1: tb0511_str;
        begin
                return 'BaseObject.' + tb0511_v1;
        end;

        function tb0511_baseobject.tb0511_m2: tb0511_str;
        begin
                return 'BaseObject.nov2';
        end;

        function tb0511_superobject.tb0511_m1: tb0511_str;
        begin
                return 'SuperObject.' + (inherited tb0511_m1) + '.' + tb0511_v1;
        end;

        function tb0511_superobject.tb0511_m2: tb0511_str;
        begin
                return 'SuperObject.' + (inherited tb0511_m2) + '.' + tb0511_v2;
        end;

        function tb0511_superobject.tb0511_m3: tb0511_str;
        begin
                return 'SuperObject.' + tb0511_v3;
        end;

        procedure tb0511_checkequal( const param, s1, s2: tb0511_str );
        begin
                if s1 <> s2 then begin
                        tb0511_good := false;
                        WriteLn( 'Failed: ', param, ' = ', s1, ' is not equal to ', s2 );
                end;
        end;

        var
                tb0511_base: tb0511_baseobject;
                tb0511_super: tb0511_superobject;
                tb0511_reallysuper: tb0511_baseobject;
{$pop}

{ Case tb0512.pas }
{$push}
{ original: peter5b.pas from the GNU Pascal testsuite }

{ Mac Pascal objects }

        type
                tb0512_str = String[100];
                tb0512_baseobject = object
                        tb0512_v1: tb0512_str;
                        function tb0512_m1: tb0512_str;
                        function tb0512_m2: tb0512_str;
                end;
                tb0512_superobject = object(tb0512_baseobject)
                        tb0512_v2: tb0512_str;
                        tb0512_v3: tb0512_str;
                        function tb0512_m1: tb0512_str; override;
                        function tb0512_m2: tb0512_str; override;
                        function tb0512_m3: tb0512_str;
                end;

        var
                tb0512_good: Boolean;

        function tb0512_baseobject.tb0512_m1: tb0512_str;
        begin
                return 'BaseObject.' + tb0512_v1;
        end;

        function tb0512_baseobject.tb0512_m2: tb0512_str;
        begin
                return 'BaseObject.nov2';
        end;

        function tb0512_superobject.tb0512_m1: tb0512_str;
        begin
                return 'SuperObject.' + (inherited tb0512_m1) + '.' + tb0512_v1;
        end;

        function tb0512_superobject.tb0512_m2: tb0512_str;
        begin
                return 'SuperObject.' + (inherited tb0512_m2) + '.' + tb0512_v2;
        end;

        function tb0512_superobject.tb0512_m3: tb0512_str;
        begin
                return 'SuperObject.' + tb0512_v3;
        end;

        procedure tb0512_checkequal( const param, s1, s2: tb0512_str );
        begin
                if s1 <> s2 then begin
                        tb0512_good := false;
                        WriteLn( 'Failed: ', param, ' = ', s1, ' is not equal to ', s2 );
                end;
        end;

        var
                tb0512_base: tb0512_baseobject;
                tb0512_super: tb0512_superobject;
                tb0512_reallysuper: tb0512_baseobject;
{$pop}

{ Case tb0513.pas }
{$push}
{ original: peter5c.pas from the GNU Pascal testsuite }

   type
     tb0513_objecta = object
       procedure tb0513_doit;
     end;
     tb0513_objectb = object
       tb0513_obj: tb0513_objecta;
       function tb0513_geta: tb0513_objecta;
     end;

var
   tb0513_ok: boolean;

   procedure tb0513_objecta.tb0513_doit;
   begin
     WriteLn( 'OK' );
     tb0513_ok := true;
   end;

   function tb0513_objectb.tb0513_geta: tb0513_objecta;
   begin
     return tb0513_obj;
   end;

var
   tb0513_a: tb0513_objecta;
   tb0513_b: tb0513_objectb;
{$pop}

{ Case tb0514.pas }
{$push}
{ original: peter5d.pas from the GNU Pascal testsuite }

        type
                tb0514_obj = object
                        procedure tb0514_destroy;
                        procedure tb0514_free;
                end;

        procedure tb0514_obj.tb0514_destroy;
        begin
                dispose( self );
        end;

        procedure tb0514_obj.tb0514_free;
        begin
           writeln('must not be called');
           halt(1);
        end;

        var
                tb0514_o: tb0514_obj;
{$pop}

begin
  { Case tb0511.pas }
  {$push}
begin
        New(tb0511_base);
        tb0511_base.tb0511_v1 := 'basev1';

        New(tb0511_super);
        tb0511_super.tb0511_v1 := 'superv1';
        tb0511_super.tb0511_v2 := 'superv2';
        tb0511_super.tb0511_v3 := 'superv3';

        tb0511_reallysuper := tb0511_super; { reference copy only! }

        tb0511_good := true;

        tb0511_checkequal( 'base.m1', tb0511_base.tb0511_m1, 'BaseObject.basev1' );
        tb0511_checkequal( 'base.m2', tb0511_base.tb0511_m2, 'BaseObject.nov2' );

        tb0511_checkequal( 'super.m1', tb0511_super.tb0511_m1, 'SuperObject.BaseObject.superv1.superv1' );
        tb0511_checkequal( 'super.m2', tb0511_super.tb0511_m2, 'SuperObject.BaseObject.nov2.superv2' );
        tb0511_checkequal( 'super.m3', tb0511_super.tb0511_m3, 'SuperObject.superv3' );

        tb0511_checkequal( 'reallysuper.m1', tb0511_reallysuper.tb0511_m1, 'SuperObject.BaseObject.superv1.superv1' );
        tb0511_checkequal( 'reallysuper.m2', tb0511_reallysuper.tb0511_m2, 'SuperObject.BaseObject.nov2.superv2' );

        if tb0511_good then begin
                WriteLn( 'OK' );
        end
        else begin
                halt(1);
        end;

        Dispose( tb0511_base );
        Dispose( tb0511_super );
end;
  {$pop}

  { Case tb0512.pas }
  {$push}
begin
        New(tb0512_base);
        tb0512_base.tb0512_v1 := 'basev1';

        New(tb0512_super);
        with tb0512_super do begin
          tb0512_v1 := 'superv1';
          tb0512_v2 := 'superv2';
          tb0512_v3 := 'superv3';
        end;

        tb0512_reallysuper := tb0512_super; { reference copy only! }

        tb0512_good := true;

        with tb0512_base do begin
        tb0512_checkequal( 'base.m1', tb0512_m1, 'BaseObject.basev1' );
        tb0512_checkequal( 'base.m2', tb0512_m2, 'BaseObject.nov2' );
        end;
        tb0512_checkequal( 'super.m1', tb0512_super.tb0512_m1, 'SuperObject.BaseObject.superv1.superv1' );
        tb0512_checkequal( 'super.m2', tb0512_super.tb0512_m2, 'SuperObject.BaseObject.nov2.superv2' );
        tb0512_checkequal( 'super.m3', tb0512_super.tb0512_m3, 'SuperObject.superv3' );

        tb0512_checkequal( 'reallysuper.m1', tb0512_reallysuper.tb0512_m1, 'SuperObject.BaseObject.superv1.superv1' );
        tb0512_checkequal( 'reallysuper.m2', tb0512_reallysuper.tb0512_m2, 'SuperObject.BaseObject.nov2.superv2' );

        if tb0512_good then begin
                WriteLn( 'OK' );
        end else begin
                halt(1)
        end;

        Dispose( tb0512_base );
        Dispose( tb0512_super );
end;
  {$pop}

  { Case tb0513.pas }
  {$push}
begin
   New(tb0513_a);
   New(tb0513_b);
   tb0513_b.tb0513_obj := tb0513_a;
   tb0513_b.tb0513_geta.tb0513_doit;
   if not tb0513_ok then
     halt(1);
end;
  {$pop}

  { Case tb0514.pas }
  {$push}
begin
        new(tb0514_o);
        tb0514_o.tb0514_destroy;
        WriteLn( 'OK' );
end;
  {$pop}

end.
