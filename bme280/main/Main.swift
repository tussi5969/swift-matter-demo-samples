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

// Constants (use the same values as ESP-IDF)
let I2C_MASTER_NUM: i2c_port_t = I2C_NUM_0
let I2C_MASTER_SDA_IO: gpio_num_t = GPIO_NUM_2
let I2C_MASTER_SCL_IO: gpio_num_t = GPIO_NUM_1
let I2C_MASTER_FREQ_HZ: UInt32 = 100000

@_cdecl("app_main")
func main() {
  var conf = i2c_config_t()
  conf.mode = I2C_MODE_MASTER
  conf.sda_io_num = Int32(I2C_MASTER_SDA_IO.rawValue)
  conf.scl_io_num = Int32(I2C_MASTER_SCL_IO.rawValue)
  conf.sda_pullup_en = true
  conf.scl_pullup_en = true
  conf.master.clk_speed = I2C_MASTER_FREQ_HZ

  // Initialize I²C driver (with error checking)
  var i2c_bus: i2c_bus_handle_t? = nil
  i2c_bus = i2c_bus_create(I2C_MASTER_NUM, &conf)

  if i2c_bus == nil {
    print("Failed to create I2C bus")
    return
  }
  print("I2C bus created successfully")

  // Step2: Init bme280 (with error checking)
  var bme280: bme280_handle_t? = nil
  bme280 = bme280_create(i2c_bus, UInt8(BME280_I2C_ADDRESS_DEFAULT))  // Try standard address 0x76

  if bme280 == nil {
    print("Failed to create BME280 handle")
      return
  } else {
    print("BME280 found at address 0x76")
  }

  let init_result = bme280_default_init(bme280)
  print("BME280 init result: \(init_result)")

  if init_result == ESP_OK {
    print("BME280 initialization succeeded")
  } else {
    print("BME280 initialization failed")
  }

  // Step3: Read temperature, humidity and pressure
  var temperature: Float = 0.0
  var humidity: Float = 0.0
  var pressure: Float = 0.0

  // (1) Create a Matter root node
  let rootNode = Matter.Node()
  rootNode.identifyHandler = {
    print("identify")
  }

  // (2) Create a Temperature endpoint
  let temperatureEndpoint = Matter.ExtendedTemperature(node: rootNode)
  let humidityEndpoint = Matter.ExtendedHumidity(node: rootNode)
  let pressureEndpoint = Matter.ExtendedPressure(node: rootNode)

  // (3) Add the endpoint to the root node
  rootNode.addEndpoint(temperatureEndpoint)
  rootNode.addEndpoint(humidityEndpoint)
  rootNode.addEndpoint(pressureEndpoint)

  // (4) Provide the node to a Matter application
  let matterApp = Matter.Application()
  matterApp.rootNode = rootNode
  matterApp.start()

  while true {
    vTaskDelay(2000 / (1000 / UInt32(configTICK_RATE_HZ)))

    let temp_result = bme280_read_temperature(bme280, &temperature)
    let hum_result = bme280_read_humidity(bme280, &humidity)
    let press_result = bme280_read_pressure(bme280, &pressure)

    if temp_result == ESP_OK && hum_result == ESP_OK && press_result == ESP_OK {
      temperatureEndpoint.updateTemperature(temperature)
      humidityEndpoint.updateHumidity(humidity)
      pressureEndpoint.updatePressure(pressure)
    } else {
      print("Error reading sensor data - Temp: \(temp_result), Hum: \(hum_result), Press: \(press_result)")
    }
  }
}

extension String.StringInterpolation {
  mutating func appendInterpolation(_ value: Float) {
    let intPart = Int(value)
    let fracPart = Int((value - Float(intPart)) * 100)
    self.appendLiteral("\(intPart).\(fracPart < 10 ? "0" : "")\(fracPart)")
  }
}

