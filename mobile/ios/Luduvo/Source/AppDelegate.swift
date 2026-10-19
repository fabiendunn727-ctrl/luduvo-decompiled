import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private let engine = LuduvoEngine()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Load native engine library
        LuduvoEngine.loadLibrary()

        // Create window
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = GameViewController(engine: engine)
        window?.makeKeyAndVisible()

        // Keep screen on
        UIApplication.shared.isIdleTimerDisabled = true

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle luduvo:// and buildoverse:// deep links
        guard let scheme = url.scheme?.lowercased(),
              (scheme == "luduvo" || scheme == "buildoverse") else {
            return false
        }

        // luduvo://<token>/<host>/<port>/<pubkey>
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = path.split(separator: "/").map(String.init)

        let token = parts.count > 0 ? parts[0] : ""
        let host = parts.count > 1 ? parts[1] : "194.163.173.138"
        let port = parts.count > 2 ? Int(parts[2]) ?? 55000 : 55000
        let pubkey = parts.count > 3 ? parts[3] : ""

        // Write config to documents directory
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let configURL = documents.appendingPathComponent("luduvo_join.json")
            let json = """
                {
                    "token": "\(token)",
                    "host": "\(host)",
                    "port": \(port),
                    "pubkey": "\(pubkey)"
                }
                """
            try? json.write(to: configURL, atomically: true, encoding: .utf8)

            // Start engine with config
            engine.start(configPath: configURL.path)
        }

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        engine.pause()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        engine.resume()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        engine.shutdown()
    }
}

struct JoinConfig: Codable {
    let token: String
    let host: String
    let port: Int
    let pubkey: String
}
