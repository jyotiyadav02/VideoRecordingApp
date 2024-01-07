// camera_utils.dart
import 'package:camera/camera.dart';

class CameraUtils {
  static Future<void> initializeCamera(
    List<CameraDescription> cameras,
    Function(CameraController) onInitialized,
  ) async {
    final CameraController controller = await _getInitializedCamera(cameras);

    if (onInitialized != null) {
      onInitialized(controller);
    }
  }

  static Future<CameraController> _getInitializedCamera(
    List<CameraDescription> cameras,
  ) async {
    final camerasList = await availableCameras();

    if (camerasList.isEmpty) {
      print("No cameras available");
      throw Exception("No cameras available");
    }

    final controller = CameraController(camerasList[0], ResolutionPreset.high);
    await controller.initialize();

    return controller;
  }
}
