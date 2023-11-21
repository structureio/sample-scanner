/*
 Copyright © 2022 XRPro, LLC. All rights reserved.
 http://structure.io
 */

import Foundation
import Structure

extension STMesh {
  func bbox() -> (SIMD3<Float>, SIMD3<Float>)? {
    guard self.meshVertices(0) != nil else {
      return nil
    }
    var minPoint = vector_float3(self.meshVertices(0)[0])
    var maxPoint = vector_float3(minPoint)

    for meshItr in 0..<self.numberOfMeshes() {
      let numVertices = Int(self.number(ofMeshVertices: meshItr))
      if let vertices = self.meshVertices(Int32(meshItr)) {
        for vertexItr in 0..<numVertices {
          let vertex = vertices[Int(vertexItr)]
          minPoint.x = min(minPoint.x, vertex.x)
          minPoint.y = min(minPoint.y, vertex.y)
          minPoint.z = min(minPoint.z, vertex.z)
          maxPoint.x = max(maxPoint.x, vertex.x)
          maxPoint.y = max(maxPoint.y, vertex.y)
          maxPoint.z = max(maxPoint.z, vertex.z)
        }
      }
    }
    return (minPoint, maxPoint)
  }
}
