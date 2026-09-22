{ %target=darwin }
{ %cpu=x86_64,arm}

{ %norun }

{$mode delphi}{$modeswitch objectivec1}

var
  o: id;
begin
  o.description;
end.
