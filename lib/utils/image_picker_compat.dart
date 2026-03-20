export 'image_picker_compat_stub.dart'
    if (dart.library.html) 'image_picker_compat_web.dart'
    if (dart.library.io) 'image_picker_compat_io.dart';

