import SwiftUI

struct RadarView: View {
    @State private var animate = false

    private let ringCount = 4
    private let duration: Double = 16.0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size.width * 1.1
            ZStack {
                ForEach(0..<ringCount, id: \.self) { i in
                    Circle()
                        .stroke(Color.blue, lineWidth: 1.5)
                        .fill(
                            RadialGradient(
                                colors: [Color.blue.opacity(0.5), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: size / 2
                            )
                        )
                        .frame(width: size, height: size)
                        .scaleEffect(animate ? 1 : 0.02)
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeOut(duration: duration)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * duration / Double(ringCount)),
                            value: animate
                        )
                }

                // Center blip
                Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
                    .shadow(color: .blue, radius: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { animate = true }
    }
}
