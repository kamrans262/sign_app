import Flutter
import UIKit
import AuthenticationServices

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appleAuth = AppleAuthBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "Sign2DigitalAppleAuth") {
      appleAuth.attach(to: registrar.messenger())
    }
  }
}

private final class AppleAuthBridge: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
  private var channel: FlutterMethodChannel?
  private var pending: FlutterResult?
  private var controller: ASAuthorizationController?
  private var anchor: ASPresentationAnchor?

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "sign2digital/apple_auth", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "signIn" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: nil, details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let nonce = args["nonce"] as? String,
            nonce.count == 64 else {
        result(FlutterError(code: "invalid_nonce", message: nil, details: nil))
        return
      }
      self.signIn(nonce: nonce, result: result)
    }
  }

  private func signIn(nonce: String, result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "busy", message: nil, details: nil))
      return
    }
    guard let window = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .filter({ $0.activationState == .foregroundActive })
      .flatMap({ $0.windows })
      .first(where: { $0.isKeyWindow }) else {
      result(FlutterError(code: "unavailable", message: nil, details: nil))
      return
    }
    anchor = window
    pending = result
    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [.fullName, .email]
    request.nonce = nonce
    let controller = ASAuthorizationController(authorizationRequests: [request])
    self.controller = controller
    controller.delegate = self
    controller.presentationContextProvider = self
    controller.performRequests()
  }

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    // The active key window is captured before starting authorization.
    return anchor ?? ASPresentationAnchor()
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
          let data = credential.identityToken,
          let token = String(data: data, encoding: .utf8), !token.isEmpty else {
      finish(FlutterError(code: "missing_token", message: nil, details: nil))
      return
    }
    var response: [String: String] = ["id_token": token]
    if let data = credential.authorizationCode, let code = String(data: data, encoding: .utf8) {
      response["authorization_code"] = code
    }
    if let name = credential.fullName {
      response["name"] = PersonNameComponentsFormatter().string(from: name)
    }
    finish(response)
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    if (error as? ASAuthorizationError)?.code == .canceled {
      finish(nil)
    } else {
      finish(FlutterError(code: "apple_auth_failed", message: nil, details: nil))
    }
  }

  private func finish(_ value: Any?) {
    let callback = pending
    pending = nil
    controller = nil
    anchor = nil
    callback?(value)
  }
}
