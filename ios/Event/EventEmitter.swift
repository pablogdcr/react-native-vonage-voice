//
//  EventEmitter.swift
//  react-native-vonage-voice
//
//  Created by Volodymyr Smolianinov on 03/08/2024.
//

import Foundation

class EventEmitter {

  static let shared = EventEmitter()

  private var eventEmitter: EventEmitterNativeModule!

  func registerEventEmitter(_ eventEmitter: EventEmitterNativeModule) {
    self.eventEmitter = eventEmitter
  }

  func sendEvent(withName name: String, body: Any?) {
    eventEmitter.sendEvent(withName: name, body: body)
  }

}
