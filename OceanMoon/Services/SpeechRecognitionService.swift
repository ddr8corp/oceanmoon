import AVFoundation
import WhisperKit
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
    private var whisperKit: WhisperKit?

    private var startTime: Date?
    private var timer: Timer?

    // Chunk-based: accumulate audio, transcribe when chunk is ready, clear buffer
    private var audioSamples: [Float] = []
    private var chunkTimer: Timer?
    private let chunkDuration: TimeInterval = 5.0  // Process every 5 seconds
    private var isTranscribing = false

    private let queue = DispatchQueue(label: "com.oceanmoon.speech", qos: .userInitiated)

    func loadModel() async {
        guard !isModelLoaded else { return }

        DispatchQueue.main.async { [weak self] in
            self?.modelLoadingProgress = "モデルをダウンロード中...(初回は数分かかります)"
        }

        do {
            let config = WhisperKitConfig(
                model: "small",
                computeOptions: ModelComputeOptions(
                    audioEncoderCompute: .cpuAndGPU,
                    textDecoderCompute: .cpuAndGPU
                )
            )
            let kit = try await WhisperKit(config)
            whisperKit = kit

            DispatchQueue.main.async { [weak self] in
                self?.isModelLoaded = true
                self?.modelLoadingProgress = ""
            }
            log.info("✅ WhisperKit model loaded (large-v3)")
        } catch {
            log.error("❌ WhisperKit load: \(error.localizedDescription)")
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
        queue.async { [weak self] in self?.startOnQueue() }
    }

    func pause() {
        queue.async { [weak self] in
            guard let self, self.isRecording, !self.isPaused else { return }
            self.audioEngine.pause()
            self.chunkTimer?.invalidate()
            DispatchQueue.main.async { self.isPaused = true }
            self.timer?.invalidate()
        }
    }

    func resume() {
        queue.async { [weak self] in
            guard let self, self.isRecording, self.isPaused else { return }
            DispatchQueue.main.async { self.isPaused = false }
            try? self.audioEngine.start()
            self.startTimer()
            self.startChunkTimer()
        }
    }

    func stop() {
        queue.async { [weak self] in self?.stopOnQueue() }
    }

    // MARK: - Private

    private func startOnQueue() {
        guard whisperKit != nil else {
            log.error("❌ WhisperKit not loaded")
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

        audioSamples.removeAll()
        isTranscribing = false

        DispatchQueue.main.async { [weak self] in
            self?.startTime = Date()
            self?.elapsedSeconds = 0
            self?.isRecording = true
            self?.isPaused = false
            self?.currentText = ""
        }

        startTimer()

        // Capture audio at 16kHz mono
        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

        guard let converter = AVAudioConverter(from: nativeFormat, to: targetFormat) else {
            log.error("❌ Cannot create audio converter")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
            guard let self else { return }

            let ratio = targetFormat.sampleRate / nativeFormat.sampleRate
            let convertedFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: convertedFrameCount) else { return }

            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if let data = convertedBuffer.floatChannelData?[0] {
                let samples = Array(UnsafeBufferPointer(start: data, count: Int(convertedBuffer.frameLength)))
                self.queue.async {
                    self.audioSamples.append(contentsOf: samples)
                }
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

        startChunkTimer()
        log.info("✅ Started (WhisperKit, chunk=\(self.chunkDuration)s)")
    }

    private func startChunkTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.chunkTimer?.invalidate()
            self.chunkTimer = Timer.scheduledTimer(withTimeInterval: self.chunkDuration, repeats: true) { [weak self] _ in
                guard let self, self.isRecording, !self.isPaused, !self.isTranscribing else { return }
                Task {
                    await self.processChunk()
                }
            }
        }
    }

    private func processChunk() async {
        guard let whisperKit else { return }

        // Grab and clear the buffer atomically
        let samples: [Float] = queue.sync {
            let s = self.audioSamples
            self.audioSamples.removeAll()
            return s
        }

        // Need at least 0.5s of audio
        guard samples.count > 8000 else {
            log.info("⏭️ Chunk too short (\(samples.count) samples), skipping")
            return
        }

        isTranscribing = true
        let duration = Double(samples.count) / 16000.0
        log.info("📝 Processing chunk: \(String(format: "%.1f", duration))s (\(samples.count) samples)")

        do {
            let options = DecodingOptions(
                language: "ja",
                temperature: 0.0,
                suppressBlank: true
            )

            let results = try await whisperKit.transcribe(
                audioArray: samples,
                decodeOptions: options
            )

            if let result = results.first {
                let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

                // Filter out Whisper hallucinations
                let isHallucination = text.isEmpty
                    || text == "(音楽)"
                    || text == "ご視聴ありがとうございました"
                    || text.hasPrefix("(")
                    || text.count <= 1

                if !isHallucination {
                    let offset = elapsedSeconds
                    let callback = onUtteranceFinalized
                    log.info("✅ \"\(text)\"")

                    DispatchQueue.main.async { [weak self] in
                        callback?(text, offset)
                        self?.currentText = ""
                    }
                } else {
                    log.info("🚫 Filtered hallucination: \"\(text)\"")
                }
            }
        } catch {
            log.warning("⚠️ Transcribe: \(error.localizedDescription)")
        }

        isTranscribing = false
    }

    private func stopOnQueue() {
        log.info("🛑 Stopping")
        timer?.invalidate()
        timer = nil
        chunkTimer?.invalidate()
        chunkTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Process remaining audio
        if !audioSamples.isEmpty {
            let remaining = audioSamples
            audioSamples.removeAll()
            if remaining.count > 8000, let whisperKit {
                Task {
                    do {
                        let options = DecodingOptions(language: "ja", temperature: 0.0, suppressBlank: true)
                        let results = try await whisperKit.transcribe(audioArray: remaining, decodeOptions: options)
                        if let text = results.first?.text.trimmingCharacters(in: .whitespacesAndNewlines),
                           !text.isEmpty, text != "(音楽)" {
                            let offset = self.elapsedSeconds
                            let callback = self.onUtteranceFinalized
                            DispatchQueue.main.async { [weak self] in
                                callback?(text, offset)
                                self?.isRecording = false
                                self?.isPaused = false
                                self?.currentText = ""
                            }
                            return
                        }
                    } catch {}
                    DispatchQueue.main.async { [weak self] in
                        self?.isRecording = false
                        self?.isPaused = false
                        self?.currentText = ""
                    }
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.isRecording = false
                    self?.isPaused = false
                    self?.currentText = ""
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isRecording = false
                self?.isPaused = false
                self?.currentText = ""
            }
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
