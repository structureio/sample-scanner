/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import Foundation
import Structure
import StructureKit

extension STMesh: STKMesh {
}

extension STColorFrame: STKColorFrame {
}

extension STIntrinsics: STKIntrinsics {
}

extension STDepthFrame: STKDepthFrame {
  public func intrinsics() -> STKIntrinsics {
    let intrinsics: STIntrinsics = self.intrinsics()
    return intrinsics
  }
}
