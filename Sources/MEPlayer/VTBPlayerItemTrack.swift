//
//  VTBPlayerItemTrack.swift
//  KSPlayer
//
//  Created by kintan on 2018/3/10.
//

import ffmpeg
import VideoToolbox

class DecompressionSession {
    fileprivate let isConvertNALSize: Bool
    fileprivate let formatDescription: CMFormatDescription
    fileprivate let decompressionSession: VTDecompressionSession

    private static func open(codecpar: AVCodecParameters, options: KSOptions) -> Bool {
        if codecpar.codec_id == AV_CODEC_ID_H264, options.hardwareDecodeH264 {
            return true
        } else if codecpar.codec_id == AV_CODEC_ID_HEVC, #available(iOS 11.0, tvOS 11.0, OSX 10.13, *), VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC), options.hardwareDecodeH265 {
            return true
        }
        return false
    }

    init?(codecpar: AVCodecParameters, options: KSOptions) {
        guard DecompressionSession.open(codecpar: codecpar, options: options),
            codecpar.format == AV_PIX_FMT_YUV420P.rawValue,
            let extradata = codecpar.extradata else {
            return nil
        }
        let extradataSize = codecpar.extradata_size
        guard extradataSize >= 7, extradata[0] == 1 else {
            return nil
        }

        if extradata[4] == 0xFE {
            extradata[4] = 0xFF
            isConvertNALSize = true
        } else {
            isConvertNALSize = false
        }
        let dic: NSMutableDictionary = [
            kCVImageBufferChromaLocationBottomFieldKey: "left",
            kCVImageBufferChromaLocationTopFieldKey: "left",
            kCMFormatDescriptionExtension_FullRangeVideo: options.bufferPixelFormatType != kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: [
                codecpar.codec_id.rawValue == AV_CODEC_ID_HEVC.rawValue ? "hvcC" : "avcC": NSData(bytes: extradata, length: Int(extradataSize)),
            ],
        ]
        if let aspectRatio = codecpar.aspectRatio {
            dic[kCVImageBufferPixelAspectRatioKey] = aspectRatio
        }
        if codecpar.color_space == AVCOL_SPC_BT709 {
            dic[kCMFormatDescriptionExtension_YCbCrMatrix] = kCMFormatDescriptionColorPrimaries_ITU_R_709_2
        }
        // codecpar.pointee.color_range == AVCOL_RANGE_JPEG kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        let type = codecpar.codec_id.rawValue == AV_CODEC_ID_HEVC.rawValue ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264
        // swiftlint:disable line_length
        var description: CMFormatDescription?
        var status = CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: type, width: codecpar.width, height: codecpar.height, extensions: dic, formatDescriptionOut: &description)
        // swiftlint:enable line_length
        guard status == noErr, let formatDescription = description else {
            return nil
        }
        self.formatDescription = formatDescription
        let attributes: NSDictionary = [
            kCVPixelBufferPixelFormatTypeKey: options.bufferPixelFormatType,
            kCVPixelBufferWidthKey: codecpar.width,
            kCVPixelBufferHeightKey: codecpar.height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
        ]
        var session: VTDecompressionSession?
        // swiftlint:disable line_length
        status = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault, formatDescription: formatDescription, decoderSpecification: nil, imageBufferAttributes: attributes, outputCallback: nil, decompressionSessionOut: &session)
        // swiftlint:enable line_length
        guard status == noErr, let decompressionSession = session else {
            return nil
        }
        self.decompressionSession = decompressionSession
    }

    deinit {
        VTDecompressionSessionWaitForAsynchronousFrames(decompressionSession)
        VTDecompressionSessionInvalidate(decompressionSession)
    }
}

final class VTBPlayerItemTrack: AsyncPlayerItemTrack<VideoVTBFrame> {
    private var session: DecompressionSession?
    // 刷新Session的话，后续的解码还是会失败，直到遇到I帧
    private var refreshSession = false
    required init(track: TrackProtocol, options: KSOptions, session: DecompressionSession) {
        super.init(track: track, options: options)
        self.session = session
    }

    required init(track _: TrackProtocol, options _: KSOptions) {
        fatalError("init(track:options:) has not been implemented")
    }

