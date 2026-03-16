import AVFoundation
import Speech
import os

private let log = Logger(subsystem: "com.oceanmoon", category: "Speech")

@Observable
final class SpeechRecognitionService: @unchecked Sendable {
    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var currentText = ""
    private(set) var elapsedSeconds: TimeInterval = 0

    var onUtteranceFinalized: (@Sendable (String, TimeInterval) -> Void)?

    private var audioEngine = AVAudioEngine()
    // The audio tap always feeds into this reference — swapping it swaps the target
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))

    private var startTime: Date?
    private var timer: Timer?

    private var pauseTimer: Timer?
    private let pauseThreshold: TimeInterval = 2.0

    private var segmentText = ""
    private var activeTaskID: UUID?

    private let queue = DispatchQueue(label: "com.oceanmoon.speech", qos: .userInitiated)

    func requestAuthorization() async -> Bool {
        let micStatus = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        log.info("🎤 Mic: \(micStatus), Speech: \(speechStatus)")
        return micStatus && speechStatus
    }

    func start() {
        queue.async { [weak self] in self?.startOnQueue() }
    }

    func pause() {
        queue.async { [weak self] in
            guard let self, self.isRecording, !self.isPaused else { return }
            self.audioEngine.pause()
            DispatchQueue.main.async { self.isPaused = true }
            self.timer?.invalidate()
            self.pauseTimer?.invalidate()
        }
    }

    func resume() {
        queue.async { [weak self] in
            guard let self, self.isRecording, self.isPaused else { return }
            DispatchQueue.main.async { self.isPaused = false }
            try? self.audioEngine.start()
            self.startTimer()
        }
    }

    func stop() {
        queue.async { [weak self] in self?.stopOnQueue() }
    }

    // MARK: - Private

    private func startOnQueue() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            log.error("❌ SpeechRecognizer not available")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            if audioSession.isInputGainSettable {
                try audioSession.setInputGain(1.0)
            }
            if let input = audioSession.currentRoute.inputs.first {
                log.info("🎤 Input: \(input.portName)")
            }
        } catch {
            log.error("❌ Audio session: \(error.localizedDescription)")
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.startTime = Date()
            self?.elapsedSeconds = 0
            self?.isRecording = true
            self?.isPaused = false
            self?.currentText = ""
        }

        startTimer()

        // Install audio tap ONCE — it always feeds self.recognitionRequest
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            // This always points to whatever recognitionRequest is current
            self?.recognitionRequest?.append(buffer)
        }
        audioEngine.prepare()
        try? audioEngine.start()

        startNewSegment()
        log.info("✅ Started")
    }

    /// Create a new recognition request+task. Audio tap keeps running and feeds the new request.
    private func startNewSegment() {
        segmentText = ""
        let taskID = UUID()
        activeTaskID = taskID

        // 1. Create new request FIRST
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.requiresOnDeviceRecognition = false
        newRequest.addsPunctuation = true
        newRequest.taskHint = .dictation

        // 2. Swap the request — tap immediately starts feeding the new one
        let oldRequest = recognitionRequest
        let oldTask = recognitionTask
        recognitionRequest = newRequest

        // 3. End old task AFTER swap — no audio gap
        oldRequest?.endAudio()
        oldTask?.cancel()

        // 4. Start new recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: newRequest) { [weak self] result, error in
            guard let self, self.activeTaskID == taskID else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                self.segmentText = text

                DispatchQueue.main.async { [weak self] in
                    self?.currentText = text
                }

                if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                    self.resetPauseTimer()
                }

                if result.isFinal {
                    log.info("🗣️ [FINAL] \"\(text)\"")
                    self.finalizeAndStartNew()
                } else {
                    log.info("🗣️ \"\(text)\"")
                }
            }

            if let error {
                let code = (error as NSError).code
                if code == 216 || code == 301 { return }
                log.warning("⚠️ Error [\(code)]: \(error.localizedDescription)")
                self.finalizeAndStartNew()
            }
        }
    }

    private func finalizeAndStartNew() {
        pauseTimer?.invalidate()
        pauseTimer = nil

        let text = segmentText.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty {
            let offset = elapsedSeconds
            let callback = onUtteranceFinalized
            log.info("✅ Finalized: \"\(text)\"")

            DispatchQueue.main.async { [weak self] in
                callback?(text, offset)
                self?.currentText = ""
            }
        }

        guard isRecording, !isPaused else { return }
        startNewSegment()
    }

    private func resetPauseTimer() {
        pauseTimer?.invalidate()
        let timer = Timer(timeInterval: pauseThreshold, repeats: false) { [weak self] _ in
            guard let self, self.isRecording, !self.isPaused else { return }
            let text = self.segmentText.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return }
            log.info("⏱️ Pause detected")
            self.finalizeAndStartNew()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pauseTimer = timer
    }

    private func stopOnQueue() {
        log.info("🛑 Stopping")
        activeTaskID = nil
        timer?.invalidate()
        timer = nil
        pauseTimer?.invalidate()
        pauseTimer = nil

        let text = segmentText.trimmingCharacters(in: .whitespaces)
        let offset = elapsedSeconds
        let callback = onUtteranceFinalized

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        DispatchQueue.main.async { [weak self] in
            if !text.isEmpty {
                callback?(text, offset)
            }
            self?.isRecording = false
            self?.isPaused = false
            self?.currentText = ""
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        log.info("🛑 Stopped")
    }

    private func startTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self, let startTime = self.startTime else { return }
                self.elapsedSeconds = Date().timeIntervalSince(startTime)
            }
        }
    }
}
