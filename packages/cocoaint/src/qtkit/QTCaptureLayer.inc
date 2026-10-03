{ Parsed from QTKit.framework QTCaptureLayer.h }


{$ifdef TYPES}
type
  QTCaptureLayerPtr = ^QTCaptureLayer;
{$endif}

{$if (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5)}
{$ifdef CLASSES}

type
  QTCaptureLayer = objcclass external (CALayer)
  private
    _captureLayerPriv: QTCaptureLayerPrivate;
  public
    class function layerWithSession (session: QTCaptureSession): id; message 'layerWithSession:';
    function initWithSession (session: QTCaptureSession): id; message 'initWithSession:';
    procedure setSession (session: QTCaptureSession); message 'setSession:';
    function session: QTCaptureSession; message 'session';
  end;
{$endif}

{$endif}
