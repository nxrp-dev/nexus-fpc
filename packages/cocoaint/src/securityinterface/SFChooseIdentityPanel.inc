{ Parsed from SecurityInterface.framework SFChooseIdentityPanel.h }


{$ifdef TYPES}
type
  SFChooseIdentityPanelPtr = ^SFChooseIdentityPanel;
{$endif}

{$ifndef _SFCHOOSEIDENTITYPANEL_H_}
{$ifdef CLASSES}

type
  SFChooseIdentityPanel = objcclass external (NSPanel)
  private
    _reserved_SFChooseIdentityPanel: id;
  public
    class function sharedChooseIdentityPanel: SFChooseIdentityPanel; message 'sharedChooseIdentityPanel';
    function runModalForIdentities_message (identities: NSArray; message_: NSString): NSInteger; message 'runModalForIdentities:message:';
    procedure beginSheetForWindow_modalDelegate_didEndSelector_contextInfo_identities_message (docWindow: NSWindow; delegate: id; didEndSelector: SEL; contextInfo: pointer; identities: NSArray; message_: NSString); message 'beginSheetForWindow:modalDelegate:didEndSelector:contextInfo:identities:message:';
    function identity: SecIdentityRef; message 'identity';
    procedure setPolicies (policies: id); message 'setPolicies:';
    function policies: NSArray; message 'policies';
    procedure setDefaultButtonTitle (title: NSString); message 'setDefaultButtonTitle:';
    procedure setAlternateButtonTitle (title: NSString); message 'setAlternateButtonTitle:';
    procedure setShowsHelp (showsHelp: ObjCBOOL); message 'setShowsHelp:';
    function showsHelp: ObjCBOOL; message 'showsHelp';
    procedure setHelpAnchor (anchor: NSString); message 'setHelpAnchor:';
    function helpAnchor: NSString; message 'helpAnchor';
    procedure setInformativeText (informativeText: NSString); message 'setInformativeText:';
    function informativeText: NSString; message 'informativeText';
    procedure setDomain (domainString: NSString); message 'setDomain:';
    function domain: NSString; message 'domain';
  end;


type
  SFChooseIdentityPanelDelegate = objccategory external (NSObject)
    function chooseIdentityPanelShowHelp (sender: SFChooseIdentityPanel): ObjCBOOL; message 'chooseIdentityPanelShowHelp:';
  end;
{$endif}

{$endif}
