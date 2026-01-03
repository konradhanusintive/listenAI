//
//  ContentView.swift
//  ListenAI
//
//  Created by Konrad Hanus on 03/01/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ListenAI - Mowa na Tekst")
                .font(.title)
                .fontWeight(.bold)
            
            ScrollView {
                Text(speechManager.transcript.isEmpty ? "Naciśnij guzik i mów..." : speechManager.transcript)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding()
            
            if let errorMessage = speechManager.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Button(action: {
                if speechManager.isRecording {
                    speechManager.stopRecording()
                } else {
                    speechManager.startRecording()
                }
            }) {
                Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(speechManager.isRecording ? .red : .blue)
                    .shadow(radius: 5)
            }
            .padding(.bottom, 30)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}