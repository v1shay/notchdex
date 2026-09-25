import AVFoundation
import Speech

final class VoiceDictationController {
    var onStateChange: ((Bool) -> Void)?
    var onTranscript: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var bestTranscript = ""
    private var desiredActive = false

    func begin() {
        desiredActive = true
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else { return }
            AVCaptureDevice.requestAccess(for: .audio) { allowed in
                guard allowed else { return }
                DispatchQueue.main.async {
                    guard self?.desiredActive == true else { return }
                    self?.startCapture()
                }
            }
        }
    }

    func end() {
        desiredActive = false
        guard engine.isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        onStateChange?(false)
        let captured = bestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !captured.isEmpty { onTranscript?(captured) }
        task?.cancel()
        task = nil
        request = nil
        bestTranscript = ""
    }

    private func startCapture() {
        guard !engine.isRunning, let recognizer, recognizer.isAvailable else { return }
        bestTranscript = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 13.0, *) { request.addsPunctuation = true }
        self.request = request

        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        engine.prepare()
        do {
            try engine.start()
            onStateChange?(true)
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                if let result { self?.bestTranscript = result.bestTranscription.formattedString }
                if error != nil { DispatchQueue.main.async { self?.end() } }
            }
        } catch {
            node.removeTap(onBus: 0)
            self.request = nil
        }
    }
}
