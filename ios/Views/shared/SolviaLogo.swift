import SwiftUI

/// Solvia pusula logosu — vektorel cizilir, her boyutta net kalir.
/// PNG yerine SwiftUI Shape kullanildi: tek bir dosya, retina sorunu yok,
/// renkler temadan gelir.
///
/// Kullanim:
///   SolviaLogo(size: 88)                    // varsayilan: dolu daire
///   SolviaLogo(size: 40, style: .plain)     // halkasiz, sade
struct SolviaLogo: View {
    let size: CGFloat
    var style: Style = .filled

    enum Style {
        /// Koyu lacivert dolu daire icinde beyaz igne (giris ekrani)
        case filled
        /// Arka plansiz, yalnizca igne ve halka (koyu zeminde kullanilir)
        case plain
    }

    var body: some View {
        ZStack {
            if style == .filled {
                Circle().fill(AppTheme.navy)
            }

            // Pusula halkasi
            Circle()
                .stroke(ringColor, lineWidth: size * 0.021)
                .frame(width: size * 0.664, height: size * 0.664)

            CompassNeedle()
                .frame(width: size * 0.266, height: size * 0.617)
        }
        .frame(width: size, height: size)
    }

    private var ringColor: Color {
        style == .filled ? .white.opacity(0.28) : AppTheme.navy.opacity(0.28)
    }
}

/// Dort yuzeyli pusula ignesi. Ust yarim beyaz (kuzey), alt yarim soluk.
/// Her yuzey ayri bir ucgen — golgelendirme bu sekilde yon hissi verir.
private struct CompassNeedle: View {
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let midY = h / 2

            ZStack {
                // Sag ust — en parlak yuzey, kuzeyi gosterir
                Triangle(
                    p1: CGPoint(x: w / 2, y: 0),
                    p2: CGPoint(x: w, y: midY),
                    p3: CGPoint(x: w / 2, y: midY)
                )
                .fill(.white)

                // Sol ust
                Triangle(
                    p1: CGPoint(x: w / 2, y: 0),
                    p2: CGPoint(x: 0, y: midY),
                    p3: CGPoint(x: w / 2, y: midY)
                )
                .fill(.white.opacity(0.58))

                // Sag alt
                Triangle(
                    p1: CGPoint(x: w / 2, y: h),
                    p2: CGPoint(x: w, y: midY),
                    p3: CGPoint(x: w / 2, y: midY)
                )
                .fill(.white.opacity(0.30))

                // Sol alt
                Triangle(
                    p1: CGPoint(x: w / 2, y: h),
                    p2: CGPoint(x: 0, y: midY),
                    p3: CGPoint(x: w / 2, y: midY)
                )
                .fill(.white.opacity(0.44))
            }
        }
    }
}

private struct Triangle: Shape {
    let p1: CGPoint
    let p2: CGPoint
    let p3: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: p1)
        path.addLine(to: p2)
        path.addLine(to: p3)
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 30) {
        SolviaLogo(size: 120)
        SolviaLogo(size: 64)
        HStack(spacing: 16) {
            SolviaLogo(size: 40)
            SolviaLogo(size: 28)
        }
    }
    .padding(40)
    .background(AppTheme.background)
}
