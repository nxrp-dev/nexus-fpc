{ Parsed from AppKit.framework NSTouch.h }


{$ifdef TYPES}
type
  NSTouchPtr = ^NSTouch;
{$endif}

{$ifdef TYPES}
type
  NSTouchPhase = NSUInteger;
  NSTouchPhasePtr = ^NSTouchPhase;

const
  NSTouchPhaseBegan = 1 shl 0;
  NSTouchPhaseMoved = 1 shl 1;
  NSTouchPhaseStationary = 1 shl 2;
  NSTouchPhaseEnded = 1 shl 3;
  NSTouchPhaseCancelled = 1 shl 4;
  NSTouchPhaseTouching = NSTouchPhaseBegan + NSTouchPhaseMoved + NSTouchPhaseStationary;
  NSTouchPhaseAny = NSUIntegerMax;
{$endif}

{$ifdef CLASSES}

type
  NSTouch = objcclass external (NSObject, NSCopyingProtocol)
  private
    _index: NSInteger;
    _identity: id;
    _phase: NSTouchPhase;
    _normalizedPosition: NSPoint;
    _privateFlags: NSInteger;
    _view: NSView;
    _device: id;
    _deviceSize: NSSize;
  public
    function identity: id; message 'identity';
    function phase: NSTouchPhase; message 'phase';
    function normalizedPosition: NSPoint; message 'normalizedPosition';
    function isResting: ObjCBOOL; message 'isResting';
    function device: id; message 'device';
    function deviceSize: NSSize; message 'deviceSize';

    { Adopted protocols }
    function copyWithZone (zone: NSZonePtr): id; message 'copyWithZone:';
  end;
{$endif}

