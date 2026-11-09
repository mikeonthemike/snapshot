import Cocoa
import Vision

/// On-device text recognition for a screenshot region.
enum TextRecognizer {
    /// The recognised text, one line per row, in reading order. Empty if nothing was found.
    static func recognize(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                do {
                    try VNImageRequestHandler(cgImage: image).perform([request])
                    continuation.resume(returning: join(request.results ?? []))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func join(_ observations: [VNRecognizedTextObservation]) -> String {
        observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}

/// Recognises text in a region and puts it on the clipboard, with audible feedback.
enum TextCopier {
    static func copyText(from image: CGImage) {
        Task { @MainActor in
            let text = (try? await TextRecognizer.recognize(in: image)) ?? ""
            if text.isEmpty {
                NSSound.beep()
            } else {
                Pasteboard.copy(text: text)
                NSSound(named: "Pop")?.play()
            }
        }
    }
}
