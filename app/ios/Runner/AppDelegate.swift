import Flutter
import UIKit
import YandexMapsMobile

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    YMKMapKit.setLocale("ru_RU")
    // Must be a MapKit Mobile SDK key from developer.tech.yandex.ru
    // (JS API / Geocoder keys produce white grid + Invalid api key).
    YMKMapKit.setApiKey("0193814c-3ba4-4571-99a1-e380f0ab9e7a")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
