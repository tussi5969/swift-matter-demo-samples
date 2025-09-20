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

enum Matter {}

extension Matter {
  class Node {
    var identifyHandler: (() -> Void)? = nil

    var endpoints: [Endpoint] = []

    func addEndpoint(_ endpoint: Endpoint) {
      endpoints.append(endpoint)
    }

    // swift-format-ignore: NeverUseImplicitlyUnwrappedOptionals
    // This is never actually nil after init(), and inside init we want to form a callback closure that references self.
    var innerNode: RootNode!

    init() {
      // Initialize persistent storage.
      nvs_flash_init()

      // For now, leak the object, to be able to use local variables to declare it. We don't expect this object to be created and destroyed repeatedly.
      _ = Unmanaged.passRetained(self)

      // Create the actual root node object, wire up callbacks.
      let root = RootNode(
        attribute: self.eventHandler,
        identify: { _, _, _, _ in self.identifyHandler?() })
      guard let root else {
        fatalError("Failed to setup root node.")
      }
      self.innerNode = root
    }

    func eventHandler(
      type: MatterAttributeEvent, endpoint: __idf_main.Endpoint,
      cluster: Cluster, attribute: UInt32,
      value: UnsafeMutablePointer<esp_matter_attr_val_t>?
    ) {
      return
    }
  }
}

extension Matter {
  class Endpoint {
    init(node: Node) {
      // For now, leak the object, to be able to use local variables to declare it. We don't expect this object to be created and destroyed repeatedly.
      _ = Unmanaged.passRetained(self)
    }

    var id: Int = 0

    var eventHandler: ((Event) -> Void)? = nil

    struct Event {
      var type: MatterAttributeEvent
      // var attribute: Attribute
      var value: Int
    }
  }
}

extension Matter {
  class SensorEndpoint: Endpoint {
    func updateAttribute(clusterId: UInt32, attributeId: UInt32, value: Int16, unit: String) {
      var attrVal = esp_matter_attr_val_t()
      attrVal.type = ESP_MATTER_VAL_TYPE_INT16
      attrVal.val.i16 = value
      
      let result = esp_matter.attribute.update_shim(UInt16(self.id), clusterId, attributeId, &attrVal)
      
      if result == ESP_OK {
        print("\(unit) updated (Matter value: \(value))")
      } else {
        print("Failed to update \(unit): \(result)")
      }
    }
  }
  
  class ExtendedTemperature: SensorEndpoint {
    override init(node: Node) {
      super.init(node: node)
      
      var temperatureConfig = esp_matter.endpoint.temperature_sensor.config_t()
      temperatureConfig.temperature_measurement.measured_value = .init(2500)
      
      let temperature = MatterExtendedTemperature(
        node.innerNode, configuration: temperatureConfig)
      self.id = Int(temperature.id)
    }

    func updateTemperature(_ celsius: Float) {
      // hundredths of degrees Celsius
      let matterValue = Int16(celsius * 100)
      
      updateAttribute(
        clusterId: ClusterID<Temperature>.temperature.rawValue,
        attributeId: Temperature.AttributeID<Temperature.MeasuredValue>.measuredValue.rawValue,
        value: matterValue,
        unit: "Temperature to \(celsius)°C"
      )
    }
  }

  class ExtendedHumidity: SensorEndpoint {
    override init(node: Node) {
      super.init(node: node)

      var humidityConfig = esp_matter.endpoint.humidity_sensor.config_t()
      humidityConfig.relative_humidity_measurement.measured_value = .init(5000) // 50.00%

      let humidity = MatterExtendedHumidity(
        node.innerNode, configuration: humidityConfig)
      self.id = Int(humidity.id)
    }

    func updateHumidity(_ percent: Float) {
      // hundredths of percent
      let matterValue = Int16(percent * 100)

      updateAttribute(
        clusterId: ClusterID<Humidity>.humidity.rawValue,
        attributeId: Humidity.AttributeID<Humidity.MeasuredValue>.measuredValue.rawValue,
        value: matterValue,
        unit: "Humidity to \(percent)%"
      )
    }
  }

  class ExtendedPressure: SensorEndpoint {
    override init(node: Node) {
      super.init(node: node)

      var pressureConfig = esp_matter.endpoint.pressure_sensor.config_t()
      pressureConfig.pressure_measurement.pressure_measured_value = .init(1013) // 1013.25 hPa

      let pressure = MatterExtendedPressure(
        node.innerNode, configuration: pressureConfig)
      self.id = Int(pressure.id)
    }

    func updatePressure(_ pascals: Float) {
      // hundredths of pascals
      let matterValue = Int16(pascals)

      updateAttribute(
        clusterId: ClusterID<Pressure>.pressure.rawValue,
        attributeId: Pressure.AttributeID<Pressure.MeasuredValue>.measuredValue.rawValue,
        value: matterValue,
        unit: "Pressure to \(pascals)Pa"
      )
    }
  }
}

extension Matter {
  class Application {
    var rootNode: Node? = nil

    init() {
      // For now, leak the object, to be able to use local variables to declare
      // it. We don't expect this object to be created and destroyed repeatedly.
      _ = Unmanaged.passRetained(self)
    }

    func start() {
      func callback(
        event: UnsafePointer<chip.DeviceLayer.ChipDeviceEvent>?, context: Int
      ) {
        // Ignore callback if event not set.
        guard let event else { return }
        switch Int(event.pointee.Type) {
        case chip.DeviceLayer.DeviceEventType.kFabricRemoved:
          recomissionFabric()
        default: break
        }
      }
      esp_matter.start(callback, 0)
    }
  }
}
