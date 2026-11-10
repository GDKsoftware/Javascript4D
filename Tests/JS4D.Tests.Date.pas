unit JS4D.Tests.Date;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TDateTests = class
  private
    FEngine: TJSEngine;

    function EvaluateNumber(const Script: string): Double;
    function EvaluateText(const Script: string): string;
    function EvaluateBoolean(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('EpochDay', 'new Date(0).getUTCDay()|4', '|')]
    [TestCase('LeapDay', 'new Date(Date.UTC(2000, 1, 29)).getUTCDate()|29', '|')]
    [TestCase('YearBeforeEpoch', 'new Date(-1).getUTCFullYear()|1969', '|')]
    [TestCase('MonthBeforeEpoch', 'new Date(-1).getUTCMonth()|11', '|')]
    [TestCase('HoursBeforeEpoch', 'new Date(-1).getUTCHours()|23', '|')]
    [TestCase('MillisecondsBeforeEpoch', 'new Date(-1).getUTCMilliseconds()|999', '|')]
    [TestCase('LargeYear', 'new Date(8.64e15).getUTCFullYear()|275760', '|')]
    [TestCase('NegativeYear', 'new Date(-8.64e15).getUTCFullYear()|-271821', '|')]
    [TestCase('GetTime', 'new Date(123456789012).getTime()|123456789012', '|')]
    [TestCase('ValueOf', 'new Date(123456789012).valueOf()|123456789012', '|')]
    procedure Getter_ReturnsComponent(const Script: string; const Expected: Double);

    [Test]
    [TestCase('Year', 'new Date(NaN).getUTCFullYear()', '|')]
    [TestCase('LocalMonth', 'new Date(NaN).getMonth()', '|')]
    [TestCase('TimezoneOffset', 'new Date(NaN).getTimezoneOffset()', '|')]
    [TestCase('Time', 'new Date(NaN).getTime()', '|')]
    [TestCase('UtcAboveLimit', 'Date.UTC(275760, 8, 13, 0, 0, 0, 1)', '|')]
    [TestCase('UtcNoArguments', 'Date.UTC()', '|')]
    [TestCase('ConstructorAboveLimit', 'new Date(8.64e15 + 1).getTime()', '|')]
    [TestCase('ParseGarbage', 'Date.parse("not a date")', '|')]
    [TestCase('ParseMonthTooLarge', 'Date.parse("2000-13-01")', '|')]
    [TestCase('ParseDayTooLarge', 'Date.parse("2000-02-30")', '|')]
    [TestCase('ParseNegativeZeroYear', 'Date.parse("-000000-01-01T00:00:00Z")', '|')]
    [TestCase('ParseHourAboveLimit', 'Date.parse("2000-01-01T24:00:01Z")', '|')]
    procedure Expression_IsNaN(const Script: string);

    [Test]
    [TestCase('Epoch', 'Date.UTC(1970, 0, 1)|0', '|')]
    [TestCase('TwoDigitYear', 'Date.UTC(99, 1) - Date.UTC(1999, 1)|0', '|')]
    [TestCase('OnlyYear', 'Date.UTC(1970) - Date.UTC(1970, 0, 1)|0', '|')]
    [TestCase('MonthOverflow', 'Date.UTC(1970, 12) - Date.UTC(1971, 0)|0', '|')]
    [TestCase('FractionalTimeValue', 'new Date(1.9).getTime()|1', '|')]
    [TestCase('NegativeFractionalTimeValue', 'new Date(-1.9).getTime()|-1', '|')]
    [TestCase('UpperLimit', 'new Date(8.64e15).getTime()|8.64e15', '|')]
    [TestCase('DateObjectCopy', 'new Date(new Date(77)).getTime()|77', '|')]
    [TestCase('ValueOfObject', 'new Date({ valueOf: function () { return 5; } }).getTime()|5', '|')]
    [TestCase('IsoDateOnlyIsUtc', 'Date.parse("1970-01-02")|86400000', '|')]
    [TestCase('IsoWithOffset', 'Date.parse("1970-01-01T01:00:00+01:00")|0', '|')]
    [TestCase('IsoWithFraction', 'Date.parse("1970-01-01T00:00:00.123Z")|123', '|')]
    [TestCase('IsoYearMonth', 'Date.parse("1970-02")|2678400000', '|')]
    [TestCase('IsoExtendedYear', 'Date.parse("+000000-01-01T00:00:00Z")|-62167219200000', '|')]
    [TestCase('IsoEndOfDay', 'Date.parse("1970-01-01T24:00:00Z")|86400000', '|')]
    [TestCase('LegacyUtcString', 'Date.parse("Thu, 01 Jan 1970 00:00:01 GMT")|1000', '|')]
    [TestCase('LegacyOffsetString', 'Date.parse("Thu Jan 01 1970 01:00:00 GMT+0100")|0', '|')]
    procedure Expression_ReturnsNumber(const Script: string; const Expected: Double);

    [Test]
    [TestCase('ToStringRoundTrip', 'var d = new Date(2024, 4, 17, 8, 9, 10); Date.parse(d.toString()) === d.getTime()', '|')]
    [TestCase('ToUtcStringRoundTrip', 'var d = new Date(1e12); Date.parse(d.toUTCString()) === d.getTime()', '|')]
    [TestCase('ToIsoStringRoundTrip', 'var d = new Date(1e12 + 5); Date.parse(d.toISOString()) === d.getTime()', '|')]
    [TestCase('LocalComponents', 'var d = new Date(2024, 0, 15, 10, 30, 45, 123); d.getFullYear() === 2024 && d.getMonth() === 0 && d.getDate() === 15 && d.getHours() === 10 && d.getMinutes() === 30 && d.getSeconds() === 45 && d.getMilliseconds() === 123', '|')]
    [TestCase('LocalDateTimeParse', 'new Date("2000-01-01T00:00:00").getHours() === 0', '|')]
    [TestCase('TimezoneOffsetMatchesLocalTime', 'var d = new Date(1e12); (d.getTimezoneOffset() * 60000) === (Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), d.getUTCHours(), d.getUTCMinutes()) - Date.UTC(d.getFullYear(), d.getMonth(), d.getDate(), d.getHours(), d.getMinutes()))', '|')]
    [TestCase('CalledAsFunctionReturnsString', 'typeof Date() === "string"', '|')]
    [TestCase('ConstructedIsDate', 'Object.prototype.toString.call(new Date(0)) === "[object Date]"', '|')]
    [TestCase('BoundConstructorBuildsDate', 'var bound = Function.prototype.bind.apply(Date, [null, 1957, 4, 27]); Object.prototype.toString.call(new bound()) === "[object Date]"', '|')]
    [TestCase('ConstructedInstanceOf', 'new Date(0) instanceof Date', '|')]
    [TestCase('PrototypeConstructor', 'Date.prototype.constructor === Date', '|')]
    [TestCase('GmtStringIsUtcString', 'Date.prototype.toGMTString === Date.prototype.toUTCString', '|')]
    [TestCase('PrototypeIsNotADate', 'try { Date.prototype.getTime(); false; } catch (e) { e instanceof TypeError; }', '|')]
    [TestCase('GetterOnForeignObject', 'try { Date.prototype.getTime.call({}); false; } catch (e) { e instanceof TypeError; }', '|')]
    [TestCase('SetterOnForeignObject', 'try { Date.prototype.setUTCHours.call({}, 1); false; } catch (e) { e instanceof TypeError; }', '|')]
    [TestCase('IsoStringOfInvalidDate', 'try { new Date(NaN).toISOString(); false; } catch (e) { e instanceof RangeError; }', '|')]
    [TestCase('MethodIsNotEnumerable', 'var count = 0; for (var key in Date.prototype) { count++; } count === 0', '|')]
    [TestCase('MethodIsNotAConstructor', 'try { new Date.prototype.getTime(); false; } catch (e) { e instanceof TypeError; }', '|')]
    [TestCase('ToJsonOfInvalidDateIsNull', 'new Date(NaN).toJSON() === null', '|')]
    [TestCase('ToJsonUsesToIsoString', 'Date.prototype.toJSON.call({ valueOf: function () { return 1; }, toISOString: function () { return "x"; } }) === "x"', '|')]
    [TestCase('SetTimeClipsToNaN', 'var d = new Date(0); d.setTime(8.64e15 + 1); isNaN(d.getTime())', '|')]
    [TestCase('SetTimeReturnsValue', 'new Date(0).setTime(42) === 42', '|')]
    [TestCase('SetUtcMillisecondsOfInvalidDate', 'var d = new Date(NaN); d.setUTCMilliseconds(5); isNaN(d.getTime())', '|')]
    procedure Expression_IsTrue(const Script: string);

    [Test]
    [TestCase('Epoch', 'new Date(0).toISOString()|1970-01-01T00:00:00.000Z', '|')]
    [TestCase('Milliseconds', 'new Date(1).toISOString()|1970-01-01T00:00:00.001Z', '|')]
    [TestCase('NegativeYear', 'new Date(-62198755200000).toISOString()|-000001-01-01T00:00:00.000Z', '|')]
    [TestCase('ExtendedYear', 'new Date(8.64e15).toISOString()|+275760-09-13T00:00:00.000Z', '|')]
    [TestCase('YearZero', 'new Date(-62167219200000).toISOString()|0000-01-01T00:00:00.000Z', '|')]
    [TestCase('UtcString', 'new Date(0).toUTCString()|Thu, 01 Jan 1970 00:00:00 GMT', '|')]
    [TestCase('UtcStringLaterDate', 'new Date(Date.UTC(2024, 11, 25, 13, 5, 9)).toUTCString()|Wed, 25 Dec 2024 13:05:09 GMT', '|')]
    [TestCase('InvalidToString', 'new Date(NaN).toString()|Invalid Date', '|')]
    [TestCase('InvalidDateString', 'new Date(NaN).toDateString()|Invalid Date', '|')]
    [TestCase('InvalidTimeString', 'new Date(NaN).toTimeString()|Invalid Date', '|')]
    [TestCase('InvalidUtcString', 'new Date(NaN).toUTCString()|Invalid Date', '|')]
    [TestCase('ToJson', 'new Date(0).toJSON()|1970-01-01T00:00:00.000Z', '|')]
    [TestCase('DateStringLayout', 'new Date(2024, 0, 5).toDateString()|Fri Jan 05 2024', '|')]
    [TestCase('TimeStringLayout', 'new Date(2024, 0, 5, 7, 8, 9).toTimeString().substring(0, 8)|07:08:09', '|')]
    procedure Expression_ReturnsText(const Script: string; const Expected: string);

    [Test]
    [TestCase('SetUtcMonthOverflow', 'var d = new Date(Date.UTC(2000, 0, 31)); d.setUTCMonth(13); d.toISOString()|2001-03-03T00:00:00.000Z', '|')]
    [TestCase('SetUtcHoursWithAllArguments', 'var d = new Date(0); d.setUTCHours(1, 2, 3, 4); d.toISOString()|1970-01-01T01:02:03.004Z', '|')]
    [TestCase('SetUtcMinutesKeepsSeconds', 'var d = new Date(Date.UTC(2000, 0, 1, 1, 1, 1, 1)); d.setUTCMinutes(30); d.toISOString()|2000-01-01T01:30:01.001Z', '|')]
    [TestCase('SetUtcSecondsWithMilliseconds', 'var d = new Date(0); d.setUTCSeconds(5, 6); d.toISOString()|1970-01-01T00:00:05.006Z', '|')]
    [TestCase('SetUtcDateNegative', 'var d = new Date(Date.UTC(2000, 1, 1)); d.setUTCDate(0); d.toISOString()|2000-01-31T00:00:00.000Z', '|')]
    [TestCase('SetUtcFullYearOfInvalidDate', 'var d = new Date(NaN); d.setUTCFullYear(2001); d.toISOString()|2001-01-01T00:00:00.000Z', '|')]
    [TestCase('SetUtcFullYearWithMonthAndDate', 'var d = new Date(0); d.setUTCFullYear(2001, 5, 7); d.toISOString()|2001-06-07T00:00:00.000Z', '|')]
    [TestCase('SetUtcMillisecondsIgnoresExtraArguments', 'var d = new Date(0); d.setUTCMilliseconds(5, 99, 99); d.toISOString()|1970-01-01T00:00:00.005Z', '|')]
    [TestCase('SetLocalHours', 'var d = new Date(2000, 0, 1, 1); d.setHours(5, 6); d.getHours() + ":" + d.getMinutes()|5:6', '|')]
    [TestCase('SetLocalMonth', 'var d = new Date(2000, 0, 31); d.setMonth(1); d.getMonth() + "-" + d.getDate()|2-2', '|')]
    [TestCase('SetYearTwoDigits', 'var d = new Date(2000, 5, 1); d.setYear(99); d.getFullYear()|1999', '|')]
    [TestCase('GetYear', 'new Date(1999, 5, 1).getYear()|99', '|')]
    procedure Setter_UpdatesTimeValue(const Script: string; const Expected: string);

    [Test]
    [TestCase('Date', 'Date|7', '|')]
    [TestCase('UTC', 'Date.UTC|7', '|')]
    [TestCase('Parse', 'Date.parse|1', '|')]
    [TestCase('Now', 'Date.now|0', '|')]
    [TestCase('GetTime', 'Date.prototype.getTime|0', '|')]
    [TestCase('SetTime', 'Date.prototype.setTime|1', '|')]
    [TestCase('SetMilliseconds', 'Date.prototype.setMilliseconds|1', '|')]
    [TestCase('SetUTCSeconds', 'Date.prototype.setUTCSeconds|2', '|')]
    [TestCase('SetMinutes', 'Date.prototype.setMinutes|3', '|')]
    [TestCase('SetHours', 'Date.prototype.setHours|4', '|')]
    [TestCase('SetDate', 'Date.prototype.setDate|1', '|')]
    [TestCase('SetMonth', 'Date.prototype.setMonth|2', '|')]
    [TestCase('SetFullYear', 'Date.prototype.setFullYear|3', '|')]
    [TestCase('ToJSON', 'Date.prototype.toJSON|1', '|')]
    [TestCase('ToISOString', 'Date.prototype.toISOString|0', '|')]
    procedure FunctionLength_MatchesSpecification(const FunctionExpression: string; const Expected: Integer);

    [Test]
    procedure Length_OfBuiltinMethod_IsReadOnlyAndNotEnumerable;
  end;

