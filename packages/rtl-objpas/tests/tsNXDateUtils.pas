unit tsNXDateUtils;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterDateUtilsTests(ARegistry: TNXTestRegistry);
implementation
uses SysUtils, DateUtils, obNXTestContext, obNXTestSuite;
procedure DateIgnoresTime(AContext: TNXTestContext);
var lDayOfYear, lDate: TDateTime;
begin
  lDayOfYear := EncodeDateDay(2023, 1) + 0.6;
  lDate := EncodeDate(2023, 1, 1) + 0.3;
  AContext.AssertTrue(DateOf(lDayOfYear) = DateOf(lDate),
    'DateOf ignores fractional times for day-of-year and calendar dates');
end;
procedure RegisterDateUtilsTests(ARegistry: TNXTestRegistry);
begin
  ARegistry.AddSuite('RTL.DateUtils').AddTest('DateIgnoresTime', @DateIgnoresTime, 'date-time');
end;
end.
