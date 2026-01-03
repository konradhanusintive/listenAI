//
//  ContentView.swift
//  ListenAI
//
//  Created by Konrad Hanus on 03/01/2026.
//

import SwiftUI
import AVFoundation

// MARK: - COLORS & CONSTANTS
extension Color {
    static let neonBlue = Color(red: 0.0, green: 1.0, blue: 1.0)
    static let neonPurple = Color(red: 0.8, green: 0.0, blue: 1.0)
    static let neonPink = Color(red: 1.0, green: 0.0, blue: 0.8)
    static let darkBackground = Color(red: 0.05, green: 0.05, blue: 0.1)
}

// MARK: - VISUALIZER
struct AudioVisualizerView: View {
    var audioLevel: Float
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<20) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(gradient: Gradient(colors: [.neonBlue, .neonPurple]), startPoint: .bottom, endPoint: .top))
                    .frame(width: 4, height: 10 + (CGFloat(audioLevel) * 200 * CGFloat.random(in: 0.5...1.5)))
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
        }
        .frame(height: 100)
        .shadow(color: .neonBlue.opacity(0.6), radius: 10, x: 0, y: 0)
    }
}

// MARK: - NEON BUTTON
struct NeonButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    var isLarge: Bool = false
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: isLarge ? 80 : 50, height: isLarge ? 80 : 50)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: 2)
                            .shadow(color: color, radius: 10)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: isLarge ? 30 : 20, weight: .bold))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.8), radius: 5)
            }
        }
    }
}

// MARK: - SETTINGS SHEET
struct SettingsSheet: View {
    @ObservedObject var speechManager: SpeechManager
    @Environment(\.dismiss) var dismiss
    
    let languages = [
        ("en", "Angielski"),
        ("pl", "Polski"),
        ("de", "Niemiecki"),
        ("es", "Hiszpański"),
        ("fr", "Francuski")
    ]
    
    var body: some View {
        ZStack {
            Color.darkBackground.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Text("USTAWIENIA")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(.neonBlue)
                    .shadow(color: .neonBlue, radius: 10)
                
                ScrollView {
                    VStack(spacing: 25) {
                        // LANGUAGE SETTINGS
                        VStack(alignment: .leading, spacing: 10) {
                            Text("JĘZYK ŹRÓDŁOWY (MOWA)")
                                .foregroundColor(.gray)
                                .font(.caption)
                            
                            Picker("Język Mowy", selection: $speechManager.sourceLanguage) {
                                ForEach(languages, id: \.0) { code, name in
                                    Text(name).tag(code)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("JĘZYK DOCELOWY (TŁUMACZENIE)")
                                .foregroundColor(.gray)
                                .font(.caption)
                            
                            Picker("Język Tłumaczenia", selection: $speechManager.targetLanguage) {
                                ForEach(languages, id: \.0) { code, name in
                                    Text(name).tag(code)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Divider().background(Color.gray)
                        
                        // VOICE SETTINGS
                        VStack(alignment: .leading, spacing: 10) {
                            Text("MODULATOR GŁOSU")
                                .foregroundColor(.gray)
                                .font(.caption)
                            
                            Text("PITCH (Tonacja): \(String(format: "%.1f", speechManager.pitch))")
                                .foregroundColor(.white)
                                .font(.headline)
                            Slider(value: $speechManager.pitch, in: 0.5...2.0, step: 0.1)
                                .accentColor(.neonPurple)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("RATE (Szybkość): \(String(format: "%.1f", speechManager.rate))")
                                .foregroundColor(.white)
                                .font(.headline)
                            Slider(value: $speechManager.rate, in: 0.25...1.0, step: 0.05)
                                .accentColor(.neonPink)
                        }
                    }
                    .padding()
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Text("ZAMKNIJ")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.neonBlue)
                        .cornerRadius(10)
                        .shadow(color: .neonBlue, radius: 10)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.top, 30)
        }
    }
}

// MARK: - MAIN CONTENT VIEW
struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @State private var showSettings = false
    @State private var animateBackground = false
    @State private var copiedToClipboard = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. DYNAMIC BACKGROUND
                LinearGradient(gradient: Gradient(colors: [Color.darkBackground, Color.black]), startPoint: animateBackground ? .topLeading : .bottomTrailing, endPoint: animateBackground ? .bottomTrailing : .topLeading)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        withAnimation(Animation.linear(duration: 5.0).repeatForever(autoreverses: true)) {
                            animateBackground.toggle()
                        }
                    }
                
                // Background Particles/Glow
                Circle()
                    .fill(Color.neonPurple.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -100, y: -200)
                
                Circle()
                    .fill(Color.neonBlue.opacity(0.1))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: 150, y: 300)

                
                VStack(spacing: 20) {
                    
                    // HEADER
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("ListenAI")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.5), radius: 10)
                            
