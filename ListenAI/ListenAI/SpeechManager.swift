import Foundation
import Speech
import AVFoundation
import SwiftUI
import Accelerate

class SpeechManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate {
    // Localization
    @Published var sourceLanguage: String = "en" {
        didSet {
            if oldValue != sourceLanguage {
                setupRecognizer(localeID: mapLanguageToLocale(sourceLanguage))
                sendToBackend(text: transcript)
            }
        }
    }
    @Published var targetLanguage: String = "pl" {
        didSet {
            sendToBackend(text: transcript)
        }
    }
    
    // Core Audio & Speech
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    
    // Data Persistence
    private var history: [String] = [] {
        didSet {
            saveHistory()
        }
    }
    private var currentLiveText: String = ""
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var errorMessage: String?
    @Published var audioLevel: Float = 0.0
    
    // Server settings
    private let serverURL = URL(string: "https://reactblog.pl/listen-ai/index.php")!
    private var lastSendTime: Date = Date()
    private var sendWorkItem: DispatchWorkItem?
    
    // Connection status
    @Published var connectionStatus: String = "Oczekiwanie"
    @Published var isConnected: Bool = false
    
    // Voice settings (TTS)
    @Published var pitch: Float = 1.0
    @Published var rate: Float = 0.5
    @Published var volume: Float = 1.0
    
    override init() {
        super.init()
        loadHistory() // Load saved text on launch
        synthesizer.delegate = self
        setupRecognizer(localeID: "en-US")
        requestAuthorization()
        updateTranscript() // Show loaded text immediately
    }
    
    private func saveHistory() {
        UserDefaults.standard.set(history, forKey: "transcriptHistory")
    }
    
    private func loadHistory() {
        if let saved = UserDefaults.standard.stringArray(forKey: "transcriptHistory") {
            history = saved
        }
    }
    
    private func setupRecognizer(localeID: String) {
        if isRecording {
            stopRecording()
        }
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID))
        speechRecognizer?.delegate = self
    }
    
    private func mapLanguageToLocale(_ lang: String) -> String {
        switch lang {
        case "pl": return "pl-PL"
        case "en": return "en-US"
        case "de": return "de-DE"
        case "es": return "es-ES"
        case "fr": return "fr-FR"
        default: return "en-US"
        }
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized: break
                case .denied: self.errorMessage = "Odmówiono dostępu do rozpoznawania mowy."
                case .restricted: self.errorMessage = "Rozpoznawanie mowy jest ograniczone na tym urządzeniu."
                case .notDetermined: self.errorMessage = "Nie ustalono uprawnień."
                @unknown default: self.errorMessage = "Nieznany błąd uprawnień."
                }
            }
        }
    }
    
    // MARK: - State Management (Main Thread) 
    
    private func commitCurrentText() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.commitCurrentText() }
            return
        }
        
        if !currentLiveText.isEmpty {
            history.append(currentLiveText)
            currentLiveText = ""
            updateTranscript()
        }
    }
    
    private func updateTranscript() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.updateTranscript() }
            return
        }
        
        let allSegments = history + (currentLiveText.isEmpty ? [] : [currentLiveText])
        self.transcript = allSegments.joined(separator: "\n\n")
        self.sendToBackend(text: self.transcript)
    }
    
    func startRecording() {
        DispatchQueue.main.async {
            self._startRecordingInternal()
        }
    }
    
    private func _startRecordingInternal() {
        commitCurrentText()
        
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
        
        if #available(iOS 13, *) {
            if speechRecognizer?.supportsOnDeviceRecognition ?? false {
                recognitionRequest.requiresOnDeviceRecognition = true
            }
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                DispatchQueue.main.async {
                    self.currentLiveText = result.bestTranscription.formattedString
                    self.updateTranscript()
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self.isRecording = false
                    if isFinal {
                        self.commitCurrentText()
                    }
                    self.audioLevel = 0.0
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = UInt(buffer.frameLength)
            var rms: Float = 0
            vDSP_rmsqv(channelData, 1, &rms, frameLength)
            let normalized = min(max(rms * 10, 0), 1)
            DispatchQueue.main.async {
                self.audioLevel = normalized
            }
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
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
            self.commitCurrentText()
            self.speak(text: self.transcript)
        }
    }
    
    func reset() {
        DispatchQueue.main.async {
            self.transcript = ""
            self.history = [] // This triggers didSet -> saveHistory (clears UserDefaults)
            self.currentLiveText = ""
            self.audioLevel = 0.0
            self.sendToBackend(text: "")
        }
    }
    
    func speak(text: String) {
        guard !text.isEmpty else { return }
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default)
        try? audioSession.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: mapLanguageToLocale(sourceLanguage))
        utterance.pitchMultiplier = pitch
        utterance.rate = rate
        utterance.volume = volume
        
        synthesizer.speak(utterance)
    }
    
    private func sendToBackend(text: String) {
        sendWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.connectionStatus = "Wysyłanie..."
            }
            
            var request = URLRequest(url: self.serverURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 5
            
            let body: [String: Any] = [
                "text": text,
                "sourceLang": self.sourceLanguage,
                "targetLang": self.targetLanguage
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Błąd wysyłania: \(error.localizedDescription)")
                        self.connectionStatus = "Błąd sieci"
                        self.isConnected = false
                    } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        self.connectionStatus = "Wysłano"
                        self.isConnected = true
                    } else {
                        self.connectionStatus = "Błąd serwera"
                        self.isConnected = false
                    }
                }
            }.resume()
        }
        
        sendWorkItem = workItem
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
}
