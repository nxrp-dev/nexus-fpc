# Apple binding cleanup and replacement register

Started: 2026-10-10. Scope: NexusFPC's `packages/univint` and `packages/cocoaint`.

Apple targets supported by this cleanup are 64-bit Intel and ARM64. Remove
nonfunctional APIs and declarations exclusive to 32-bit processes first. A
32-bit integer field in a usable 64-bit API is not a 32-bit-only API. Preserve
shared types, constants, and functioning 64-bit declarations until their
consumers have been checked. MACPAS remains required by the surviving bindings.

This restriction applies to Apple targets. NexusFPC also supports 32-bit
i386 Windows and Linux; see the supported-target table in
[the mission statement](nexusfpc-mission-statement.md).

“Bindings present” below means the named declarations exist in this checkout;
it does not claim coverage of the entire current Apple SDK or a completed
application migration. Replacement implementation work is tracked separately.

## First removal batch

Status: first removal batch implemented, compile-verified and committed as
`e09f5bfa`. The follow-up cleanup below is implemented and uncommitted.

| Retired functionality / source | Replacement reference | Bindings we already carry | Implementation still needed |
| --- | --- | --- | --- |
| QTKit playback, capture, editing and export: `cocoaint/src/QTKit.pas`, `DefinedClassesQTKit.pas`, `qtkit/` | [Apple's QTKit to AVFoundation migration guide](https://developer.apple.com/library/archive/technotes/tn2300/_index.html). QTKit became nonfunctional in [macOS 10.15](https://developer.apple.com/documentation/macos-release-notes/macos-catalina-10_15-release-notes). | `AVFoundation.pas`: `AVPlayer`, `AVCaptureSession`, `AVAssetReader`, `AVAssetWriter`, `AVAssetExportSession`; `AVKit.pas`: `AVPlayerView`. | No new basic replacement binding is required. Any application still using QTKit needs a functional migration, including playback/capture/export behavior and error handling. |
| QuickTime C entry points: 32-bit branches of `Movies`, `QuickTimeComponents`, `QuickTimeStreaming`, `QuickTimeMusic`, `QuickTimeVR`, `ImageCompression`, `ImageCodec`, `MediaHandlers`, `QTML`, related units | [QuickTime 64-bit restrictions](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/64bitPorting/HighLevelAPIs/HighLevelAPIs.html); use AVFoundation rather than the historical QTKit recommendation. | Same AVFoundation/AVKit bindings; Core Audio units for music/audio use cases. | Migrate consumers when found. Media-format constants and shared record declarations must be reviewed separately from removed executable APIs. |
| Carbon windows, menus, controls, HIView, dialogs, navigation, printing UI, color/font panels: 32-bit branches of `MacWindows`, `Menus`, `Controls`, `HI*`, `Dialogs`, `Navigation`, `PMApplication*`, `ColorPicker`, `FontPanel` | [Apple's Human Interface Toolbox migration guide](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/Carbon64BitGuide/HIToolboxChanges/HIToolboxChanges.html) | AppKit/CocoaAll: `NSWindow`, `NSView`, `NSControl`, `NSMenu`, `NSOpenPanel`, `NSSavePanel`, `NSPrintOperation`, `NSPrintPanel`, `NSColorPanel`, `NSFontPanel`. | UI consumers need Cocoa implementations. Retire the Carbon-only `controldemo` example instead of presenting it as supported. |
| QuickDraw drawing, classic fonts and ATSUI/MLTE text: 32-bit branches of `Quickdraw`, `QDOffscreen`, `Fonts`, `ATSUnicode*`, `MacTextEditor`, related units | [Apple's 64-bit migration overview](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/Carbon64BitGuide/PortingTo64Bit/PortingTo64Bit.html) | Core Graphics: `CGContext`, `CGImage`; Core Text: `CTFont`, `CTLine`, `CTFrame`, `CTFramesetter`; AppKit: `NSTextView`. | Drawing/text consumers need conversion. Retain any region/basic record APIs that remain available in 64-bit processes. |
| Other removed 32-bit service entry points: file/alias operations, display services, sound, clipboard, dates, dictionaries, language analysis, resource/code-fragment management | [Apple's service-by-service replacement reference](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/Carbon64BitGuide/OtherAPIChanges/OtherAPIChanges.html) | Replacement coverage and exceptions are recorded below as each service is checked. | No blanket replacement claim: some services require design changes or have no direct equivalent. |
| Cocoa 32-bit ABI branches in `cocoaint/src/*.pas` and included declarations | [Apple's Cocoa 64-bit transition guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Cocoa64BitGuide/64BitChangesCocoa/64BitChangesCocoa.html) | The existing 64-bit declarations in those same files. | None for the ABI selection itself. Keep the selected 64-bit sizes/layouts unchanged. |

Removed the associated QTKit namespace wrappers and build registrations, and
the obsolete AppKit `NSMovie` / `NSMovieView` wrappers. The remaining references
to QTMovie representations in ImageKit are string constants, not QTKit imports
or class declarations. Historical data-format constants are not automatically
executable API dependencies.

Three other AppKit wrappers had only forward declarations and pointer aliases
left after their 32-bit implementations were removed. Those empty wrappers and
their forwards were removed too:

| Removed class | Replacement | Existing binding / remaining work |
| --- | --- | --- |
| `NSMenuView` | AppKit `NSMenu` / `NSMenuItem` | Present in `cocoaint/src/appkit`; custom menu drawing requires an application rewrite. |
| `NSQuickDrawView` | `NSView` with Core Graphics drawing | Both present; port QuickDraw drawing operations. |
| `NSSimpleHorizontalTypesetter` | `NSTypesetter` / `NSATSTypesetter` | Both present in `cocoaint/src/appkit`; custom layout behavior needs migration. |

The source declarations themselves restricted these three class implementations
to non-LP64 targets. See the Cocoa transition reference above for the 64-bit
AppKit model. No consumers of these classes or the removed movie wrappers were
found in the searched Nexus Pascal packages/projects or FPC tests/packages.

## Service replacement coverage

This table expands the remaining 32-bit service removals. Paths are relative
to `packages/`; `univint/src/<name>.pas` and `cocoaint/src/<framework>/<name>.inc`
contain the checked declarations. Unless identified as a direct successor,
the replacement is a proposed implementation direction, not a signature-compatible
substitute. Existing bindings are evidence of local declarations, not evidence
that an entire replacement feature has been implemented.

Apple's [service transition reference](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/Carbon64BitGuide/OtherAPIChanges/OtherAPIChanges.html)
documents the 64-bit exclusions. That historical guide sometimes recommends
APIs which were themselves deprecated later; those are identified below.

| Removed service / units | Replacement reference or direction | Existing bindings | Work still needed |
| --- | --- | --- | --- |
| File, folder, alias and resource-file operations: `Files`, `Folders`, `Aliases`, `Resources` | [Foundation file management](https://developer.apple.com/documentation/foundation/filemanager), URL bookmarks and bundle resources | `NSFileManager`, `NSURL` bookmark creation/resolution in Foundation; `CFURL`, `CFBundle`. Surviving FSRef APIs remain. | Convert FSSpec/Pascal-string consumers and resource storage. FSRef is the historical transition, not the preferred new application design. |
| Display Manager: `Displays` | [Quartz Display Services](https://developer.apple.com/documentation/coregraphics/quartz-display-services) | `CGDirectDisplay`, `CGDisplayConfiguration`, including `CGGetActiveDisplayList` | Convert display identifiers and configuration code. |
| Dates, times and number formatting: `DateTimeUtils`, `UTCUtils`, `NumberFormatting` | Core Foundation date/calendar/formatter APIs | `CFDate`, `CFCalendar`, `CFTimeZone`, `CFDateFormatter`, `CFNumberFormatter` | Translate representations and formatting. Reading/formatting dates does not replace privileged system-clock setting. |
| Dictionaries and language analysis: `Dictionary`, `LanguageAnalysis` | Dictionary Services and CFStringTokenizer | `DictionaryServices.DCSCopyTextDefinition`, `CFStringTokenizer.CFStringTokenizerCreate` | Rewrite lookup/tokenization callers. Dictionary creation/editing is not equivalent to lookup. |
| Classic text utilities and scripts: `StringCompare`, `TextUtils`, `Script`, `TypeSelect`, `TextEdit`, `TSMTE`, `TextServices` | Core Foundation strings/locales; Core Text; Cocoa text input | `CFString`, `CFLocale`, Core Text; AppKit `NSTextView`, `NSTextInputContext` | Replace script-manager state and encoding assumptions; integrate Cocoa text input. |
| Keyboard Layout Services: `Keyboards` | Text Input Source Services | `TextInputSources.TISCopyCurrentKeyboardInputSource`, `TISSelectInputSource` | Migrate layout enumeration, selection and property access. |
| Clipboard and drag-and-drop: `Scrap`, `Drag` | [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard), Cocoa dragging | AppKit `NSPasteboard`, dragging protocols / `NSDraggingSession` | Convert flavor identifiers, promised data, and drag lifecycle. |
| Classic sound/music: `Sound`, QuickTime music units | Core Audio; [AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine) | `AudioQueue`, `AudioFile`, audio-unit interfaces; AVFoundation `AVAudioEngine` | Implement playback/capture/sequencing against the chosen existing API. |
| Carbon audio-unit views and obsolete listener removal: `AudioUnitCarbonViews`, `AUComponent` | Cocoa views; callback-specific listener removal | CoreAudioKit `AUGenericView`; `AUComponent.AudioUnitRemovePropertyListenerWithUserData` | Custom plug-in UI must become Cocoa. The follow-up audit below found no legacy component-based Audio Unit loader consumers in the searched source. |
| Old ColorSync/image/icon APIs: `ColorSyncDeprecated`, `Icons`, `IconsCore`, `Palettes`, `PictUtils`, `QDPictToCGContext` | ColorSync transforms/profiles; Core Graphics and Image I/O | `ColorSyncTransform`, `ColorSyncProfile`, `CGImage`, `CGImageSource`, `CGImageDestination` | Reimplement color/image pipelines and convert PICT assets. A color-management API does not by itself implement a display-calibration plug-in. |
| Classic fonts and font matching: `Fonts`, `FontSync`, `ATSFont`, `ATSUnicode*` | Core Text and AppKit font selection | `CTFont`, `CTFontDescriptor`, `CTFontManager`; `NSFontManager`, `NSFontPanel` | Convert font matching/metrics. Retained ATS declarations need a separate modern-API audit. |
| Carbon printing UI and old core-print calls: `PMApplication`, `PMApplicationDeprecated`, `PMCoreDeprecated` | Cocoa printing and explicit Core Printing objects | AppKit `NSPrintOperation`, `NSPrintPanel`; `PMCore` | Port print loops/dialog customization and obsolete handle-based state. |
| Open Transport / URL Access: `OpenTransport*`, `URLAccess` | BSD sockets or Foundation URL loading | RTL `Sockets` / `BaseUnix`; `CFSocket`, `CFStream`; Foundation `NSURLSession` | Rewrite networking operations and callbacks; no new socket/HTTP binding required for the basic path. |
| Network Services Location: `NSLCore` | Service discovery chosen for the actual protocol | Foundation `NSNetService` / `NSNetServiceBrowser` exist as historical Bonjour bindings | No direct NSL neighborhood abstraction replacement. Current Network.framework / DNS-SD binding coverage still needs implementation or import; none was found in this Pascal checkout. |
| Code Fragment Manager: `CodeFragments` | Native Mach-O libraries/bundles | RTL `Dynlibs`; `CFBundleLoadExecutable` and related bundle APIs | Rebuild code as native libraries and adapt loading. CFM binaries are not converted by adding bindings. |
| Memory zones, low-memory globals and old execution utilities: `MacMemory`, `LowMem`, `OSUtils`, `Multiprocessing` | Pascal memory management; POSIX memory protection where required | RTL `GetMem` / `FreeMem`, `Move` / `FillChar`; `BaseUnix.fpMProtect` | Remove classic heap-zone/A5/world assumptions. No equivalent is promised for classic hardware globals. |
| Thread Manager pool-count queries: `Threads` | Remove obsolete pool assumptions | Existing execution model needs no replacement binding for these counts | No threaded implementation is introduced by this cleanup. Any actual scheduling redesign remains a separate decision. |
| AVL Tree Utilities: `AVLTree` | An application-owned Pascal container | `fcl-base` `AVL_Tree` exists | Adapt ownership, comparator and traversal behavior; not a drop-in binding replacement. |
| Gestalt patching: `GestaltEqu` | Explicit capability checks / ordinary application state | Foundation `NSProcessInfo`; normal RTL state mechanisms | `NewGestalt` / `ReplaceGestalt` system-selector patching has no proposed equivalent. |
| Classic application/event/help APIs: `MacApplication`, `Events`, `MacHelp`; Carbon event/HI units | AppKit application, events, Dock and help | `NSApplication`, `NSEvent`, `NSDockTile`, `NSHelpManager`, `NSMenu`, `NSWindow`, `NSView` | Move application integration and event handling into Cocoa. Preserve surviving non-UI Carbon declarations until individually audited. |
| Classic Notification Manager: `Notification` | [UserNotifications](https://developer.apple.com/documentation/usernotifications) for user-visible notifications | Old Foundation `NSUserNotification` is present; **UserNotifications bindings were not found** | Add the current framework bindings if notifications are needed; do not adopt another deprecated API as the final replacement. |
| Old power/device/SCSI operations: `Power`, `SCSI` | [IOKit](https://developer.apple.com/documentation/iokit), power assertions, or application activity tokens as applicable | `NSProcessInfo.beginActivityWithOptions_reason` exists; **IOPM/IOService/SCSI task interfaces were not found** | Add the specific IOKit bindings required by an actual device/power use case. Some old hardware controls have no modern equivalent. `IOKitReturn` alone is not IOKit coverage. |
| Legacy Keychain FSSpec entry point: `KeychainCore.KCMakeKCRefFromFSSpec` | [Keychain Services](https://developer.apple.com/documentation/security/keychain-services), preferably SecItem operations for new credential storage | `SecBase` / `SecTrust` and SecurityFoundation exist; **SecItem / modern keychain-storage declarations were not found** | Add storage/query/update/delete bindings for a credential feature. Existing certificate/trust types do not provide that implementation. |
| AppleScript debugging/property extensions: `ASDebugging` | [OSAKit](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/OSX_Technology_Overview/SystemFrameworks/SystemFrameworks.html) where it covers the use case | `OSAScript` and the surviving OSA interfaces | Script execution bindings exist; exact debugging/property behavior requires a consumer-specific audit. |
| Old Component Manager calls: `Components` | Component-specific replacement; AudioComponent for audio | `AudioComponents.pas` and surviving component functions exist | Do not claim one replacement for every component type; determine the consumer's framework. |
| Old Translation Manager: `Translation`, `TranslationExtensions` | Format-specific conversion in the consuming application | Historical `TranslationServices` successor exists | Current converter/format support still needs review; that old successor is not a promise of a modern conversion feature. |
| Objective-C legacy ABI branches: `ObjCRuntime`; aggregate helpers in `MacOSAll` | Existing 64-bit declarations and compiler Objective-C support | First-batch universal-interface checksums matched the baseline; the now-empty ObjCRuntime shell is removed in the follow-up | No new binding for the retained ABI. Obsolete garbage-collector/runtime manipulation functions are not recreated. |

The Carbon UI grouping also covers `Appearance`, `ControlDefinitions`, `Controls`,
`Dialogs`, `Lists`, `Menus`, `MacWindows`, `Navigation`, `IBCarbonRuntime`,
`ColorPicker`, `CarbonEvents*`, and the pruned `HI*` declarations. QuickDraw
grouping also covers `QDOffscreen` and `QuickdrawText`; QuickTime grouping includes
`QTSMovie` and `QTStreamingComponents`.

Rows marked missing are binding work, not justification for retaining an API
that is already nonfunctional. No new framework or application implementation
is included in this removal batch.

## Known consumers and remaining work

- `fcl-base/src/custapp.pas` uses CoreFoundation bundle/path APIs through
  `MacOSAll`. Preserve this functioning path.
- Nexus fpGUI's Cocoa backend uses `CocoaAll`; preserve it and its AppKit types.
- Nexus2D's old `Rtt_MacSurfaceVideoRecorder.mm` is disabled by `#if 0`. Its
  QTKit-based implementation is historical, not a working recording feature.
  An AVFoundation recorder would require implementation if this feature is wanted.
- Nexus2D's Mac WebView and OpenGL implementations require later migration;
  neither is being removed in this nonfunctional/32-bit binding batch.

## Follow-up cleanup (2026-10-10)

The confirmed dead-code findings are now cleaned up. The first batch selected
supported 64-bit declarations and removed QTKit; neither batch constitutes a
complete current-SDK audit.

| Finding and evidence | Replacement / binding coverage | Disposition |
| --- | --- | --- |
| PowerPC64 conditionals were unreachable: both package CPU lists select only x86_64/aarch64, and the compiler has no retained PowerPC backend. | Existing x86_64/aarch64 branches; no new bindings. | Removed PowerPC selection branches and unused target constants throughout both binding packages. Shared expressions were simplified; historical architecture identifiers in data declarations remain. |
| Declaration-free legacy shells remained registered after their API declarations disappeared in the 32-bit pruning. | Relevant feature replacements are listed above; the empty units need no new binding. | Removed 22 shells, their namespace wrappers, registrations, aggregate includes and obsolete `uses` entries. Useful umbrella units such as CoreFoundation remain. |
| Foundation included `NSGarbageCollector.inc` and its class forward. Apple states in its [Objective-C runtime source](https://github.com/apple-oss-distributions/objc4/blob/main/runtime/objc-auto.mm) that garbage collection is unsupported; collector compatibility routines are stubs. | Ordinary Objective-C object ownership and autorelease pools; existing compiler Objective-C support and `NSAutoreleasePool` bindings. ARC in Objective-C source is not a Pascal replacement binding. | Removed the class include, registration and forward after finding no consumers. Kept `NSAllocateCollectable` / `NSReallocateCollectable`: their names alone do not establish that their fallback allocation behavior is nonfunctional. |
| `LowMem.pas` exported `LMSetApFontID` and `LMSetSysFontSize`; their translated Apple documentation explicitly says the corresponding functionality is unsupported on Mac OS X. | AppKit font selection (`NSFont`, control/view font properties) and Core Text, already present. | Removed both unsupported setters after finding no callers. Other LowMem entry points remain pending individual review. |
| `Components.pas` exposes legacy component enumeration/opening. Apple says [Carbon Component Manager cannot open Audio Units for arm64 or apps linked against macOS 11+ SDKs](https://developer.apple.com/documentation/apple-silicon/porting-your-audio-code-to-apple-silicon). | `AudioComponents.pas` already declares `AudioComponentFindNext`, `AudioComponentInstanceNew`, and `AudioComponentRegister`; `AUComponent` already imports it. | No legacy Audio Unit loader consumers were found in the searched FPC source/tests or Nexus packages/projects, so no application migration was needed. Retained shared Component Manager declarations: the Audio Unit restriction does not establish that non-audio component operations are dead. |
| ImageKit retains QTMovie representation constants in `imagekit/IKImageBrowserView.inc`. These refer to the retired QTKit ecosystem, although they are not imports of the removed QTKit unit. | URL-based media sources and AVFoundation/AVKit are available; ImageKit declares `IKImageBrowserNSURLRepresentationType`. | Check the individual representation contracts and consumers before deleting constants or claiming an equivalent ImageKit rendering path. |

The 22 removed source units are `CodeFragments`, `HIMovieView`, `HIRelevanceBar`,
`HITextUtils`, `ImageCodec`, `MediaHandlers`, `ObjCRuntime`,
`OpenTransportProtocol`, `OpenTransportProviders`, `PMApplication`,
`PMApplicationDeprecated`, `PMDefinitionsDeprecated`,
`PMPrintingDialogExtensions`, `QTML`, `QTSMovie`, `QTStreamingComponents`,
`QuickTimeErrors`, `QuickTimeMusic`, `QuickTimeStreaming`, `QuickTimeVR`,
`SCSI`, and `Sound`. Each had no remaining API declarations or declaration
includes. Their `MacOsApi.*` wrappers are removed as well.

### PowerPC scope decision

Removing PowerPC from the current Nexus desktop/mobile target set remains
reasonable, but the broader architecture is not dead. IBM introduced
[Power11 servers in July 2025](https://newsroom.ibm.com/2025-07-08-ibm-power11-raises-the-bar-for-enterprise-it),
and NXP maintains [Power Architecture embedded products](https://www.nxp.com/products/processors-and-microcontrollers/power-architecture%3APOWER-ARCHITECTURE).
Apple's PowerPC Mac platform is a different case: its
[2009 Snow Leopard release required Intel processors](https://www.apple.com/newsroom/2009/06/08Apple-Unveils-Mac-OS-X-Snow-Leopard/).

The tradeoff is deliberately foregoing POWER server/Linux and Power Architecture
embedded targets. Reconsider that choice if a concrete supported product needs
them. Old PowerPC Mac binding branches do not provide those targets; support
would require a compiler backend, target ABI/RTL integration and validation.
This cleanup changes Apple bindings only and does not revisit compiler targets.

`InstantMessage`, `PubSub`, and `SyncServices` are still registered Cocoa packages
and deserve a focused SDK/runtime audit. Apple explicitly labels InstantMessage
deprecated and says not to use it in its [framework reference](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/OSX_Technology_Overview/SystemFrameworks/SystemFrameworks.html),
but this review has not established that every operation in all three frameworks
is nonfunctional. They are candidates, not confirmed whole-framework deletions.
OpenGL, AddressBook, CalendarStore and SceneKit also require their own availability
and consumer checks; deprecation alone is not proof that code cannot run.

## Deferred deprecated functionality

| Functionality | Intended replacement | Binding status / remaining work |
| --- | --- | --- |
| Legacy WebKit `WebView` | `WKWebView` | Both bindings exist in `cocoaint/src/webkit`. Nexus2D's native browser implementation still needs migration. |
| OpenGL / NSOpenGL | Metal | Verify Metal binding coverage and renderer requirements before planning a migration. No renderer replacement is implemented in this batch. |
| AddressBook | Contacts | Contacts binding coverage still needs verification. |
| CalendarStore | EventKit | `cocoaint/src/EventKit.pas` exists; consumer migration remains separate. |
| SceneKit | Evaluate current Apple rendering alternatives for the actual use case | Replacement choice and coverage still need review. |

## First-batch validation and limitations

- Before edits, `MacOS`, `MacOSAll`, `CocoaAll`, `AVFoundation`, `AVKit` and
  `QTKit` compiled for x86_64-darwin and aarch64-darwin using the existing cross
  compilers, matching RTL, and the package's `-Mmacpas` option. These are
  compile-only checks; no Apple SDK linker or Mac runtime was exercised.
- An initial direct compile without the package's `-Mmacpas` option failed;
  rebuilding with the declared package options passed. That invocation is not
  the baseline used for comparison.
- The standalone `cocoaint/src/QuartzCore.pas` wrapper has unbalanced existing
  conditional directives in its `uses` section. The first batch left this
  wrapper untouched. `CocoaAll` includes the QuartzCore declarations directly
  and passed the baseline check. Direct standalone compilation without
  `COCOAALL` reproduced `ENDIF without IF(N)DEF` at then-line 208 in both the
  first-batch baseline and final source. The follow-up prunes only its balanced
  architecture header; the existing `uses` defect remains separate.

### Scope of the mechanical pruning

- Select the existing 64-bit declaration branches and remove the excluded
  32-bit bodies, including obsolete 32-bit architecture-selection branches.
- Restrict both package CPU lists to `x86_64` / `aarch64`. `univint` retains its
  macOS, iOS and simulator OS selections; `cocoaint` remains macOS-only.
- Reject a direct 32-bit `MacTypes` compilation with an explicit fatal diagnostic.
- Keep shared records, constants, and modern declarations in mixed historical
  units. These units are not removed merely because their filenames are old.
- Delete `controldemo` and its example makefiles/registration: its Carbon window
  and control APIs cannot form a supported 64-bit example.
- Keep compiler MACPAS support and every compiler/RTL source file unchanged.

### Reproduction

First-batch validation used ignored `output/apple-bindings-cleanup/`. That
directory is no longer present; the results below are the recorded historical
results. The follow-up has its own fresh baseline and logs, described below.
The baseline is committed `6fad023d`; Apple package sources were extracted there
for comparison without changing the working checkout. Each target/phase uses
a separate empty unit-output directory and the matching existing RTL.

Compile options:

```text
-n -T<darwin|ios|iphonesim> -Mmacpas -dCOCOAALL -dMACOSALL
-dLEGACY_SETNEEDSDISPLAY -Cn -s
-Fu<matching rtl/units/cpu-os> -Fu<fresh output>
-Fu<source/packages/univint/src> -Fu<source/packages/cocoaint/src>
-FU<fresh output> -FE<fresh output>
```

For macOS, compile `MacOS.pas`, `MacOSAll.pas`, then every `AddUnit` target in
`cocoaint/fpmake.pas`. For iOS/simulator, compile the two universal-interface roots.
`-Cn -s` deliberately skips assembly/linking; these checks do not validate
framework availability at link time or runtime on a current Mac.

### Completed results (2026-10-10)

| Check | Result |
| --- | --- |
| Untouched baseline: 2 universal roots plus 60 Cocoa roots on each macOS CPU; 2 universal roots on each mobile/simulator target | 130/130 compile checks passed. |
| Final sources: same matrix, with QTKit removed from the two macOS builds | 128/128 passed: 61 each on x86_64-darwin and aarch64-darwin; 2 each on x86_64-iphonesim, aarch64-iphonesim and aarch64-ios. |
| Final universal-interface PPU interface checksums against baseline | All 475 units match on each of the five targets: 2,375 matches, zero differences. |
| Initial 32-bit branch pruning, before deleting obsolete Cocoa wrappers | All 493 then-compiled unit interfaces matched on each macOS CPU. Removing obsolete public Cocoa names subsequently changes CocoaAll and dependent package checksums intentionally. |
| Namespaced MacOSAll, CocoaAll, AVFoundation and AVKit on x86_64-darwin | 4/4 passed. Build namespaced RTL types in their normal mode, universal interfaces with MacPas, and Cocoa wrappers with Delphi mode. |
| Existing `fcl-base` CustApp consumer on both macOS CPUs | 2/2 passed with the final MacOSAll PPU. |
| Both changed `fpmake.pas` package definitions | Compiled successfully. All unit and namespace-map source paths resolve. |
| Actual i386 compiler, direct MacTypes compilation | Rejected as intended: `Nexus Apple bindings require a 64-bit target`. |
| Mechanical source audit | 589 modified binding source/include files contain only retained original lines, conditional-start promotions, and the explicit 64-bit guard. |
| Working diff | `git diff --check` passes. 638 tracked files affected, including 46 deleted files; net reduction 178,874 lines, excluding this new document. Compiler and RTL source diffs are empty. |

The extra namespace checks initially lacked the correct per-package modes and
namespaced RTL include paths. Correcting the invocation passed; no source fix
was made for those invocation errors. Likewise, the first universal-interface
invocation without `-Mmacpas` is excluded from the baseline result.

No native Windows bootstrap, Apple framework linking, or Apple runtime test was
run for this binding-only batch. The 128 checks cover the registered package
roots, not every independently compilable convenience wrapper; in particular,
the existing standalone QuartzCore wrapper problem remains outside this change.

## Follow-up validation and limitations

Compared against committed `e09f5bfa`, extracted into an isolated source
directory without changing the working checkout. Used the same existing cross
compilers and matching RTL for both phases, with fresh unit-output directories
and the compile options above. No cached binding PPUs were reused between the
baseline and changed sources.

| Check | Result |
| --- | --- |
| Committed baseline: universal roots on five Apple targets and every registered Cocoa root on both macOS CPUs | 128/128 passed. |
| Changed source: identical matrix | 128/128 passed: 61 each on x86_64-darwin and aarch64-darwin; 2 each on x86_64-iphonesim, aarch64-iphonesim and aarch64-ios. |
| Namespaced MacOSAll, CocoaAll, AVFoundation and AVKit on both macOS CPUs | 8/8 passed. Namespaced System.CTypes was built in its normal mode, MacOSAll with MacPas, and the Cocoa wrappers with Delphi mode. |
| Existing `fcl-base` CustApp consumer on both macOS CPUs | 2/2 passed with the changed MacOSAll PPU. |
| Both `fpmake.pas` package definitions | Compiled successfully with the native compiler. All unit and namespace-map source paths resolve. |
| PPU interface inventory | Exactly the 22 intentionally deleted units are absent on every target; no unexpected missing units. |
| Interface checksums on each macOS CPU | 511 unchanged, 65 changed, 22 removed. Changes include the removed class/setters and obsolete imports, with dependent interface checksums. |
| Interface checksums on mobile/simulator targets | x86_64-iphonesim and aarch64-ios: 442 unchanged, 11 changed, 22 removed each. aarch64-iphonesim: 440 unchanged, 13 changed, 22 removed. This batch intentionally changes interfaces; it does not claim checksum identity. |
| Source audit | No remaining PowerPC-selecting conditionals in either package's source; no dangling removed-unit imports/includes. Shared records and functioning umbrella units remain. |
| Working diff | `git diff --check` passes. Compiler and RTL sources are unchanged. 45 files deleted: 22 units, 22 namespace wrappers and the collector include. |

The follow-up removes about 15,000 net source lines. It introduces no new
frameworks, runtime ownership mechanisms, or threaded implementation. Validation
is compile-only: no native Windows bootstrap, Apple SDK linking or Apple runtime
test was run. The standalone QuartzCore `uses` defect remains as documented
above; the registered Cocoa roots pass.

Follow-up logs and JSON results are under ignored
`output/apple-bindings-followup/`. Removed 10,519 generated artifacts and copied
baseline files (357.31 MiB) after verification. Automatic approval review
rejected the subsequent removal of empty directories and two temporary helper
scripts with `blocked by policy`; those small leftovers remain alongside the
validation records. These local records are not part of the commit; this
register is the durable result and replacement inventory.

## Next audit priorities

1. Check residual 64-bit declarations and framework availability against a
   current Apple SDK. An old unit name or successful Pascal compilation alone
   cannot establish current runtime support.
2. Inspect standalone/obsolete wrappers and remaining historical data types for
   actual consumers before further deletion. Keep recording successors and gaps
   here rather than treating deprecated replacements as a finished migration.
3. Fill missing bindings only for selected features: Security credential storage,
   UserNotifications, IOKit power/device APIs, and modern service discovery.
4. Handle the deferred WebKit/OpenGL and other application migrations separately,
   with linked and runtime validation on macOS.
