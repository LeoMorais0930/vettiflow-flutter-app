library;

export 'local_json_persistence_stub.dart'
    if (dart.library.html) 'local_json_persistence_web.dart'
    if (dart.library.io) 'local_json_persistence_io.dart';
