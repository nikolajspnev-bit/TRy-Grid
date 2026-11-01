import AVFoundation
import Accelerate
import CoreImage
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var video: TryVideo?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TryVideo") {
      let channel = FlutterMethodChannel(name: "try_grid/video", binaryMessenger: registrar.messenger())
      let v = TryVideo()
      video = v
      channel.setMethodCallHandler { call, result in v.handle(call, result) }
    }
  }
}

// MARK: Video Bausteine für TRy Grid (Bilder lesen, MP4 schreiben)

enum TryVideoError: Error { case message(String) }

final class TryVideo {
  private let queue = DispatchQueue(label: "try_grid.video")
  private var readers: [Int: TryVideoReader] = [:]
  private var encoder: TryVideoEncoder?
  private var nextId = 1

  func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    queue.async {
      do {
        let value: Any?
        switch call.method {
        case "probe":
          value = try TryVideoReader.probe(path: args["path"] as! String)
        case "openReader":
          let id = self.nextId
          self.nextId += 1
          self.readers[id] = try TryVideoReader(path: args["path"] as! String, maxSide: args["maxSide"] as! Int)
          value = id
        case "frame":
          guard let r = self.readers[args["id"] as! Int] else { throw TryVideoError.message("Reader fehlt") }
          value = try r.frame(timeMs: (args["timeMs"] as! NSNumber).int64Value)
        case "closeReader":
          self.readers.removeValue(forKey: args["id"] as! Int)
          value = nil
        case "startEncoder":
          self.encoder = try TryVideoEncoder(
            path: args["path"] as! String,
            width: args["width"] as! Int,
            height: args["height"] as! Int,
            fps: args["fps"] as! Int,
            bitrate: args["bitrate"] as! Int)
          value = nil
        case "addFrame":
          guard let e = self.encoder else { throw TryVideoError.message("Encoder fehlt") }
          let data = args["rgba"] as! FlutterStandardTypedData
          try e.add(rgba: data.data)
          value = nil
        case "finishEncoder":
          guard let e = self.encoder else { throw TryVideoError.message("Encoder fehlt") }
          self.encoder = nil
          value = try e.finish()
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
          return
        }
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "video", message: "\(error)", details: nil))
        }
      }
    }
  }
}

final class TryVideoReader {
  private let asset: AVURLAsset
  private let track: AVAssetTrack
  private let maxSide: Int
  private let orientation: CGImagePropertyOrientation
  private let context = CIContext(options: [.cacheIntermediates: false])
  private var reader: AVAssetReader?
  private var output: AVAssetReaderTrackOutput?
  private var current: CMSampleBuffer?
  private var pending: CMSampleBuffer?
  private var lastTime: Int64 = -1

  static func probe(path: String) throws -> [String: Any] {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let track = asset.tracks(withMediaType: .video).first else {
      throw TryVideoError.message("Keine Videospur")
    }
    let size = track.naturalSize.applying(track.preferredTransform)
    return [
      "width": Int(abs(size.width).rounded()),
      "height": Int(abs(size.height).rounded()),
      "durationMs": Int64(CMTimeGetSeconds(asset.duration) * 1000),
    ]
  }

  init(path: String, maxSide: Int) throws {
    asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let t = asset.tracks(withMediaType: .video).first else {
      throw TryVideoError.message("Keine Videospur")
    }
    track = t
    self.maxSide = maxSide
    let m = t.preferredTransform
    if m.a == 0 && m.b == 1 && m.c == -1 && m.d == 0 {
      orientation = .right
    } else if m.a == 0 && m.b == -1 && m.c == 1 && m.d == 0 {
      orientation = .left
    } else if m.a == -1 && m.d == -1 {
      orientation = .down
    } else {
      orientation = .up
    }
  }