                            // CONNECTION STATUS INDICATOR
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(speechManager.isConnected ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: speechManager.isConnected ? .green : .red, radius: 5)
                                
                                Text(speechManager.connectionStatus.uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(speechManager.isConnected ? .green : .red)
                            }
                        }
                        
                        Spacer()
                        
                        NeonButton(icon: "slider.horizontal.3", color: .neonBlue, action: {
                            showSettings = true
                        })
                    }
                    .padding(.horizontal)
                    .padding(.top, 40)
                    
                    // 2. AUDIO VISUALIZER
                    AudioVisualizerView(audioLevel: speechManager.audioLevel)
                        .opacity(speechManager.isRecording ? 1 : 0.3)
                    
                    // TEXT DISPLAY (GLASSMORPHISM)
                    ZStack(alignment: .topTrailing) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                Text(speechManager.transcript.isEmpty ? "Naciśnij mikrofon i mów..." : speechManager.transcript)
                                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("bottom")
                            }
                            .onChange(of: speechManager.transcript) { _ in
                                withAnimation {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }
                        }
                        .background(VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(LinearGradient(gradient: Gradient(colors: [.white.opacity(0.2), .clear]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                        
                        // TOOLBAR INSIDE TEXT AREA
                        VStack(spacing: 15) {
                            // COPY BUTTON
                            Button(action: {
                                UIPasteboard.general.string = speechManager.transcript
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                withAnimation {
                                    copiedToClipboard = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { copiedToClipboard = false }
                                }
                            }) {
                                Image(systemName: copiedToClipboard ? "checkmark.circle.fill" : "doc.on.doc")
                                    .foregroundColor(copiedToClipboard ? .green : .white.opacity(0.7))
                                    .font(.system(size: 20))
                            }
                            
                            // SHARE BUTTON
                            if !speechManager.transcript.isEmpty {
                                ShareLink(item: speechManager.transcript) {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(.white.opacity(0.7))
                                        .font(.system(size: 20))
                                }
                            }
                            
                            // RESET/TRASH BUTTON
                            Button(action: {
                                withAnimation {
                                    speechManager.reset()
                                }
                                let generator = UIImpactFeedbackGenerator(style: .heavy)
                                generator.impactOccurred()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.7))
                                    .font(.system(size: 20))
                            }
                        }
                        .padding()
                    }
                    .padding()
                    
                    if let errorMessage = speechManager.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(5)
                    }

                    // CONTROLS AREA
                    HStack(spacing: 40) {
                        // SPEAK AGAIN BUTTON
                        NeonButton(icon: "play.fill", color: .neonBlue, action: {
                            speechManager.speak(text: speechManager.transcript)
                        })
                        
                        // RECORD BUTTON (MAIN)
                        NeonButton(icon: speechManager.isRecording ? "stop.fill" : "mic.fill",
                                   color: speechManager.isRecording ? .red : .neonPurple,
                                   action: {
                            if speechManager.isRecording {
                                speechManager.stopRecording()
                            } else {
                                speechManager.startRecording()
                            }
                        }, isLarge: true)
                        .scaleEffect(speechManager.isRecording ? 1.1 : 1.0)
                        .animation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: speechManager.isRecording)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(speechManager: speechManager)
        }
        .preferredColorScheme(.dark)
    }
}

// HELPER FOR GLASSMORPHISM
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

#Preview {
    ContentView()
}