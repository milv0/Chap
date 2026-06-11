import Foundation
import AppKit

public func isValidDomain(_ domain: String) -> Bool {
    guard !domain.isEmpty,
          let regex = Defaults.domainRegex,
          regex.firstMatch(in: domain, range: NSRange(domain.startIndex..., in: domain)) != nil
    else { return false }
    return true
}

public func chromeBoundsString(x: Int, y: Int, width: Int, height: Int) -> String {
    "\(x), \(y), \(x + width), \(y + height)"
}

public var builtInScreen: NSScreen {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
        ?? NSScreen.main ?? NSScreen.screens[0]
}

public func targetScreen(for site: Site) -> NSScreen {
    if let name = site.displayName {
        return NSScreen.screens.first { $0.localizedName == name } ?? NSScreen.main ?? NSScreen.screens[0]
    }
    return builtInScreen
}