  private func start(at ms: Int64) throws {
    reader?.cancelReading()
    let r = try AVAssetReader(asset: asset)
    let o = AVAssetReaderTrackOutput(
      track: track,
      outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    o.alwaysCopiesSampleData = false
    r.add(o)
    r.timeRange = CMTimeRange(start: CMTime(value: max(0, ms - 100), timescale: 1000), duration: .positiveInfinity)
    r.startReading()
    reader = r
    output = o
    current = nil
    pending = nil
  }

  private func ms(_ s: CMSampleBuffer) -> Int64 {
    Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(s)) * 1000)
  }

  /// Bild, das zum Zeitpunkt [timeMs] zu sehen ist.
  func frame(timeMs: Int64) throws -> [String: Any] {
    if reader == nil || timeMs < lastTime { try start(at: timeMs) }
    lastTime = timeMs
    while true {
      let next: CMSampleBuffer?
      if let p = pending { next = p; pending = nil } else { next = output?.copyNextSampleBuffer() }
      guard let s = next else { break }
      if current != nil && ms(s) > timeMs { pending = s; break }
      current = s
      if ms(s) >= timeMs { break }
    }
    guard let s = current, let pb = CMSampleBufferGetImageBuffer(s) else {
      throw TryVideoError.message("Kein Bild bei \(timeMs) ms")
    }
    var img = CIImage(cvPixelBuffer: pb).oriented(orientation)
    let ext = img.extent
    let scale = min(1.0, Double(maxSide) / Double(max(ext.width, ext.height)))
    img = img.transformed(by: CGAffineTransform(translationX: -ext.origin.x, y: -ext.origin.y))
    if scale < 1 { img = img.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) }
    let w = max(1, Int((ext.width * scale).rounded()))
    let h = max(1, Int((ext.height * scale).rounded()))
    var bytes = Data(count: w * h * 4)
    bytes.withUnsafeMutableBytes { raw in
      context.render(
        img, toBitmap: raw.baseAddress!, rowBytes: w * 4,
        bounds: CGRect(x: 0, y: 0, width: w, height: h),
        format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
    }
    return ["width": w, "height": h, "rgba": FlutterStandardTypedData(bytes: bytes)]
  }

  deinit { reader?.cancelReading() }
}

final class TryVideoEncoder {
  private let writer: AVAssetWriter
  private let input: AVAssetWriterInput
  private let adaptor: AVAssetWriterInputPixelBufferAdaptor
  private let width: Int
  private let height: Int
  private let fps: Int32
  private let path: String
  private var index: Int64 = 0

  init(path: String, width: Int, height: Int, fps: Int, bitrate: Int) throws {
    self.path = path
    self.width = width
    self.height = height
    self.fps = Int32(fps)
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.removeItem(at: url)
    writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    input = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate],
    ])
    input.expectsMediaDataInRealTime = false
    adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: width,
      kCVPixelBufferHeightKey as String: height,
    ])
    writer.add(input)
    guard writer.startWriting() else {
      throw TryVideoError.message("Video konnte nicht starten: \(String(describing: writer.error))")
    }
    writer.startSession(atSourceTime: .zero)
  }

  func add(rgba: Data) throws {
    while !input.isReadyForMoreMediaData { usleep(2000) }
    guard let pool = adaptor.pixelBufferPool else { throw TryVideoError.message("Kein Puffer") }
    var pbOut: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOut)
    guard let pb = pbOut else { throw TryVideoError.message("Kein Puffer") }
    CVPixelBufferLockBaseAddress(pb, [])
    rgba.withUnsafeBytes { raw in
      var src = vImage_Buffer(
        data: UnsafeMutableRawPointer(mutating: raw.baseAddress!),
        height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
      var dst = vImage_Buffer(
        data: CVPixelBufferGetBaseAddress(pb)!,
        height: vImagePixelCount(height), width: vImagePixelCount(width),
        rowBytes: CVPixelBufferGetBytesPerRow(pb))
      // RGBA → BGRA
      let map: [UInt8] = [2, 1, 0, 3]
      vImagePermuteChannels_ARGB8888(&src, &dst, map, vImage_Flags(kvImageNoFlags))
    }
    CVPixelBufferUnlockBaseAddress(pb, [])
    if !adaptor.append(pb, withPresentationTime: CMTime(value: index, timescale: fps)) {
      throw TryVideoError.message("Bild konnte nicht geschrieben werden: \(String(describing: writer.error))")
    }
    index += 1
  }

  func finish() throws -> String {
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    if writer.status != .completed {
      throw TryVideoError.message("Video fehlerhaft: \(String(describing: writer.error))")
    }
    return path
  }
}
