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

protocol MatterNode {
  var node: UnsafeMutablePointer<esp_matter.node_t> { get }
}

protocol MatterEndpoint {
  var endpoint: UnsafeMutablePointer<esp_matter.endpoint_t> { get }
}

protocol MatterConreteEndpoint: MatterEndpoint {
  static var deviceTypeId: UInt32 { get }

  init(_ endpoint: UnsafeMutablePointer<esp_matter.endpoint_t>)
}

extension MatterEndpoint {
  var id: UInt16 { esp_matter.endpoint.get_id(endpoint) }

  func cluster<Cluster: MatterCluster>(_ id: ClusterID<Cluster>) -> Cluster {
    Cluster(esp_matter.cluster.get_shim(endpoint, id.rawValue))
  }
}

struct RootNode: MatterNode {
  typealias AttributeCallback = (
    MatterAttributeEvent, Endpoint, Cluster, UInt32,
    UnsafeMutablePointer<esp_matter_attr_val_t>?
  ) -> Void
  typealias IdentifyCallback = (
    esp_matter.identification.callback_type_t, UInt16, UInt8, UInt8
  ) -> Void

  final class Context {
    var attribute: AttributeCallback
    var identify: IdentifyCallback

    init(
      attribute: @escaping AttributeCallback,
      identify: @escaping IdentifyCallback
    ) {
      self.attribute = attribute
      self.identify = identify
    }
  }

  var node: UnsafeMutablePointer<esp_matter.node_t>
  let context: Context

  init?(
    attribute: @escaping AttributeCallback, identify: @escaping IdentifyCallback
  ) {
    var nodeConfig = esp_matter.node.config_t()
    esp_matter.attribute.set_callback_shim {
      type, endpoint, cluster, attribute, value, context in
      guard let context else {
        return ESP_OK
      }
      guard let e = Endpoint(id: endpoint) else { return ESP_OK }
      guard let c = Cluster(endpoint: e, id: cluster) else { return ESP_OK }
      guard let event = MatterAttributeEvent(rawValue: type.rawValue) else {
        fatalError("Unknown event type")
      }
      print("Received Matter attribute event: \(event)")
      let ctx = Unmanaged<Context>.fromOpaque(context).takeUnretainedValue()
      ctx.attribute(event, e, c, attribute, value)
      return ESP_OK
    }
    esp_matter.identification.set_callback {
      type, endpoint, effect, variant, context in
      guard let context else { fatalError("context must be non-nil") }
      Unmanaged<Context>.fromOpaque(context).takeUnretainedValue().identify(
        type, endpoint, effect, variant)
      return ESP_OK
    }
    guard let node = esp_matter.node.create_raw() else {
      return nil
    }

    let context = Context(attribute: attribute, identify: identify)
    withUnsafeMutablePointer(to: &nodeConfig.root_node) {
      // Transfer ownership to the node. This is a leak for now, but we don't expect nodes to be created and destroyed repeatedly.
      _ = esp_matter.endpoint.root_node.create(
        node, $0, 0x00, Unmanaged.passRetained(context).toOpaque())
    }
    self.node = node
    self.context = context
  }

  var endpoint: Endpoint {
    Endpoint(esp_matter.endpoint.get(node, 0))
  }
}

struct Endpoint: MatterEndpoint {
  var endpoint: UnsafeMutablePointer<esp_matter.endpoint_t>

  init(_ endpoint: UnsafeMutablePointer<esp_matter.endpoint_t>) {
    self.endpoint = endpoint
  }

  init?(id: UInt16) {
    guard let root = esp_matter.node.get() else { return nil }
    guard let endpoint = esp_matter.endpoint.get(root, id) else { return nil }
    self.init(endpoint)
  }

  func `as`<T: MatterConreteEndpoint>(_ type: T.Type) -> T? {
    var count = UInt8(0)
    let expected = T.deviceTypeId
    let ids = esp_matter.endpoint.get_device_type_ids(endpoint, &count)
    for id in UnsafeMutableBufferPointer(start: ids, count: Int(count)) {
      if id == expected {
        return T(endpoint)
      }
    }
    return nil
  }
}



struct MatterExtendedTemperature: MatterConreteEndpoint {
  static var deviceTypeId: UInt32 {
    esp_matter.endpoint.temperature_sensor.get_device_type_id()
  }
  
  var endpoint: UnsafeMutablePointer<esp_matter.endpoint_t>
    
  init(
    _ node: RootNode,
    configuration: esp_matter.endpoint.temperature_sensor.config_t
  ) {
    var config = configuration
    endpoint = esp_matter.endpoint.temperature_sensor.create(
      node.node, &config, 0x00, nil)
  }
  
  init(_ endpoint: UnsafeMutablePointer<esp_matter.endpoint_t>) {
    self.endpoint = endpoint
  }
  
  var temperature: Temperature {
    cluster(.temperature)
  }
}

struct MatterExtendedHumidity: MatterConreteEndpoint {
  static var deviceTypeId: UInt32 {
    esp_matter.endpoint.humidity_sensor.get_device_type_id()
  }
  
  var endpoint: UnsafeMutablePointer<esp_matter.endpoint_t>
    
  init(
    _ node: RootNode,
    configuration: esp_matter.endpoint.humidity_sensor.config_t
  ) {
    var config = configuration
    endpoint = esp_matter.endpoint.humidity_sensor.create(
      node.node, &config, 0x00, nil)
  }
  
  init(_ endpoint: UnsafeMutablePointer<esp_matter.endpoint_t>) {
    self.endpoint = endpoint
  }
  
  var humidity: Humidity {
    cluster(.humidity)
  }
}

struct MatterExtendedPressure: MatterConreteEndpoint {
  static var deviceTypeId: UInt32 {
    esp_matter.endpoint.pressure_sensor.get_device_type_id()
  }
  
  var endpoint: UnsafeMutablePointer<esp_matter.endpoint_t>
    
  init(
    _ node: RootNode,
    configuration: esp_matter.endpoint.pressure_sensor.config_t
  ) {
    var config = configuration
    endpoint = esp_matter.endpoint.pressure_sensor.create(
      node.node, &config, 0x00, nil)
  }
  
  init(_ endpoint: UnsafeMutablePointer<esp_matter.endpoint_t>) {
    self.endpoint = endpoint
  }

  var pressure: Pressure {
    cluster(.pressure)
  }
}