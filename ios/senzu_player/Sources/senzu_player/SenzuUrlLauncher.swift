import UIKit

@objc public class SenzuUrlLauncher: NSObject {
    @objc public static func launchUrl(_ urlString: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { success in
                completion(success)
            }
        }
    }
}