implementation

procedure TDateTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TDateTests.TearDown;
begin
  FEngine.Free;
end;

function TDateTests.EvaluateNumber(const Script: string): Double;
begin
  Result := FEngine.Evaluate(Script).ToNumber;
end;

function TDateTests.EvaluateText(const Script: string): string;
begin
  Result := FEngine.Evaluate(Script).ToString;
end;

function TDateTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).ToBoolean;
end;

procedure TDateTests.Getter_ReturnsComponent(const Script: string; const Expected: Double);
begin
  Assert.AreEqual(Expected, EvaluateNumber(Script));
end;

procedure TDateTests.Expression_IsNaN(const Script: string);
begin
  Assert.IsTrue(FEngine.Evaluate(Script).IsNaN);
end;

procedure TDateTests.Expression_ReturnsNumber(const Script: string; const Expected: Double);
begin
  Assert.AreEqual(Expected, EvaluateNumber(Script));
end;

procedure TDateTests.Expression_IsTrue(const Script: string);
begin
  Assert.IsTrue(EvaluateBoolean(Script), Script);
end;

procedure TDateTests.Expression_ReturnsText(const Script: string; const Expected: string);
begin
  Assert.AreEqual(Expected, EvaluateText(Script));
end;

procedure TDateTests.Setter_UpdatesTimeValue(const Script: string; const Expected: string);
begin
  Assert.AreEqual(Expected, EvaluateText(Script));
end;

procedure TDateTests.FunctionLength_MatchesSpecification(const FunctionExpression: string; const Expected: Integer);
begin
  Assert.AreEqual(Double(Expected), EvaluateNumber(FunctionExpression + '.length'));
end;

procedure TDateTests.Length_OfBuiltinMethod_IsReadOnlyAndNotEnumerable;
begin
  const Script = 'var f = Date.prototype.getTime; var d = Object.getOwnPropertyDescriptor(f, "length"); ' +
                 '!d.writable && !d.enumerable && d.configurable';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

end.
