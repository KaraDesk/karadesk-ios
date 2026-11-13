import SwiftUI
import UIKit

struct InterfaceStyleOverride: UIViewRepresentable {
    let colorScheme: ColorScheme?

    func makeUIView(context: Context) -> StyleView {
        let view = StyleView()
        view.isUserInteractionEnabled = false
        view.isHidden = true
        return view
    }

    func updateUIView(_ view: StyleView, context: Context) {
        view.style = switch colorScheme {
        case .light: .light
        case .dark: .dark
        default: .unspecified
        }
    }

    final class StyleView: UIView {
        var style: UIUserInterfaceStyle = .unspecified {
            didSet { apply() }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        private func apply() {
            var responder: UIResponder? = self

            while let next = responder, !(next is UIViewController) {
                responder = next.next
            }

            guard var controller = responder as? UIViewController else {
                return
            }

            while let parent = controller.parent {
                controller = parent
            }

            if controller.overrideUserInterfaceStyle != style {
                controller.overrideUserInterfaceStyle = style
            }

            fillSheetCorners(for: controller)
        }

        private func fillSheetCorners(for controller: UIViewController) {
            guard let sheet = controller.presentationController?.presentedView,
                  sheet !== controller.view else {
                return
            }

            let backing = sheet.subviews.first { $0.tag == Self.backingTag } ?? {
                let view = UIView()
                view.tag = Self.backingTag
                view.isUserInteractionEnabled = false
                view.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
                sheet.insertSubview(view, at: 0)
                return view
            }()

            let height: CGFloat = 80
            backing.frame = CGRect(x: 0, y: sheet.bounds.height - height, width: sheet.bounds.width, height: height)
            backing.isHidden = style == .unspecified
            backing.backgroundColor = UIColor.systemBackground.resolvedColor(
                with: UITraitCollection(traitsFrom: [
                    UITraitCollection(userInterfaceStyle: style == .dark ? .dark : .light),
                    UITraitCollection(userInterfaceLevel: .elevated),
                ]),
            )
        }

        private static let backingTag = 0x4B44_5348
    }
}
