# FCL JSON code review

Review date: 2026-10-15. Reviewed revision:
`5c10feaeb7d237a3658bee502f329e5765c1a1a7`.

The following eleven findings are open. They were traced through the source
during static review; runtime reproductions and test execution remain pending.
The suggested corrections have not been applied.

## 1 P1 Parsing duplicate containers uses freed memory

Source: [jsonparser.pas:154](src/jsonparser.pas#L154),
[jsonparser.pas:214](src/jsonparser.pas#L214).

With `joIgnoreDuplicates`, input such as `{"a":1,"a":{"x":2}}` frees the
second value in `NewValue`, but returns its pointer. `StartObject` then pushes
that freed object as the active parse structure. Duplicate arrays follow the
same path. Subsequent parsing accesses freed memory.

Suggested correction: consume ignored containers without using freed storage,
either retaining them until parsing finishes or skipping their contents safely.
Regression coverage should include duplicate objects and arrays and verify that
the first member remains intact. The existing duplicate-key test covers only
scalar values.

## 2 P1 Changing a dirty configuration filename overwrites the destination

Source: [jsonconf.pas:716](src/jsonconf.pas#L716),
[jsonconf.pas:181](src/jsonconf.pas#L181).

`DoSetFilename` assigns `FFilename` before calling `Flush`. Changing the filename
on a modified configuration therefore writes its current contents over the new
destination before `LoadFromFile` reads it. An existing destination configuration
loses its contents.

Suggested correction: flush against the old filename before switching the
active file. Verify with two existing files and unsaved changes in the first;
switching files must not overwrite the second.

## 3 P1 JSON INI writes can disappear

Source: [jsonini.pas:137](src/jsonini.pas#L137),
[jsonini.pas:88](src/jsonini.pas#L88),
[jsonini.pas:204](src/jsonini.pas#L204).

`WriteString`, `WriteInteger`, and the other setters call `SetKeyData`, which
changes memory and sets `FDirty` without calling `MaybeUpdateFile`.
`SetCacheUpdates` also never assigns `FCacheUpdates`. Consequently,
`CacheUpdates := False` does not provide write-through, and destruction discards
changes unless an explicit save or another operation has already written them.

Suggested correction: restore the cache setting and connect the write methods
to the update path. The existing `TestWriteString` and related tests expect
write-through after disabling caching; verify the resulting file by reopening it.

## 4 P2 Malformed JSON values are silently ignored

Source: [jsonreader.pas:248](src/jsonreader.pas#L248).

`DoParse` has no rejection case for an unexpected colon; its default branch does
nothing. Inputs such as `[:]` and `{"a"::}` therefore produce empty containers
instead of syntax errors, including with `joStrict`.

Suggested correction: reject every token that cannot begin a value. Add negative
tests for unexpected colons in arrays and object values in both parser modes.

## 5 P2 Strict strings accept some raw control characters

Source: [jsonscanner.pas:614](src/jsonscanner.pas#L614).

The scanner checks `Sp^ < #20`, where `#20` is decimal 20. Raw character codes
20 through 31 therefore pass through strict string parsing, even though they
require escaping in JSON.

Suggested correction: check the full control-character range below decimal 32.
Verify rejection of every unescaped control character and acceptance of its
corresponding valid escape.

## 6 P2 Destroying an unused data writer accesses an empty stack

Source: [jsonwriter.pas:323](src/jsonwriter.pas#L323).

`TJSONDataWriter.Create.Free` reaches `FreeAndNil(FStack[0])` before any write
has allocated the dynamic array. Empty writer destruction can consequently
raise an access violation or range error, including during exception cleanup.

Suggested correction: check whether the stack has storage before accessing its
root. Verify destruction before the first write and after extracting the data.

## 7 P2 The writer corrupts large unsigned integers

Source: [jsonwriter.pas:174](src/jsonwriter.pas#L174),
[fpjson.pas:1380](src/fpjson.pas#L1380).

The `ntQWord` writer branch reads `AsInt64`. Values above `High(Int64)` become
negative with range checking disabled; for example, `High(QWord)` is written as
`-1`. Range checking can instead raise an exception.

Suggested correction: provide an unsigned writer path without narrowing through
`Int64`. Verify exact round trips at `High(Int64)`, `High(Int64) + 1`, and
`High(QWord)`.

## 8 P2 Integer differences fail while formatting the diagnostic

Source: [jsoncomparer.pas:154](src/jsoncomparer.pas#L154).

The integer difference message requires two integer arguments. Each integer
branch instead supplies one Boolean expression. Comparing unequal integer
values therefore raises a formatting exception instead of reporting the
expected and actual values.

Suggested correction: supply both numeric values using the appropriate signed
or unsigned accessors. Verify unequal Integer, Int64, and QWord comparisons.

## 9 P2 RTTI restoration corrupts non ASCII characters

Source: [fpjsonrtti.pas:566](src/fpjsonrtti.pas#L566),
[fpjsonrtti.pas:587](src/fpjsonrtti.pas#L587).

The `tkWChar` and `tkUChar` branches take the first byte of a UTF-8 string rather
than decoding the character. For example, U+00E9 is restored as character code
`$C3`, its first UTF-8 byte.

Suggested correction: decode the character according to the target property
type before assigning its ordinal value. Verify non-ASCII character round trips.

## 10 P2 YAML conversion changes string values into other types

Source: [json2yaml.pas:77](src/json2yaml.pas#L77).

Strings are emitted without quoting or escaping. For example, JSON
`{"s":"true"}` becomes YAML `s: true`, changing the value from a string to a
Boolean. Embedded newlines can also change the document structure.

Suggested correction: quote and escape string scalars and property names as
needed. Verify that conversion preserves strings resembling Booleans, numbers,
or null, as well as strings containing newlines and YAML punctuation.

## 11 P2 Pascal generation reads an uninitialized flag

Source: [fpjsontopas.pas:558](src/fpjsontopas.pas#L558),
[fpjsontopas.pas:608](src/fpjsontopas.pas#L608).

`GenerateObjectDeclaration` initializes `HaveObj` but not `HaveComplexArr`.
The latter is only assigned when a complex array is encountered. For simpler
objects, its uninitialized value can cause a destructor declaration to be
emitted without the corresponding implementation.

Suggested correction: initialize `HaveComplexArr` before examining the members.
Verify that generated classes containing only scalar properties compile
consistently, alongside classes containing complex arrays.
