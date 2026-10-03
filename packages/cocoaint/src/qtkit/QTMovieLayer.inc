{ Parsed from QTKit.framework QTMovieLayer.h }


{$ifdef TYPES}
type
  QTMovieLayerPtr = ^QTMovieLayer;
{$endif}

{$if (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5)}
{$ifdef CLASSES}

type
  QTMovieLayer = objcclass external (CALayer)
  private
    _movieLayerPriv: QTMovieLayerPrivate;
  public
    class function layerWithMovie (movie: QTMovie): id; message 'layerWithMovie:';
    function initWithMovie (movie: QTMovie): id; message 'initWithMovie:';
    procedure setMovie (movie: QTMovie); message 'setMovie:';
    function movie: QTMovie; message 'movie';
  end;
{$endif}

{$endif}
