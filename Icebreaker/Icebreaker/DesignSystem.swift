// MARK: - Icebreaker Design System
// Glass Morphism & Apple-inspired UI Components

import SwiftUI

// MARK: - Color Extensions
extension Color {
    static let icebreakerPrimary = Color.cyan
    static let icebreakerSecondary = Color.blue
    static let icebreakerAccent = Color(red: 0, green: 1, blue: 0.8)
    
    // Glass morphism colors - enhanced for dark theme
    static let glassBackground = Color.white.opacity(0.1)
    static let glassBorder = Color.white.opacity(0.2)
    static let darkGlassBackground = Color.black.opacity(0.3)
    
    // Dark theme specific colors
    static let darkBackground = Color(red: 0.06, green: 0.06, blue: 0.14)
    static let darkSecondary = Color(red: 0.1, green: 0.1, blue: 0.16)
    static let darkAccent = Color(red: 0.06, green: 0.19, blue: 0.24)
}

// MARK: - Glass Morphism Modifier
struct GlassMorphism: ViewModifier {
    let intensity: Double
    let cornerRadius: CGFloat
    
    init(intensity: Double = 0.1, cornerRadius: CGFloat = 20) {
        self.intensity = intensity
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                Rectangle()
                    .fill(Color.white.opacity(intensity))
                    .background(.ultraThinMaterial.opacity(0.8))
                    .cornerRadius(cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .foregroundStyle(.primary) // Use adaptive colors
    }
}

extension View {
    func glassMorphism(intensity: Double = 0.1, cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassMorphism(intensity: intensity, cornerRadius: cornerRadius))
    }
}

// MARK: - Animated Background
struct AnimatedBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.06, blue: 0.14),
                Color(red: 0.1, green: 0.1, blue: 0.16),
                Color(red: 0.06, green: 0.19, blue: 0.24)
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
        .overlay(
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.cyan.opacity(0.1))
                        .frame(width: 80)
                        .offset(
                            x: animateGradient ? 50 : -50,
                            y: animateGradient ? 30 : -30
                        )
                        .animation(
                            .easeInOut(duration: Double.random(in: 4...8))
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.5),
                            value: animateGradient
                        )
                }
            }
        )
    }
}

// MARK: - Missing UI Components

// MARK: - Glass Card Component
struct GlassCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    
    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
    }
    
    var body: some View {
        content
            .padding(padding)
            .glassMorphism()
    }
}

// MARK: - Match Percentage Badge
struct MatchPercentageBadge: View {
    let percentage: Double
    let size: CGFloat
    
    private var color: Color {
        switch percentage {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        Text("\(Int(percentage))%")
            .font(.system(size: size * 0.3, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(color)
                    .shadow(color: color, radius: 4)
            )
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                .shadow(color: isActive ? .green : .orange, radius: 4)
            
            Text(isActive ? "Active now" : "Away")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Glass Button Style
struct GlassButtonStyle: ButtonStyle {
    let isSecondary: Bool
    
    init(isSecondary: Bool = false) {
        self.isSecondary = isSecondary
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isSecondary {
                        Color.white.opacity(0.1)
                    } else {
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .foregroundColor(isSecondary ? .white : .white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Glass TextField Style
struct GlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .offset(y: animationOffset)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = -4
        }
    }
}

// MARK: - Enhanced Radar Sweep View
struct RadarSweepView: View {
    @State private var sweepAngle: Double = 0
    let isActive: Bool
    
    var body: some View {
        ZStack {
            // Outer container with subtle glow
            Circle()
                .fill(Color.clear)
                .frame(width: 280, height: 280)
                .background(
                    Circle()
                        .fill(RadialGradient(
                            colors: [
                                Color.cyan.opacity(0.1),
                                Color.cyan.opacity(0.05),
                                Color.black.opacity(0.1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        ))
                )
                .overlay(
                    Circle()
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                )
                .overlay(
                    // Concentric circles
                    Group {
                        Circle()
                            .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                            .frame(width: 200, height: 200)
                        
                        Circle()
                            .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .stroke(Color.cyan.opacity(0.1), lineWidth: 1)
                            .frame(width: 40, height: 40)
                    }
                )
                .overlay(
                    // Gradient sweep fan (the blue gradient section you see in the image)
                    Path { path in
                        let center = CGPoint(x: 140, y: 140)
                        path.move(to: center)
                        path.addArc(
                            center: center,
                            radius: 140,
                            startAngle: .degrees(-30),
                            endAngle: .degrees(30),
                            clockwise: false
                        )
                        path.closeSubpath()
                    }
                    .fill(
                        AngularGradient(
                            colors: [
                                Color.clear,
                                Color.cyan.opacity(0.1),
                                Color.cyan.opacity(0.3),
                                Color.cyan.opacity(0.5),
                                Color.cyan.opacity(0.3),
                                Color.cyan.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startAngle: .degrees(-30),
                            endAngle: .degrees(30)
                        )
                    )
                    .rotationEffect(.degrees(sweepAngle), anchor: .center)
                    .opacity(isActive ? 0.8 : 0.3)
                )
                .overlay(
                    // Sweep line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.8),
                                    Color.cyan.opacity(0.4),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 140, height: 2)
                        .offset(x: 70)
                        .rotationEffect(.degrees(sweepAngle))
                        .opacity(isActive ? 0.6 : 1.0)
                )
        }
        .frame(width: 280, height: 280)
        .onAppear {
            if isActive {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    sweepAngle = 360
                }
            }
        }
    }
}

// MARK: - Preview
struct DesignSystemPreview: View {
    var body: some View {
        ZStack {
            AnimatedBackground()
            
            VStack(spacing: 20) {
                // Glass Card Example
                GlassCard {
                    VStack {
                        Text("Glass Morphism Card")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        StatusIndicator(isActive: true)
                    }
                }
                
                // Buttons
                HStack {
                    Button("Primary") {}
                        .buttonStyle(GlassButtonStyle())
                    
                    Button("Secondary") {}
                        .buttonStyle(GlassButtonStyle(isSecondary: true))
                }
                
                // Match Badge
                MatchPercentageBadge(percentage: 92, size: 50)
                
                // Radar
                RadarSweepView(isActive: true)
            }
            .padding()
        }
    }
}

#Preview {
    DesignSystemPreview()
}
