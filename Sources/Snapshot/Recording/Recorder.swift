import Cocoa
import ScreenCaptureKit
import AVFoundation

final class Recorder: NSObject, SCStreamOutput, SCStreamDelegate {
    static let shared = Recorder()

    // Main-thread state
    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var micAvailable = false
    private(set) var micMuted = false
    var onChange: (() -> Void)?

    private var stream: SCStream?
    private var stopping = false
    private var url: URL?
    private var frameWindow: NSWindow?
    private var controller: RecordingBar?
    private var startDate = Date()
    private var pausedTotal: TimeInterval = 0
    private var pauseBegan: Date?

    var elapsed: TimeInterval {
        let current = pauseBegan.map { Date().timeIntervalSince($0) } ?? 0
        return max(Date().timeIntervalSince(startDate) - pausedTotal - current, 0)
    }

    // Sample-queue state: only touched on `queue`
    private let queue = DispatchQueue(label: "snapshot.recorder")
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var started = false
    private var sessionStart = CMTime.zero
    private var audioFormat: CMFormatDescription?
    private var wantsMic = false
    private var qPaused = false
    private var qMuted = false
    private var offset = CMTime.zero
    private var pauseHostTime = CMTime.zero
    private var streamStart = Date()
    private var outputURL: URL?
    private var width = 0
    private var height = 0

