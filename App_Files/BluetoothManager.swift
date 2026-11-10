
import Foundation
import Combine
import CoreBluetooth

// PARMCO Checkpoint 2
// iPhone: Bluetooth Low Energy (BLE) Central
// Raspberry Pi 4: BLE Peripheral
//
// Phone buttons send text messages only.
// Motor movement is controlled by the RP4 keyboard during CP2.

final class BluetoothManager: NSObject, ObservableObject {

    // MARK: - Bluetooth UUIDs

    // These same UUIDs must be used in the Raspberry Pi program.

    private let serviceUUID = CBUUID(
        string: "E4235001-2026-4000-8000-000000000001"
    )

    private let commandUUID = CBUUID(
        string: "E4235001-2026-4000-8000-000000000002"
    )

    private let responseUUID = CBUUID(
        string: "E4235001-2026-4000-8000-000000000003"
    )

    // MARK: - App display values

    @Published private(set) var status = "Initializing Bluetooth..."
    @Published private(set) var isReady = false
    @Published private(set) var lastSent = "None"
    @Published private(set) var lastReceived = "None"

    // MARK: - Bluetooth objects

    private var central: CBCentralManager!
    private var raspberryPi: CBPeripheral?

    private var commandCharacteristic: CBCharacteristic?
    private var responseCharacteristic: CBCharacteristic?

    override init() {
        super.init()

        central = CBCentralManager(
            delegate: self,
            queue: nil
        )
    }

    // MARK: - Connect to Raspberry Pi

    func scanAndConnect() {

        guard central.state == .poweredOn else {
            status = "Bluetooth is not ready"
            return
        }

        guard raspberryPi == nil else {
            status = "Connection already in progress"
            return
        }

        isReady = false
        status = "Scanning for PARMCO-RP4..."

        central.scanForPeripherals(
            withServices: [serviceUUID],
            options: nil
        )
    }

    // MARK: - Disconnect

    func disconnect() {

        central.stopScan()

        if let device = raspberryPi {
            central.cancelPeripheralConnection(device)
        }

        clearConnection()
        status = "Disconnected"
    }

    private func clearConnection() {
        raspberryPi = nil
        commandCharacteristic = nil
        responseCharacteristic = nil
        isReady = false
    }

    // MARK: - Send a text command

    func send(_ command: String) {

        guard isReady,
              let device = raspberryPi,
              let characteristic = commandCharacteristic else {

            status = "Not connected - command not sent"
            return
        }

        // Add a newline so the RP4 can parse text commands.
        let message = command + "\n"
        let data = Data(message.utf8)

        device.writeValue(
            data,
            for: characteristic,
            type: .withResponse
        )

        lastSent = command
        print("PARMCO sent: \(command)")
    }
}

// MARK: - Central Bluetooth callbacks

extension BluetoothManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(
        _ central: CBCentralManager
    ) {

        switch central.state {

        case .poweredOn:
            status = "Bluetooth ready - tap Connect"

        case .poweredOff:
            clearConnection()
            status = "Bluetooth is turned off"

        case .unauthorized:
            clearConnection()
            status = "Bluetooth permission denied"

        case .unsupported:
            status = "Bluetooth LE is not supported"

        case .resetting:
            status = "Bluetooth is resetting"

        case .unknown:
            status = "Waiting for Bluetooth"

        @unknown default:
            status = "Unknown Bluetooth state"
        }
    }

    // Called when the iPhone discovers the RP4.
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {

        guard raspberryPi == nil else { return }

        central.stopScan()

        raspberryPi = peripheral
        peripheral.delegate = self

        status = "RP4 found - connecting..."

        central.connect(peripheral, options: nil)
    }

    // Called when the connection succeeds.
    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {

        status = "Connected - discovering service"

        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {

        clearConnection()

        status = "Connection failed: " +
            (error?.localizedDescription ?? "Unknown error")
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {

        clearConnection()
        status = "Disconnected from RP4"
    }
}

// MARK: - Raspberry Pi GATT callbacks

extension BluetoothManager: CBPeripheralDelegate {

    // Discover the PARMCO service.
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {

        if let error = error {
            status = "Service error: \(error.localizedDescription)"
            return
        }

        guard let service = peripheral.services?.first(
            where: { $0.uuid == serviceUUID }
        ) else {
            status = "PARMCO service not found"
            return
        }

        status = "Discovering characteristics..."

        peripheral.discoverCharacteristics(
            [commandUUID, responseUUID],
            for: service
        )
    }

    // Discover the command and response characteristics.
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {

        if let error = error {
            status = "Characteristic error: \(error.localizedDescription)"
            return
        }

        for characteristic in service.characteristics ?? [] {

            if characteristic.uuid == commandUUID {
                commandCharacteristic = characteristic
            }

            if characteristic.uuid == responseUUID {
                responseCharacteristic = characteristic
            }
        }

        guard let command = commandCharacteristic,
              let response = responseCharacteristic else {
            status = "Required characteristics not found"
            return
        }

        guard command.properties.contains(.write),
              response.properties.contains(.notify) else {
            status = "Incorrect characteristic permissions"
            return
        }

        status = "Enabling reply notifications..."

        peripheral.setNotifyValue(
            true,
            for: response
        )
    }

    // Confirm the phone can receive notifications.
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {

        if let error = error {
            status = "Notification error: \(error.localizedDescription)"
            return
        }

        if characteristic.uuid == responseUUID &&
           characteristic.isNotifying &&
           commandCharacteristic != nil {

            isReady = true
            status = "Connected to PARMCO-RP4"
        }
    }

    // Receive a reply from the Raspberry Pi.
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {

        if let error = error {
            status = "Receive error: \(error.localizedDescription)"
            return
        }

        guard characteristic.uuid == responseUUID,
              let data = characteristic.value else {
            return
        }

        let message = String(
            decoding: data,
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        lastReceived = message

        print("PARMCO received: \(message)")
    }

    // Confirm whether the command write succeeded.
    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {

        if let error = error {
            status = "Send error: \(error.localizedDescription)"
        }
    }
}
