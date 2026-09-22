{ %target=darwin }
{ %cpu=x86_64,arm,aarch64}
{ %norun }
{$modeswitch objectivec1}

type
 MyClass = objcclass (NSObject)
   _rec: record
     mask: MyClass;
   end;
 end;

begin
end.
