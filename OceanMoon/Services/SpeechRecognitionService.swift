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
    private(set) var isModelLoaded = false
    private(set) var modelLoadingProgress = ""

    var onUtteranceFinalized: (@Sendable (String, TimeInterval) -> Void)?

    private var audioEngine = AVAudioEngine()
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var analyzerFormat: AVAudioFormat?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var converter: AVAudioConverter?

    private var startTime: Date?
    private var timer: Timer?

    private var pauseTimer: Timer?
    private let pauseThreshold: TimeInterval = 2.0
    private var currentSegmentText = ""

    private var analyzerTask: Task<Void, Never>?
    private var resultTask: Task<Void, Never>?

    func loadModel() async {
        guard !isModelLoaded else { return }

        DispatchQueue.main.async { [weak self] in
            self?.modelLoadingProgress = "音声モデルを準備中..."
        }

        do {
            let locale = Locale(identifier: "ja-JP")

            // Check if ja-JP is supported
            let supported = await SpeechTranscriber.supportedLocales
            let jaSupported = supported.contains { $0.identifier.hasPrefix("ja") }
            log.info("🗣️ ja-JP supported: \(jaSupported)")
            log.info("🗣️ Supported locales: \(supported.map { $0.identifier })")

            let t = SpeechTranscriber(
                locale: locale,
                preset: .progressiveTranscription
            )
            transcriber = t

            DispatchQueue.main.async { [weak self] in
                self?.isModelLoaded = true
                self?.modelLoadingProgress = ""
            }
            log.info("✅ SpeechTranscriber ready (ja-JP)")
        } catch {
            log.error("❌ Model load: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.modelLoadingProgress = "モデル読み込み失敗: \(error.localizedDescription)"
            }
        }
    }

    func requestAuthorization() async -> Bool {
        let micStatus = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        log.info("🎤 Mic: \(micStatus)")
        return micStatus
    }

    func start() {
        Task { await startAsync() }
    }

    func pause() {
        audioEngine.pause()
        timer?.invalidate()
        pauseTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            self?.isPaused = true
        }
    }

    func resume() {
        try? audioEngine.start()
        startTimer()
        DispatchQueue.main.async { [weak self] in
            self?.isPaused = false
        }
    }

    func stop() {
        log.info("🛑 Stopping")
        timer?.invalidate()
        timer = nil
        pauseTimer?.invalidate()
        pauseTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        inputBuilder?.finish()
        inputBuilder = nil

        let text = currentSegmentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            let offset = elapsedSeconds
            let callback = onUtteranceFinalized
            DispatchQueue.main.async { [weak self] in
                callback?(text, offset)
                self?.currentText = ""
            }
        }

        analyzerTask?.cancel()
        resultTask?.cancel()
        analyzerTask = nil
        resultTask = nil
        analyzer = nil

        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.isPaused = false
            self?.currentText = ""
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        log.info("🛑 Stopped")
    }

    // MARK: - Private

    private func startAsync() async {
        guard let transcriber else {
            log.error("❌ Transcriber not initialized")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .default, options: [])
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

        // Get compatible audio format
        if let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) {
            analyzerFormat = format
            log.info("🎵 Analyzer format: \(format.sampleRate)Hz \(format.channelCount)ch")
        } else {
            log.error("❌ No compatible audio format")
            return
        }

        // Create async stream for audio input
        let (inputSequence, builder) = AsyncStream<AnalyzerInput>.makeStream()
        inputBuilder = builder

        // Create analyzer
        let speechAnalyzer = SpeechAnalyzer(modules: [transcriber])
        analyzer = speechAnalyzer

        // Set up audio converter if needed
        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        log.info("🎵 Native format: \(nativeFormat.sampleRate)Hz \(nativeFormat.channelCount)ch")

        if let analyzerFormat, (nativeFormat.sampleRate != analyzerFormat.sampleRate || nativeFormat.channelCount != analyzerFormat.channelCount) {
            converter = AVAudioConverter(from: nativeFormat, to: analyzerFormat)
            log.info("🔄 Converter: \(nativeFormat.sampleRate)→\(analyzerFormat.sampleRate)Hz")
        } else {
            converter = nil
        }

        currentSegmentText = ""

        DispatchQueue.main.async { [weak self] in
            self?.startTime = Date()
            self?.elapsedSeconds = 0
            self?.isRecording = true
            self?.isPaused = false
            self?.currentText = ""
        }

        startTimer()

        // Listen for transcription results
        resultTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    let isFinal = result.isFinal

                    if isFinal {
                        log.info("🗣️ [FINAL] \"\(text)\"")
                        self.finalizeSegment(text: text)
                    } else {
                        log.info("🗣️ \"\(text)\"")
                        self.currentSegmentText = text
                        DispatchQueue.main.async { [weak self] in
                            self?.currentText = text
                        }
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            self.resetPauseTimer()
                        }
                    }
                }
                log.info("📊 Results stream ended")
            } catch {
                log.warning("⚠️ Results: \(error.localizedDescription)")
            }
        }

        // Install audio tap
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
            guard let self, let builder = self.inputBuilder else { return }

            if let converter = self.converter, let targetFormat = self.analyzerFormat {
                let ratio = targetFormat.sampleRate / nativeFormat.sampleRate
                let convertedFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: convertedFrameCount) else { return }

                var error: NSError?
                converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                builder.yield(AnalyzerInput(buffer: convertedBuffer))
            } else {
                builder.yield(AnalyzerInput(buffer: buffer))
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            log.info("✅ Audio engine started")
        } catch {
            log.error("❌ Audio engine: \(error.localizedDescription)")
            return
        }

        // Start analyzer (blocks until input ends)
        analyzerTask = Task {
            do {
                try await speechAnalyzer.start(inputSequence: inputSequence)
                log.info("📊 Analyzer finished")
            } catch {
                log.warning("⚠️ Analyzer: \(error.localizedDescription)")
            }
        }

        log.info("✅ Started (SpeechAnalyzer)")
    }

    private func finalizeSegment(text: String) {
        pauseTimer?.invalidate()
        pauseTimer = nil

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let offset = elapsedSeconds
        let callback = onUtteranceFinalized

        log.info("✅ Finalized: \"\(trimmed)\"")

        currentSegmentText = ""
        DispatchQueue.main.async { [weak self] in
            callback?(trimmed, offset)
            self?.currentText = ""
        }
    }

    private func resetPauseTimer() {
        pauseTimer?.invalidate()
        let timer = Timer(timeInterval: pauseThreshold, repeats: false) { [weak self] _ in
            guard let self, self.isRecording, !self.isPaused else { return }
            let text = self.currentSegmentText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            log.info("⏱️ Pause detected")
            self.finalizeSegment(text: text)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pauseTimer = timer
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
