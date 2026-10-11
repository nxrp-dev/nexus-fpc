{ Parsed from SecurityInterface.framework SFCertificateTrustPanel.h }


{$ifdef TYPES}
type
  SFCertificateTrustPanelPtr = ^SFCertificateTrustPanel;
{$endif}

{$ifndef _SFCERTIFICATETRUSTPANEL_H_}
{$ifdef CLASSES}

type
  SFCertificateTrustPanel = objcclass external (SFCertificatePanel)
  private
    _reserved_SFCertificateTrustPanel: id;
  public
    class function sharedCertificateTrustPanel: SFCertificateTrustPanel; message 'sharedCertificateTrustPanel';
    function runModalForTrust_message (trust: SecTrustRef; message_: NSString): NSInteger; message 'runModalForTrust:message:';
    procedure beginSheetForWindow_modalDelegate_didEndSelector_contextInfo_trust_message (docWindow: NSWindow; delegate: id; didEndSelector: SEL; contextInfo: pointer; trust: SecTrustRef; message_: NSString); message 'beginSheetForWindow:modalDelegate:didEndSelector:contextInfo:trust:message:';
    procedure setInformativeText (informativeText: NSString); message 'setInformativeText:';
    function informativeText: NSString; message 'informativeText';
  end;
{$endif}

{$endif}
