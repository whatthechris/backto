import SwiftUI

struct LaunchScreenView: View {
    @State private var animate = false
    private let ringCount = 3
    private let duration: Double = 1.8

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    ForEach(0..<ringCount, id: \.self) { i in
                        Circle()
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 80, height: 80)
                            .scaleEffect(animate ? 3.5 : 1)
                            .opacity(animate ? 0 : 0.8)
                            .animation(
                                .easeOut(duration: duration)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * duration / Double(ringCount)),
                                value: animate
                            )
                    }

                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 14, height: 14)
                        .shadow(color: .accentColor.opacity(0.6), radius: 8)
                }
                .frame(width: 80, height: 80)

                Text("BackTo")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .onAppear { animate = true }
    }
}