    override func doDecode(packet: Packet) throws -> [VideoVTBFrame] {
        let corePacket = packet.corePacket
        guard let data = corePacket.pointee.data, let session = session else {
            return []
        }
        let sampleBuffer = try session.formatDescription.getSampleBuffer(isConvertNALSize: session.isConvertNALSize, data: data, size: Int(corePacket.pointee.size))
        if refreshSession, corePacket.pointee.flags & AV_PKT_FLAG_KEY == 1 {
            refreshSession = false
        }
        var result = [VideoVTBFrame]()
        var error: NSError?
        let status = VTDecompressionSessionDecodeFrame(session.decompressionSession, sampleBuffer: sampleBuffer, flags: VTDecodeFrameFlags(rawValue: 0), infoFlagsOut: nil) { status, _, imageBuffer, _, _ in
            if status == noErr {
                if let imageBuffer = imageBuffer {
                    let frame = VideoVTBFrame()
                    frame.corePixelBuffer = imageBuffer
                    frame.timebase = self.track.timebase
                    frame.position = corePacket.pointee.pts
                    if frame.position == Int64.min || frame.position < 0 {
                        frame.position = max(corePacket.pointee.dts, 0)
                    }
                    frame.duration = corePacket.pointee.duration
                    frame.size = Int64(corePacket.pointee.size)
                    result.append(frame)
                }
            } else {
                if !self.refreshSession {
                    error = .init(result: status, errorCode: .codecVideoReceiveFrame)
                }
            }
        }
        if let error = error {
            throw error
        } else {
            if status == kVTInvalidSessionErr || status == kVTVideoDecoderMalfunctionErr {
                // 解决从后台切换到前台，解码失败的问题
                self.session = DecompressionSession(codecpar: codecpar.pointee, options: options)
                refreshSession = true
            } else if status != noErr {
                throw NSError(result: status, errorCode: .codecVideoReceiveFrame)
            }
            return result
        }
    }

    override func doFlushCodec() {
        super.doFlushCodec()
        session = DecompressionSession(codecpar: codecpar.pointee, options: options)
    }

    override func shutdown() {
        super.shutdown()
        session = nil
    }
}

extension CMFormatDescription {
    fileprivate func getSampleBuffer(isConvertNALSize: Bool, data: UnsafeMutablePointer<UInt8>, size: Int) throws -> CMSampleBuffer {
        if isConvertNALSize {
            var ioContext: UnsafeMutablePointer<AVIOContext>?
            let status = avio_open_dyn_buf(&ioContext)
            if status == 0 {
                var nalSize: UInt32 = 0
                let end = data + size
                var nalStart = data
                while nalStart < end {
                    nalSize = UInt32(UInt32(nalStart[0]) << 16 | UInt32(nalStart[1]) << 8 | UInt32(nalStart[2]))
                    avio_wb32(ioContext, nalSize)
                    nalStart += 3
                    avio_write(ioContext, nalStart, Int32(nalSize))
                    nalStart += Int(nalSize)
                }
                var demuxBuffer: UnsafeMutablePointer<UInt8>?
                let demuxSze = avio_close_dyn_buf(ioContext, &demuxBuffer)
                return try createSampleBuffer(data: demuxBuffer, size: Int(demuxSze))
            } else {
                throw NSError(result: status, errorCode: .codecVideoReceiveFrame)
            }
        } else {
            return try createSampleBuffer(data: data, size: size)
        }
    }

    private func createSampleBuffer(data: UnsafeMutablePointer<UInt8>?, size: Int) throws -> CMSampleBuffer {
        var blockBuffer: CMBlockBuffer?
        var sampleBuffer: CMSampleBuffer?
        // swiftlint:disable line_length
        var status = CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: data, blockLength: size, blockAllocator: kCFAllocatorNull, customBlockSource: nil, offsetToData: 0, dataLength: size, flags: 0, blockBufferOut: &blockBuffer)
        if status == noErr {
            status = CMSampleBufferCreate(allocator: nil, dataBuffer: blockBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: self, sampleCount: 1, sampleTimingEntryCount: 0, sampleTimingArray: nil, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sampleBuffer)
            if let sampleBuffer = sampleBuffer {
                return sampleBuffer
            }
        }
        throw NSError(result: status, errorCode: .codecVideoReceiveFrame)
        // swiftlint:enable line_length
    }
}
