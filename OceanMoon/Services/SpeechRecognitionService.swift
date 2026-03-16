import AVFoundation
import Speech

@MainActor @Observable
final class SpeechRecognitionService {
    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var currentText = ""
    private(set) var elapsedSeconds: TimeInterval = 0

    var onUtteranceFinalized: ((String, TimeInterval) -> Void)?

    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))

    private var startTime: Date?
    private var timer: Timer?
    private var lastFinalizedText = ""

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func start() throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { throw SpeechError.requestCreationFailed }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.addsPunctuation = true

        startTime = Date()
        lastFinalizedText = ""
        elapsedSeconds = 0
        isRecording = true
        isPaused = false

        startTimer()
        startRecognitionTask(with: recognitionRequest)

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func pause() {
        guard isRecording, !isPaused else { return }
        isPaused = true
        audioEngine.pause()
        timer?.invalidate()
    }

    func resume() throws {
        guard isRecording, isPaused else { return }
        isPaused = false
        try audioEngine.start()
        startTimer()
    }

    func stop() {
        isRecording = false
        isPaused = false
        timer?.invalidate()
        timer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        if !currentText.isEmpty {
            let offset = elapsedSeconds
            onUtteranceFinalized?(currentText, offset)
            currentText = ""
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startRecognitionTask(with request: SFSpeechAudioBufferRecognitionRequest) {
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let fullText = result.bestTranscription.formattedString
                let newText = String(fullText.dropFirst(self.lastFinalizedText.count)).trimmingCharacters(in: .whitespaces)

                if result.isFinal {
                    if !newText.isEmpty {
                        let offset = self.elapsedSeconds
                        self.onUtteranceFinalized?(newText, offset)
                    }
                    self.lastFinalizedText = fullText
                    self.currentText = ""
                } else {
                    self.currentText = newText
                }
            }

            if error != nil && self.isRecording {
                self.restartRecognition()
            }
        }
    }

    private func restartRecognition() {
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)

        guard isRecording, !isPaused else { return }

        do {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = true
            recognitionRequest.addsPunctuation = true

            lastFinalizedText = ""
            startRecognitionTask(with: recognitionRequest)

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            stop()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let startTime = self.startTime else { return }
            self.elapsedSeconds = Date().timeIntervalSince(startTime)
        }
    }
}

enum SpeechError: LocalizedError {
    case recognizerUnavailable
    case requestCreationFailed

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "音声認識が利用できません。設定を確認してください。"
        case .requestCreationFailed:
            return "音声認識リクエストの作成に失敗しました。"
        }
    }
}
