{ Parsed from SecurityInterface.framework SFKeychainSettingsPanel.h }


{$ifdef TYPES}
type
  SFKeychainSettingsPanelPtr = ^SFKeychainSettingsPanel;
{$endif}

{$ifndef _SFKEYCHAINSETTINGSPANEL_H_}
{$ifdef CLASSES}

type
  SFKeychainSettingsPanel = objcclass external (NSPanel)
  private
    _reserved_SFKeychainSettingsPanel: id;
  public
    class function sharedKeychainSettingsPanel: SFKeychainSettingsPanel; message 'sharedKeychainSettingsPanel';
    function runModalForSettings_keychain (settings: SecKeychainSettingsPtr; keychain: SecKeychainRef): NSInteger; message 'runModalForSettings:keychain:';
    procedure beginSheetForWindow_modalDelegate_didEndSelector_contextInfo_settings_keychain (docWindow: NSWindow; delegate: id; didEndSelector: SEL; contextInfo: pointer; settings: SecKeychainSettingsPtr; keychain: SecKeychainRef); message 'beginSheetForWindow:modalDelegate:didEndSelector:contextInfo:settings:keychain:';
  end;
{$endif}

{$endif}
