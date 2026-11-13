import SwiftUI

struct SparkleStar: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let origin = CGPoint(x: rect.midX - 12 * scale, y: rect.midY - 12 * scale)

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }

        var path = Path()
        path.move(to: p(11.017, 2.814))
        path.addQuadCurve(to: p(12.983, 2.814), control: p(12.000, 1.182))
        path.addLine(to: p(14.034, 8.372))
        path.addQuadCurve(to: p(15.628, 9.966), control: p(14.287, 9.713))
        path.addLine(to: p(21.186, 11.017))
        path.addQuadCurve(to: p(21.186, 12.983), control: p(22.818, 12.000))
        path.addLine(to: p(15.628, 14.034))
        path.addQuadCurve(to: p(14.034, 15.628), control: p(14.287, 14.287))
        path.addLine(to: p(12.983, 21.186))
        path.addQuadCurve(to: p(11.017, 21.186), control: p(12.000, 22.818))
        path.addLine(to: p(9.966, 15.628))
        path.addQuadCurve(to: p(8.372, 14.034), control: p(9.713, 14.287))
        path.addLine(to: p(2.814, 12.983))
        path.addQuadCurve(to: p(2.814, 11.017), control: p(1.182, 12.000))
        path.addLine(to: p(8.372, 9.966))
        path.addQuadCurve(to: p(9.966, 8.372), control: p(9.713, 9.713))
        path.closeSubpath()
        path.closeSubpath()
        return path
    }
}

struct SparkleAccents: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let origin = CGPoint(x: rect.midX - 12 * scale, y: rect.midY - 12 * scale)

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }

        var path = Path()
        path.move(to: p(20, 2))
        path.addLine(to: p(20, 6))
        path.move(to: p(22, 4))
        path.addLine(to: p(18, 4))
        path.addEllipse(in: CGRect(origin: p(2, 18), size: CGSize(width: 4 * scale, height: 4 * scale)))
        return path
    }
}
