{ Parsed from AppKit.framework NSDraggingSession.h }


{$ifdef TYPES}
type
  NSDraggingSessionPtr = ^NSDraggingSession;
{$endif}

{$ifdef CLASSES}

type
  NSDraggingSession = objcclass external (NSObject)
  private
    _private: pointer;
    _offset: NSPoint;
    _source: NSDraggingSourceProtocol;
    _alternateDragSource: id;
    _filePromiseDragSource: NSDraggingSourceProtocol;
    _pboard: NSPasteboard;
    _compositeImageCache: NSImage;
    _animatesOnCancelOrFail: ObjCBOOL;
  public
    procedure setDraggingFormation(newValue: NSDraggingFormation); message 'setDraggingFormation:';
    function draggingFormation: NSDraggingFormation; message 'draggingFormation';
    procedure setAnimatesToStartingPositionsOnCancelOrFail(newValue: ObjCBOOL); message 'setAnimatesToStartingPositionsOnCancelOrFail:';
    function animatesToStartingPositionsOnCancelOrFail: ObjCBOOL; message 'animatesToStartingPositionsOnCancelOrFail';
    procedure setDraggingLeaderIndex(newValue: NSInteger); message 'setDraggingLeaderIndex:';
    function draggingLeaderIndex: NSInteger; message 'draggingLeaderIndex';
    function draggingPasteboard: NSPasteboard; message 'draggingPasteboard';
    function draggingSequenceNumber: NSInteger; message 'draggingSequenceNumber';
    function draggingLocation: NSPoint; message 'draggingLocation';
    procedure enumerateDraggingItemsWithOptions_forView_classes_searchOptions_usingBlock (enumOpts: NSDraggingItemEnumerationOptions; view: NSView; classArray: NSArray; searchOptions: NSDictionary; block: OpaqueCBlock); message 'enumerateDraggingItemsWithOptions:forView:classes:searchOptions:usingBlock:';
  end;
{$endif}

