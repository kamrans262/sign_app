import Flutter
import UIKit
import AuthenticationServices
import StoreKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appleAuth = AppleAuthBridge()
  private let storeKit = StoreKitBridge()

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "Sign2DigitalStoreKit") {
      storeKit.attach(to: registrar.messenger())
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

private final class StoreKitBridge {
  private var channel: FlutterMethodChannel?
  private var updateTask: Task<Void, Never>?
  func attach(to messenger: FlutterBinaryMessenger) {
    let c = FlutterMethodChannel(name: "sign2digital/storekit", binaryMessenger: messenger)
    channel = c
    c.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: nil, details: nil)); return
      }
      Task { @MainActor in
        do { try await self.handle(call, result: result) }
        catch { result(FlutterError(code: "storekit_error", message: "App Store operation could not be completed.", details: nil)) }
      }
    }
    updateTask?.cancel()
    updateTask = Task { @MainActor [weak self] in
      for await update in StoreKit.Transaction.updates {
        if Task.isCancelled { break }
        if case .verified(let t) = update {
          self?.channel?.invokeMethod("transactionUpdated", arguments: ["id": String(t.id), "token": t.appAccountToken?.uuidString.lowercased() ?? ""])
        }
      }
    }
  }
  deinit { updateTask?.cancel() }
  @MainActor private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) async throws {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "products":
      let ids = args["ids"] as? [String] ?? []
      let products = try await Product.products(for: ids)
      let rows = products.compactMap { p -> [String: String]? in
        guard p.type == .autoRenewable, let s = p.subscription,
              s.subscriptionPeriod.value == 1 else { return nil }
        let period: String
        switch s.subscriptionPeriod.unit {
        case .month: period = "monthly"
        case .year: period = "yearly"
        default: return nil
        }
        return ["id": p.id, "price": p.displayPrice, "period": period]
      }
      result(rows)
    case "purchase":
      guard let id = args["id"] as? String, let token = args["token"] as? String,
            let uuid = UUID(uuidString: token),
            let product = try await Product.products(for: [id]).first,
            product.type == .autoRenewable else {
        result(FlutterError(code: "unavailable", message: nil, details: nil)); return
      }
      switch try await product.purchase(options: [.appAccountToken(uuid)]) {
      case .success(let verification):
        guard case .verified(let t) = verification else {
          result(FlutterError(code: "unverified", message: nil, details: nil)); return
        }
        result(["status": "purchased", "id": String(t.id)])
      case .pending: result(["status": "pending"])
      case .userCancelled: result(["status": "cancelled"])
      @unknown default: result(["status": "unknown"])
      }
    case "transactions":
      if args["restore"] as? Bool == true { try await AppStore.sync() }
      var rows: [String: [String: String]] = [:]
      for await v in StoreKit.Transaction.currentEntitlements {
        if case .verified(let t) = v {
          rows[String(t.id)] = ["id": String(t.id), "token": t.appAccountToken?.uuidString.lowercased() ?? ""]
        }
      }
      for await v in StoreKit.Transaction.unfinished {
        if case .verified(let t) = v {
          rows[String(t.id)] = ["id": String(t.id), "token": t.appAccountToken?.uuidString.lowercased() ?? ""]
        }
      }
      result(Array(rows.values))
    case "finish":
      guard let id = args["id"] as? String else { result(nil); return }
      for await v in StoreKit.Transaction.unfinished {
        if case .verified(let t) = v, String(t.id) == id { await t.finish(); break }
      }
      result(nil)
    case "manage":
      guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }) else {
        result(FlutterError(code: "unavailable", message: nil, details: nil)); return
      }
      try await AppStore.showManageSubscriptions(in: scene)
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }
}
