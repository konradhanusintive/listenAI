import Foundation
import Speech
import AVFoundation
import SwiftUI

class SpeechManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "pl-PL")) // Polish locale based on user language
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var errorMessage: String?
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
        synthesizer.delegate = self
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    break
                case .denied:
                    self.errorMessage = "Odmówiono dostępu do rozpoznawania mowy."
                case .restricted:
                    self.errorMessage = "Rozpoznawanie mowy jest ograniczone na tym urządzeniu."
                case .notDetermined:
                    self.errorMessage = "Nie ustalono uprawnień."
                @unknown default:
                    self.errorMessage = "Nieznany błąd uprawnień."
                }
            }
        }
    }
    
    func startRecording() {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Nie udało się skonfigurować sesji audio: \(error.localizedDescription)"
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Nie można utworzyć żądania rozpoznawania."
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Keep the speech recognition data on device for privacy and speed if available (iOS 13+)
        if #available(iOS 13, *) {
            if speechRecognizer?.supportsOnDeviceRecognition ?? false {
                recognitionRequest.requiresOnDeviceRecognition = true
            }
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                self.transcript = result.bestTranscription.formattedString
                isFinal = result.isFinal
                
                // Real-time TTS trigger could go here if "immediately" means echoing words,
                // but usually that creates a feedback loop.
                // We will stick to STT for now as per "pisze" (writes).
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isRecording = false
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            errorMessage = nil
        } catch {
            errorMessage = "Nie udało się uruchomić silnika audio."
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
        
        // Auto-speak functionality if desired "zamienia tekst na mowę" after listening
        speak(text: transcript)
    }
    
    func speak(text: String) {
        guard !text.isEmpty else { return }
        
        // Ensure audio session is set to playback for speaking
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default)
        try? audioSession.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "pl-PL")
        utterance.rate = 0.5
        
        synthesizer.speak(utterance)
    }
}
