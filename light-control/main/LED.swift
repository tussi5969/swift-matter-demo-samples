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

// Helper object that can be used to control the ESP32C6 on-board LED. Settings
// the `enabled`, `brightness`, `color` properties immediately propagates those
// to the physical LED.

final class LED {
  private var ledStrip: UnsafeMutablePointer<led_strip_t>?
  // Whether the LED should be turned on
  var enabled: Bool = true {
    didSet {
      print("LED enabled: \(enabled)")
      led_driver_set_power(handle, enabled)
    }
  }

  // Brightness of the LED
  var brightness: Int = 100 {
    didSet {
      brightness = max(0, min(100, brightness))
      led_driver_set_brightness(handle, UInt8(brightness))
    }
  }

  // Color of the LED
  var color: Color = .hueSaturation(0, 100) {
    didSet {
      switch color {
      case .hueSaturation(let hue, let saturation):
        led_driver_set_hue(handle, UInt16(hue))
        led_driver_set_saturation(handle, UInt8(saturation))
      case .temperature(let temperature):
        led_driver_set_temperature(handle, UInt32(temperature))
      }
    }
  }

  // Color, represented as either "hue + saturation", or temperature.
  enum Color {
    // "Hue + saturation" color representation. Hue range is 0 ..< 360.
    // Saturation is 0 ... 100.
    case hueSaturation(Int, Int)

    // Temperature color representation in Kelvins (range 600 ... 10000).
    case temperature(Int)

    // Hue range is 0 ..< 360.
    var hue: Int {
      switch self {
      case .hueSaturation(let hue, _): return hue
      case .temperature: return 0
      }
    }

    // Saturation is 0 ... 100.
    var saturation: Int {
      switch self {
      case .hueSaturation(_, let saturation): return saturation
      case .temperature: return 0
      }
    }
  }

  var handle: led_driver_handle_t

  init() {
    // Enable RGB LED power (set GPIO19 to High)
    guard gpio_reset_pin(GPIO_NUM_19) == ESP_OK else {
      fatalError("cannot reset led")
    }

    guard gpio_set_direction(GPIO_NUM_19, GPIO_MODE_OUTPUT) == ESP_OK else {
      fatalError("cannot reset led")
    }
    gpio_set_level(GPIO_NUM_19, 1)
    print("GPIO19 set to HIGH for LED power")
    
    // Set GPIO pin and channel for M5NanoC6
    let gpioPin: gpio_num_t = GPIO_NUM_20
    let rmtChannel: rmt_channel_t = RMT_CHANNEL_0
    
    // RMT configuration (based on C implementation of led_driver_init)
    var rmtConfig = rmt_config_t()
    rmtConfig.channel = rmtChannel
    rmtConfig.gpio_num = gpioPin
    rmtConfig.mem_block_num = 1
    rmtConfig.clk_div = 2
    rmtConfig.tx_config.loop_en = false
    rmtConfig.tx_config.carrier_en = false
    rmtConfig.rmt_mode = RMT_MODE_TX
    
    // Initialize RMT
    let rmtConfigResult = rmt_config(&rmtConfig)
    guard rmtConfigResult == ESP_OK else {
      print("rmt_config failed with error: \(rmtConfigResult)")
      fatalError("Failed to configure RMT for GPIO \(gpioPin)")
    }
    
    let rmtInstallResult = rmt_driver_install(rmtConfig.channel, 0, 0)
    guard rmtInstallResult == ESP_OK else {
      print("rmt_driver_install failed with error: \(rmtInstallResult)")
      fatalError("Failed to install RMT driver")
    }
    
    // LED strip configuration
    var stripConfig = led_strip_config_t(
      max_leds: 1,
      dev: UnsafeMutableRawPointer(bitPattern: Int(rmtConfig.channel.rawValue))
    )

    // Initialize LED strip
    let strip = led_strip_new_rmt_ws2812(&stripConfig)
    guard let strip else {
      print("W2812 driver install failed")
      fatalError("Failed to initialize LED strip")
    }
    
    // Set handle (in C implementation, returns (led_driver_handle_t)strip)
    // Convert UnsafeMutablePointer<led_strip_t> to UnsafeMutableRawPointer
    self.handle = UnsafeMutableRawPointer(strip)
    self.ledStrip = strip
    
    print("LED strip initialized successfully on GPIO \(gpioPin)")
    print("LED initialized with handle: \(handle)")
  }
}