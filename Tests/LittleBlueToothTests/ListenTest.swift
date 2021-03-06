//
//  ListenTest.swift
//  LittleBlueToothTests
//
//  Created by Andrea Finollo on 04/07/2020.
//  Copyright © 2020 Andrea Finollo. All rights reserved.
//

import XCTest
import Combine
import CoreBluetoothMock
@testable import LittleBlueTooth

struct ButtonState: Readable {
    let isOn: Bool

    init(from data: Data) throws {
        let answer: Bool = try data.extract(start: 0, length: 1)
        self.isOn = answer
    }
    
}


class ListenTest: LittleBlueToothTests {
    var cancellable: Cancellable?

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
        littleBT = LittleBlueTooth()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testListen() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let charateristic = LittleBlueToothCharacteristic(characteristic: CBUUID.buttonCharacteristic.uuidString, for: CBUUID.nordicBlinkyService.uuidString)
        let listenExpectation = expectation(description: "Listen expectation")
        
        var counter = 0
        
        let scheduler: AnyCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
        .autoconnect()
        .map {_ in
            blinky.simulateValueUpdate(Data([0x01]), for: CBMCharacteristicMock.buttonCharacteristic)
        }.sink { value in
            print("Led value:\(value)")
        }
        
        littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
            .map { disc -> PeripheralDiscovery in
                print("Discovery discovery \(disc)")
                return disc
        }
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .flatMap { _ in
            self.littleBT.startListen(from: charateristic, forType: ButtonState.self)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (answer) in
            counter += 1
            print("Answer \(answer)")
            if counter > 10 {
                scheduler.cancel()
                self.littleBT.disconnect().sink(receiveCompletion: {_ in
                }) { (perip) in
                    listenExpectation.fulfill()
                }
                .store(in: &self.disposeBag)
            }
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 20)
        XCTAssert(counter > 10)
    }
    
    
    func testConnectableListen() {
        disposeBag.removeAll()

        blinky.simulateProximityChange(.immediate)
        let charateristic = LittleBlueToothCharacteristic(characteristic: CBUUID.buttonCharacteristic.uuidString, for: CBUUID.nordicBlinkyService.uuidString)
        
        // Expectation
        let firstListenExpectation = expectation(description: "First sub expectation")
        let secondListenExpectation = expectation(description: "Second sub expectation")
        var sub1Event = [Bool]()
        var sub2Event = [Bool]()
        var firstCounter = 0
        var secondCounter = 0
        
        // Simulate notification
        let scheduler: AnyCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .map {_ -> UInt8 in
                let data = UInt8.random(in: 0...1)
                blinky.simulateValueUpdate(Data([data]), for: CBMCharacteristicMock.buttonCharacteristic)
                return data
        }.sink { value in
            print("Led value:\(value)")
        }

        let connectable = littleBT.connectableListenPublisher(for: charateristic, valueType: ButtonState.self)
        
        // First subscriber
        connectable
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (answer) in
            firstCounter += 1
            print("Sub1 \(answer)")
            sub1Event.append(answer.isOn)
            if firstCounter == 10 {
                scheduler.cancel()
                self.littleBT.disconnect().sink(receiveCompletion: {_ in
                }) { (perip) in
                    firstListenExpectation.fulfill()
                }
                .store(in: &self.disposeBag)
            }
        }
        .store(in: &disposeBag)
        
        // Second subscriber
        connectable
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (answer) in
          print("Sub2: \(answer)")
            sub2Event.append(answer.isOn)
          secondCounter += 1
          if secondCounter == 10 {
            secondListenExpectation.fulfill()
          }
        }
        .store(in: &disposeBag)
        

        littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
        .map { disc -> PeripheralDiscovery in
                print("Discovery discovery \(disc)")
                return disc
        }
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .map { _ -> Void in
            self.cancellable = connectable.connect()
            return ()
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (answer) in
            print("Answer \(answer)")
        }
        .store(in: &disposeBag)
        
        
        waitForExpectations(timeout: 40)
        XCTAssert(sub1Event.count == sub2Event.count)
        XCTAssert(sub1Event == sub2Event)
    }
    
 

    func testListenToMoreCharacteristic() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let charateristicOne = LittleBlueToothCharacteristic(characteristic: CBUUID.buttonCharacteristic.uuidString, for: CBUUID.nordicBlinkyService.uuidString)
        let charateristicTwo = LittleBlueToothCharacteristic(characteristic: CBUUID.ledCharacteristic.uuidString, for: CBUUID.nordicBlinkyService.uuidString)
        // Expectation
        let firstListenExpectation = XCTestExpectation(description: "First sub more expectation")
        let secondListenExpectation = XCTestExpectation(description: "Second sub more expectation")
        var sub1Event = [Bool]()
        var sub2Event = [Bool]()
        var firstCounter = 0
        var secondCounter = 0
        
        // Simulate notification
        let scheduler: AnyCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .map {_ -> UInt8 in
                var data = UInt8.random(in: 0...1)
                blinky.simulateValueUpdate(Data([data]), for: CBMCharacteristicMock.buttonCharacteristic)
                data = UInt8.random(in: 0...1)
                blinky.simulateValueUpdate(Data([data]), for: CBMCharacteristicMock.ledCharacteristic)
                return data
        }.sink { value in
            print(" value:\(value)")
        }
        
        // First publisher
        littleBT.listenPublisher
        .filter { charact -> Bool in
                charact.uuid == charateristicOne.characteristic
        }
        .tryMap { (characteristic) -> ButtonState in
            guard let data = characteristic.value else {
                throw LittleBluetoothError.emptyData
            }
            return try ButtonState(from: data)
        }
        .mapError { (error) -> LittleBluetoothError in
            if let er = error as? LittleBluetoothError {
                return er
            }
            return .emptyData
        }
        .sink(receiveCompletion: { completion in
                print("Completion \(completion)")
            }) { (answer) in
                print("Sub1: \(answer)")
                if firstCounter == 10 {
                    return
                } else {
                    sub1Event.append(answer.isOn)
                    firstCounter += 1
                }
        }
        .store(in: &self.disposeBag)
        
        // Second publisher
        littleBT.listenPublisher
        .filter { charact -> Bool in
                charact.uuid == charateristicTwo.characteristic
        }
        .tryMap { (characteristic) -> LedState in
            guard let data = characteristic.value else {
                throw LittleBluetoothError.emptyData
            }
            return try LedState(from: data)
        }.mapError { (error) -> LittleBluetoothError in
            if let er = error as? LittleBluetoothError {
                return er
            }
            return .emptyData
        }
        .sink(receiveCompletion: { completion in
                print("Completion \(completion)")
            }) { (answer) in
                print("Sub2: \(answer)")
                if secondCounter == 10 {
                    return
                } else {
                    sub2Event.append(answer.isOn)
                    secondCounter += 1
                }
        }
        .store(in: &self.disposeBag)

        littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
            .map { disc -> PeripheralDiscovery in
                print("Discovery discovery \(disc)")
                return disc
        }
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .flatMap { periph in
            self.littleBT.startListen(from: charateristicOne)
        }
        .flatMap { periph in
            self.littleBT.startListen(from: charateristicTwo)
        }
        .delay(for: .seconds(20), scheduler: DispatchQueue.global())
        .flatMap { _ in
            self.littleBT.stopListen(from: charateristicOne)
        }
        .flatMap { _ in
            self.littleBT.stopListen(from: charateristicTwo)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
        }) { (answer) in
            secondListenExpectation.fulfill()
            firstListenExpectation.fulfill()
        }
        .store(in: &disposeBag)
        
        wait(for: [firstListenExpectation, secondListenExpectation], timeout: 30)
        littleBT.disconnect()
        XCTAssert(sub1Event.count == sub2Event.count)
        
    }
    
    func testPowerOffWhileListen() {
        disposeBag.removeAll()
        
        blinky.simulateProximityChange(.immediate)
        let charateristic = LittleBlueToothCharacteristic(characteristic: CBUUID.buttonCharacteristic.uuidString, for: CBUUID.nordicBlinkyService.uuidString)
        let listenExpectation = expectation(description: "Listen while powering off expectation")
        var isPowerOff = false
        
        let scheduler: AnyCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
        .autoconnect()
        .map {_ in
            var data = UInt8.random(in: 0...1)
            blinky.simulateValueUpdate(Data([data]), for: CBMCharacteristicMock.buttonCharacteristic)
        }.sink { value in
            print("Led value:\(value)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) {
            CBMCentralManagerMock.simulateInitialState(.poweredOff)
        }
        
        littleBT.startDiscovery(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
        .map { disc -> PeripheralDiscovery in
                print("Discovery discovery \(disc)")
                return disc
        }
        .flatMap { discovery in
            self.littleBT.connect(to: discovery)
        }
        .flatMap { _ in
            self.littleBT.startListen(from: charateristic, forType: ButtonState.self)
        }
        .sink(receiveCompletion: { completion in
            print("Completion \(completion)")
            switch completion {
            case let .failure(error):
                if case LittleBluetoothError.bluetoothPoweredOff = error {
                    isPowerOff = true
                    listenExpectation.fulfill()
                }
            default:
                break
            }
        }) { (answer) in
            print("Answer \(answer)")
        }
        .store(in: &disposeBag)
        
        waitForExpectations(timeout: 10)
        XCTAssert(isPowerOff)
        
    }
    
}