    static func requestMic() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    func start(displayID: CGDirectDisplayID, rect: CGRect, scale: CGFloat) {
        guard !isRecording else { return }
        isRecording = true
        stopping = false
        Task { @MainActor in
            do {
                var mic = false
                if #available(macOS 15.0, *) { mic = await Recorder.requestMic() }
                micAvailable = mic
                micMuted = false
                isPaused = false

                let screen = NSScreen.screens.first { $0.displayID == displayID } ?? NSScreen.main
                if let screen = screen {
                    frameWindow = makeRecordingFrame(screen: screen, area: rect)
                    controller = RecordingBar(screen: screen, area: rect)
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
                let content = try await SCShareableContent.current
                guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
                    throw NSError(domain: "Snapshot", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display found."])
                }
                let hidden = [frameWindow?.windowNumber, controller?.windowNumber].compactMap { $0 }.map { CGWindowID($0) }
                let excluded = content.windows.filter { hidden.contains($0.windowID) }

                let w = max(Int(rect.width * scale) & ~1, 2), h = max(Int(rect.height * scale) & ~1, 2)
                let cfg = SCStreamConfiguration()
                cfg.sourceRect = rect
                cfg.width = w
                cfg.height = h
                cfg.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                cfg.pixelFormat = kCVPixelFormatType_32BGRA
                cfg.showsCursor = true
                cfg.queueDepth = 6
                if #available(macOS 15.0, *), mic { cfg.captureMicrophone = true }

                let url = Output.newURL(prefix: "Recording", ext: "mov")
                self.url = url
                queue.sync {
                    writer = nil
                    videoInput = nil
                    audioInput = nil
                    started = false
                    audioFormat = nil
                    wantsMic = mic
                    qPaused = false
                    qMuted = false
                    offset = .zero
                    streamStart = Date()
                    outputURL = url
                    width = w
                    height = h
                }

                let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: excluded), configuration: cfg, delegate: self)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
                if #available(macOS 15.0, *), mic {
                    try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
                }
                self.stream = stream
                try await stream.startCapture()
                startDate = Date()
                pausedTotal = 0
                pauseBegan = nil
                controller?.begin()
                onChange?()
            } catch {
                fail(error)
            }
        }
    }

    func togglePause() {
        guard isRecording, stream != nil else { return }
        if isPaused {
            pausedTotal += pauseBegan.map { Date().timeIntervalSince($0) } ?? 0
            pauseBegan = nil
            isPaused = false
            queue.sync {
                let gap = CMTimeSubtract(CMClockGetTime(CMClockGetHostTimeClock()), pauseHostTime)
                offset = CMTimeAdd(offset, gap)
                qPaused = false
            }
        } else {
            isPaused = true
            pauseBegan = Date()
            queue.sync {
                pauseHostTime = CMClockGetTime(CMClockGetHostTimeClock())
                qPaused = true
            }
        }
    }

    func toggleMic() {
        guard micAvailable else { return }
        micMuted.toggle()
        queue.sync { qMuted = micMuted }
    }

    func stop(discard: Bool = false) {
        guard isRecording, !stopping, let stream = stream else { return }
        stopping = true
        Task { @MainActor in
            try? await stream.stopCapture()
            let (writer, wasStarted): (AVAssetWriter?, Bool) = queue.sync {
                videoInput?.markAsFinished()
                audioInput?.markAsFinished()
                return (self.writer, started)
            }
            if wasStarted, let writer = writer {
                await writer.finishWriting()
            } else {
                writer?.cancelWriting()
            }
            let url = self.url
            reset()
            onChange?()
            guard let url = url else { return }
            let exists = FileManager.default.fileExists(atPath: url.path)
            if discard {
                try? FileManager.default.removeItem(at: url)
            } else if exists && wasStarted {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                showError("Nothing was recorded.")
            }
        }
    }

    private func reset() {
        isRecording = false
        isPaused = false
        stopping = false
        pauseBegan = nil
        frameWindow?.orderOut(nil)
        frameWindow = nil
        controller?.close()
        controller = nil
        stream = nil
        url = nil
    }

    private func showError(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Recording problem"
        alert.informativeText = text
        alert.runModal()
    }

    private func fail(_ error: Error) {
        reset()
        onChange?()
        showError(error.localizedDescription)
    }

    // MARK: Sample handling (runs on `queue`)

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        if type == .screen {
            handleVideo(sampleBuffer)
        } else if #available(macOS 15.0, *), type == .microphone {
            handleAudio(sampleBuffer)
        }
    }

    private func handleVideo(_ sb: CMSampleBuffer) {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete, !qPaused else { return }
        if !started {
            // Wait briefly for the first microphone buffer so the audio track can match its format.
            if wantsMic, audioFormat == nil, Date().timeIntervalSince(streamStart) < 1.5 { return }
            guard startWriter(at: CMSampleBufferGetPresentationTimeStamp(sb)) else { return }
        }
        guard let input = videoInput, writer?.status == .writing, input.isReadyForMoreMediaData, let out = retimed(sb) else { return }
        input.append(out)
    }

    private func handleAudio(_ sb: CMSampleBuffer) {
        if !started {
            if audioFormat == nil { audioFormat = CMSampleBufferGetFormatDescription(sb) }
            return
        }
        guard let input = audioInput, !qPaused, !qMuted, writer?.status == .writing, input.isReadyForMoreMediaData,
              let out = retimed(sb), CMTimeCompare(CMSampleBufferGetPresentationTimeStamp(out), sessionStart) >= 0 else { return }
        input.append(out)
    }

    private func startWriter(at pts: CMTime) -> Bool {
        guard let url = outputURL, let w = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return false }
        let vi = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        vi.expectsMediaDataInRealTime = true
        guard w.canAdd(vi) else { return false }
        w.add(vi)
        if wantsMic, let fmt = audioFormat, let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt)?.pointee {
            let ai = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: asbd.mSampleRate,
                AVNumberOfChannelsKey: Int(asbd.mChannelsPerFrame),
                AVEncoderBitRateKey: 96_000,
            ], sourceFormatHint: fmt)
            ai.expectsMediaDataInRealTime = true
            if w.canAdd(ai) { w.add(ai); audioInput = ai }
        }
        guard w.startWriting() else { return false }
        w.startSession(atSourceTime: pts)
        writer = w
        videoInput = vi
        sessionStart = pts
        started = true
        return true
    }

    /// Shifts a buffer's timestamps back by the total time spent paused so the video has no gap.
    private func retimed(_ sb: CMSampleBuffer) -> CMSampleBuffer? {
        if CMTimeCompare(offset, .zero) == 0 { return sb }
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sb, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count)
        var infos = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: count)
        CMSampleBufferGetSampleTimingInfoArray(sb, entryCount: count, arrayToFill: &infos, entriesNeededOut: &count)
        for i in infos.indices {
            infos[i].presentationTimeStamp = CMTimeSubtract(infos[i].presentationTimeStamp, offset)
            if infos[i].decodeTimeStamp.isValid { infos[i].decodeTimeStamp = CMTimeSubtract(infos[i].decodeTimeStamp, offset) }
        }
        var out: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sb, sampleTimingEntryCount: count,
                                              sampleTimingArray: &infos, sampleBufferOut: &out)
        return out
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { if self.isRecording { self.stop() } }
    }
}
