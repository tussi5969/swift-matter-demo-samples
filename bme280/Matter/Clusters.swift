//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors.
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

protocol MatterCluster {
  var cluster: UnsafeMutablePointer<esp_matter.cluster_t> { get }

  init(_ cluster: UnsafeMutablePointer<esp_matter.cluster_t>)
}

extension MatterCluster {
  init?(endpoint: some MatterEndpoint, id: UInt32) {
    guard let cluster = esp_matter.cluster.get_shim(endpoint.endpoint, id)
    else {
      return nil
    }
    self.init(cluster)
  }
}

protocol MatterConcreteCluster: MatterCluster {
  static var clusterTypeId: ClusterID<Self> { get }
}

struct ClusterID<Cluster: MatterCluster>: RawRepresentable {
  var rawValue: UInt32

  static var identify: ClusterID<Identify> { .init(rawValue: 0x0000_0003) }
  static var temperature: ClusterID<Temperature> {
    .init(rawValue: 0x0000_0402)
  }
  static var humidity: ClusterID<Humidity> {
    .init(rawValue: 0x0000_0405)
  }
  static var pressure: ClusterID<Pressure> {
    .init(rawValue: 0x0000_0403)
  }
}

struct Cluster: MatterCluster {
  var cluster: UnsafeMutablePointer<esp_matter.cluster_t>

  init(_ cluster: UnsafeMutablePointer<esp_matter.cluster_t>) {
    self.cluster = cluster
  }

  func `as`<T: MatterConcreteCluster>(_ type: T.Type) -> T? {
    let expected = T.clusterTypeId
    let id = esp_matter.cluster.get_id(cluster)
    if id == expected.rawValue {
      return T(cluster)
    }
    return nil
  }
}

struct Identify: MatterConcreteCluster {
  static var clusterTypeId: ClusterID<Self> { .identify }
  struct AttributeID<Attribute: MatterAttribute>: MatterAttributeID {
    var rawValue: UInt32
  }

  var cluster: UnsafeMutablePointer<esp_matter.cluster_t>

  init(_ cluster: UnsafeMutablePointer<esp_matter.cluster_t>) {
    self.cluster = cluster
  }

  func attribute<Attribute: MatterAttribute>(_ id: AttributeID<Attribute>)
    -> Attribute
  {
    Attribute(attribute: esp_matter.attribute.get_shim(cluster, id.rawValue))
  }
}

struct Temperature: MatterConcreteCluster {
  static var clusterTypeId: ClusterID<Self> { .temperature }
  struct AttributeID<Attribute: MatterAttribute>: MatterAttributeID {
    var rawValue: UInt32

    static var measuredValue: AttributeID<MeasuredValue> {
      .init(rawValue: 0x0000_0000)
    }
  }

  var cluster: UnsafeMutablePointer<esp_matter.cluster_t>

  init(_ cluster: UnsafeMutablePointer<esp_matter.cluster_t>) {
    self.cluster = cluster
  }

  func attribute<Attribute: MatterAttribute>(_ id: AttributeID<Attribute>)
    -> Attribute
  {
    Attribute(attribute: esp_matter.attribute.get_shim(cluster, id.rawValue))
  }

  var measuredValue: MeasuredValue { attribute(.measuredValue) }
}

struct Humidity: MatterConcreteCluster {
  static var clusterTypeId: ClusterID<Self> { .humidity }
  struct AttributeID<Attribute: MatterAttribute>: MatterAttributeID {
    var rawValue: UInt32

    static var measuredValue: AttributeID<MeasuredValue> {
      .init(rawValue: 0x0000_0000)
    }
  }

  var cluster: UnsafeMutablePointer<esp_matter.cluster_t>

  init(_ cluster: UnsafeMutablePointer<esp_matter.cluster_t>) {
    self.cluster = cluster
  }

  func attribute<Attribute: MatterAttribute>(_ id: AttributeID<Attribute>)
    -> Attribute
  {
    Attribute(attribute: esp_matter.attribute.get_shim(cluster, id.rawValue))
  }

  var measuredValue: MeasuredValue { attribute(.measuredValue) }
}

struct Pressure: MatterConcreteCluster {
  static var clusterTypeId: ClusterID<Self> { .pressure }
  struct AttributeID<Attribute: MatterAttribute>: MatterAttributeID {
    var rawValue: UInt32

    static var measuredValue: AttributeID<MeasuredValue> {
      .init(rawValue: 0x0000_0000)
    }
  }

  var cluster: UnsafeMutablePointer<esp_matter.cluster_t>

  init(_ cluster: UnsafeMutablePointer<esp_matter.cluster_t>) {
    self.cluster = cluster
  }

  func attribute<Attribute: MatterAttribute>(_ id: AttributeID<Attribute>)
    -> Attribute
  {
    Attribute(attribute: esp_matter.attribute.get_shim(cluster, id.rawValue))
  }

  var measuredValue: MeasuredValue { attribute(.measuredValue) }
}

