import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Match the desktop layout's minimum content area without fixing the window size.
    self.contentMinSize = NSSize(width: 960, height: 640)
    let contentSize = self.contentRect(forFrameRect: self.frame).size
    self.setContentSize(NSSize(
      width: max(contentSize.width, self.contentMinSize.width),
      height: max(contentSize.height, self.contentMinSize.height)
    ))

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
