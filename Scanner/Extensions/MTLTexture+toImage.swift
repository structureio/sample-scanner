/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import Metal
import MetalKit

extension MTLTexture {

  func toImage() -> CGImage? {
    assert(self.pixelFormat == .bgra8Unorm)

    let width = self.width
    let height = self.height
    guard let bytes: UnsafeMutableRawPointer = malloc(width * height * 4) else { return nil }

    let rowBytes = self.width * 4
    self.getBytes(bytes, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)

    let selftureSize = self.width * self.height * 4
    let releaseMaskImagePixelData: CGDataProviderReleaseDataCallback = { (_: UnsafeMutableRawPointer?, data: UnsafeRawPointer, _: Int) -> Void in
      data.deallocate()
    }
    guard let provider = CGDataProvider(dataInfo: nil, data: bytes, size: selftureSize, releaseData: releaseMaskImagePixelData) else { return nil }

    let pColorSpace = CGColorSpaceCreateDeviceRGB()
    let rawBitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    let bitmapInfo: CGBitmapInfo = CGBitmapInfo(rawValue: rawBitmapInfo)
    let cgImageRef = CGImage(
      width: self.width,
      height: self.height,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: rowBytes,
      space: pColorSpace,
      bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: true,
      intent: CGColorRenderingIntent.defaultIntent)
    return cgImageRef
  }
}
