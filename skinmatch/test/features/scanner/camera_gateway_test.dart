import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:skinmatch/features/scanner/data/camera_gateway.dart';
import 'package:skinmatch/features/scanner/data/scanner_models.dart';

void main() {
  DeviceCameraGateway gatewayReturning(PermissionStatus status) {
    return DeviceCameraGateway(
      requestCameraPermission: () async => status,
    );
  }

  Matcher throwsScannerFailure(ScannerErrorCode code) {
    return throwsA(
      isA<ScannerFailure>().having((failure) => failure.code, 'code', code),
    );
  }

  test('izin ditolak sekali menjadi permissionDenied', () async {
    await expectLater(
      gatewayReturning(PermissionStatus.denied).initialize(),
      throwsScannerFailure(ScannerErrorCode.permissionDenied),
    );
  });

  test('izin "jangan tanya lagi" menjadi permissionPermanentlyDenied',
      () async {
    await expectLater(
      gatewayReturning(PermissionStatus.permanentlyDenied).initialize(),
      throwsScannerFailure(ScannerErrorCode.permissionPermanentlyDenied),
    );
  });

  test('izin dibatasi sistem menjadi permissionPermanentlyDenied', () async {
    await expectLater(
      gatewayReturning(PermissionStatus.restricted).initialize(),
      throwsScannerFailure(ScannerErrorCode.permissionPermanentlyDenied),
    );
  });

  test('checkPermission membaca status tanpa meminta izin', () async {
    var requestCalls = 0;
    final gateway = DeviceCameraGateway(
      requestCameraPermission: () async {
        requestCalls++;
        return PermissionStatus.granted;
      },
      readCameraPermission: () async => PermissionStatus.permanentlyDenied,
    );

    expect(await gateway.checkPermission(), PermissionStatus.permanentlyDenied);
    expect(requestCalls, 0);
  });
}
