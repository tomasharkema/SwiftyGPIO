/*
 SwiftyGPIO

 Copyright (c) 2017 Umberto Raimondi
 Licensed under the MIT license, as follows:

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.)
 */
#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

// MARK: - 1-Wire Presets
extension SwiftyGPIO {

    public static func hardware1Wires(for board: SupportedBoard) -> [OneWireInterface]? {
        switch board {
        case .RaspberryPiRev1,
             .RaspberryPiRev2,
             .RaspberryPiPlusZero,
             .RaspberryPiZero2,
             .RaspberryPi2,
             .RaspberryPi3,
             .RaspberryPi4:
            return [SysFSOneWire(masterId: 1)]
        default:
            return nil
        }
    }
}

// MARK: 1-Wire
public protocol OneWireInterface {
    func getSlaves() throws -> [String]
    func readData(_ slaveId: String) throws -> [String]
}

/// Hardware 1-Wire via SysFS
public final class SysFSOneWire: OneWireInterface {

    let masterId: Int

    public init(masterId: Int) {
        self.masterId = masterId
    }

    public func getSlaves() throws -> [String] {
        let listpath = ONEWIREBASEPATH + "w1_bus_master" + String(masterId) + "/w1_master_slaves"
        return try readFile(listpath)
    }

    public func readData(_ slaveId: String) throws -> [String] {
        let devicepath = ONEWIREBASEPATH + slaveId + "/w1_slave"
        return try readFile(devicepath)
    }

    private func readFile(_ pathname: String) throws -> [String] {
        let fd = open(pathname, O_RDONLY | O_SYNC)
        guard fd > 0, let file = fdopen(fd, "r") else {
          throw GPIOError.bus("Couldn't open 1-Wire device: "+pathname)
        }

        var lines = [String]()
        while let s = try readLine(maxLength: 128, file: file) {
            lines.append(s)
        }

        close(fd)
        return lines      
    }

    func readLine(maxLength: Int = 128, file: UnsafeMutablePointer<FILE>!) throws -> String? {
        var buffer = [CChar](repeating: 0, count: maxLength)
        guard fgets(&buffer, Int32(maxLength), file) != nil else {
            if feof(file) != 0 {
                return nil
            } else {
              throw GPIOError.bus("Error while reading from 1-Wire interface")
            }
        }
        return String(cString: buffer)
    }

}

// MARK: - 1-Wire Constants

internal let ONEWIREBASEPATH = "/sys/bus/w1/devices/"

// MARK: - Darwin / Xcode Support
#if os(OSX) || os(iOS)
    private var O_SYNC: CInt { fatalError("Linux only") }
#endif

