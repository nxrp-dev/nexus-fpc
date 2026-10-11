{ Parsed from AppKit.framework NSAnimationContext.h }


{$ifdef TYPES}
type
  NSAnimationContextPtr = ^NSAnimationContext;
{$endif}

{$ifdef CLASSES}

type
  NSAnimationContext = objcclass external (NSObject)
  private
  public
    class procedure runAnimationGroup_completionHandler (changes: OpaqueCBlock; completionHandler: OpaqueCBlock); message 'runAnimationGroup:completionHandler:'; { available in 10_7 }
    class procedure beginGrouping; message 'beginGrouping';
    class procedure endGrouping; message 'endGrouping';
    class function currentContext: NSAnimationContext; message 'currentContext';
    procedure setDuration(newValue: NSTimeInterval); message 'setDuration:';
    function duration: NSTimeInterval; message 'duration';
    procedure setTimingFunction(newValue: CAMediaTimingFunction); message 'setTimingFunction:';
    function timingFunction: CAMediaTimingFunction; message 'timingFunction';
    procedure setCompletionHandler(newValue: OpaqueCBlock); message 'setCompletionHandler:';
    function completionHandler: OpaqueCBlock; message 'completionHandler';
    procedure setAllowsImplicitAnimation(newValue: ObjCBOOL); message 'setAllowsImplicitAnimation:';
    function allowsImplicitAnimation: ObjCBOOL; message 'allowsImplicitAnimation';
  end;
{$endif}

