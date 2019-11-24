#import "FlutterCameraViewPlugin.h"
#import <flutter_camera_view/flutter_camera_view-Swift.h>

@implementation FlutterCameraViewPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterCameraViewPlugin registerWithRegistrar:registrar];
}
@end
