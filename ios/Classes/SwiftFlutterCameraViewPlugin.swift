import Flutter
import UIKit

public class SwiftFlutterCameraViewPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let factory = FlutterCameraViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "flutter_camera_view")
  }
}
