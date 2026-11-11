import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Получаем размеры экрана (за вычетом верхнего меню Mac и нижнего дока)
    if let screen = NSScreen.main {
      let screenRect = screen.visibleFrame
      
      // Вычисляем 90% от размера экрана
      let width = screenRect.width * 0.9
      let height = screenRect.height * 0.9
      
      // Вычисляем координаты, чтобы окно было ровно по центру
      let x = screenRect.origin.x + (screenRect.width - width) / 2
      let y = screenRect.origin.y + (screenRect.height - height) / 2
      
      let newFrame = NSRect(x: x, y: y, width: width, height: height)
      
      // Применяем новые размеры к окну
      self.setFrame(newFrame, display: true)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
  }
}
