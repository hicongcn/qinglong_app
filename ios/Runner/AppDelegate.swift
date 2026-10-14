import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // iOS 13 起采用 UIScene 生命周期后（本项目 Info.plist 声明了 UIApplicationSceneManifest，
    // 且部署目标为 15.0，因此**始终**走场景路径），didFinishLaunching 执行时场景的 window
    // 尚未创建，此时按老写法注册插件会挂到与场景无关的引擎实例上，导致 sqflite /
    // path_provider / shared_preferences 等插件在 Dart 侧全部 MissingPlugin，
    // 画面停在没有首帧的黑屏。故插件注册改到 SceneDelegate 里进行；
    // 这里仅保留对「未声明场景清单」的老式启动路径的兜底。
    if Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") == nil {
      GeneratedPluginRegistrant.register(with: self)
    }
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// UIScene 生命周期入口。
///
/// Xcode 27（iOS 27 SDK）起，未声明 `UIApplicationSceneManifest` 的应用启动即失败
/// （Apple TN3187），因此必须采用场景生命周期；但 Flutter 3.3.10 的引擎里**没有**
/// `FlutterSceneDelegate`（该 API 是后几代 Flutter 才引入的），所以这里手写一个最小实现。
///
/// 本类刻意与 AppDelegate 放在同一文件：无需改动 Xcode 工程文件（pbxproj）即可生效，
/// 由 Info.plist 的 `UISceneDelegateClassName = SceneDelegate` 通过 `@objc(SceneDelegate)`
/// 找到（用 `@objc(...)` 显式指定 ObjC 名，避免依赖 PRODUCT_MODULE_NAME）。
@objc(SceneDelegate)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  /// 插件只能注册一次，且必须注册到场景实际使用的那个引擎上。
  private static var pluginsRegistered = false

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    // 声明了 UISceneStoryboardFile 时，UIKit 会按 storyboard 建好 window（根视图控制器
    // 即 Main.storyboard 中的 FlutterViewController）并赋给本属性；取不到时按顺序回退，
    // 保证任何一条路径都能出画面，不会留下一片黑的窗口。
    let window: UIWindow
    if let existing = self.window {
      window = existing
    } else if let storyboardWindow = windowScene.windows.first(where: {
      $0.rootViewController is FlutterViewController
    }) {
      window = storyboardWindow
    } else {
      window = UIWindow(windowScene: windowScene)
    }

    let flutterViewController: FlutterViewController
    if let rootViewController = window.rootViewController as? FlutterViewController {
      flutterViewController = rootViewController
    } else {
      let created = FlutterViewController(project: nil, nibName: nil, bundle: nil)
      window.rootViewController = created
      flutterViewController = created
    }

    if !SceneDelegate.pluginsRegistered {
      SceneDelegate.pluginsRegistered = true
      // 必须注册到这张场景真正使用的引擎上，且需早于引擎跑起 Dart（此处在 window
      // 可见之前，满足时序要求）。
      GeneratedPluginRegistrant.register(with: flutterViewController)
    }

    self.window = window
    // 同步给 AppDelegate：引擎与部分插件会通过 UIApplication.shared.delegate.window
    // 取当前窗口。
    (UIApplication.shared.delegate as? FlutterAppDelegate)?.window = window
    window.makeKeyAndVisible()
  }

  // 采用场景生命周期后，UIApplicationDelegate 的这四个回调不再被系统触发，
  // 需从场景回调转交（AppDelegate 实现了这些方法并会转发给插件，例如
  // local_auth 依赖 applicationDidBecomeActive 在系统弹窗返回后重试生物识别）。
  func sceneDidBecomeActive(_ scene: UIScene) {
    UIApplication.shared.delegate?.applicationDidBecomeActive?(UIApplication.shared)
  }

  func sceneWillResignActive(_ scene: UIScene) {
    UIApplication.shared.delegate?.applicationWillResignActive?(UIApplication.shared)
  }

  func sceneWillEnterForeground(_ scene: UIScene) {
    UIApplication.shared.delegate?.applicationWillEnterForeground?(UIApplication.shared)
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    UIApplication.shared.delegate?.applicationDidEnterBackground?(UIApplication.shared)
  }

  func sceneDidDisconnect(_ scene: UIScene) {}
}
