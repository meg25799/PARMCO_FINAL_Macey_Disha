import SwiftUI

struct ContentView: View {

    // Bluetooth manager
    @StateObject private var bluetooth = BluetoothManager()

    // PARMCO default settings
    @State private var desiredRPM = 20
    @State private var clockwise = true
    @State private var startRequested = false
    @State private var lastAction = "None"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: Bluetooth Connection

                    VStack(spacing: 12) {
                        Text("Bluetooth Connection")
                            .font(.headline)

                        Text(bluetooth.status)
                            .foregroundStyle(
                                bluetooth.isReady
                                ? Color.green : Color.orange
                            )
                            .multilineTextAlignment(.center)

                        Button("Connect to Raspberry Pi") {
                            bluetooth.scanAndConnect()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Disconnect") {
                            bluetooth.disconnect()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 15))

                    // MARK: Speed Controls

                    Text("Desired Speed")
                        .font(.headline)

                    Text("\(desiredRPM) RPM")
                        .font(.largeTitle.bold())

                    HStack(spacing: 15) {
                        Button("Slower") {
                            desiredRPM = max(10, desiredRPM - 5)
                            lastAction = "SLOWER"
                            bluetooth.send("SLOWER")
                        }

                        Button("Faster") {
                            desiredRPM = min(100, desiredRPM + 5)
                            lastAction = "FASTER"
                            bluetooth.send("FASTER")
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Divider()

                    // MARK: Direction

                    Text("Direction")
                        .font(.headline)

                    Button(clockwise ? "Clockwise (CW)" :
                                       "Counterclockwise (CCW)") {
                        clockwise.toggle()

                        let command = clockwise
                            ? "DIR:CW" : "DIR:CCW"

                        lastAction = command
                        bluetooth.send(command)
                    }
                    .buttonStyle(.borderedProminent)

                    Divider()

                    // MARK: Start/Stop Request
                    // Does NOT physically operate motor in CP2.

                    Text("Motor State Request")
                        .font(.headline)

                    Button(startRequested
                           ? "STOP Request" : "START Request") {
                        startRequested.toggle()

                        let command = startRequested
                            ? "START" : "STOP"

                        lastAction = command
                        bluetooth.send(command)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(startRequested ? .red : .green)

                    Divider()

                    // MARK: Message Display

                    VStack(spacing: 8) {
                        Text("Bluetooth Messages")
                            .font(.headline)

                        Text("Last button action:")
                            .foregroundStyle(.secondary)
                        Text(lastAction)

                        Text("Last command sent:")
                            .foregroundStyle(.secondary)
                        Text(bluetooth.lastSent)

                        Text("Last RP4 response:")
                            .foregroundStyle(.secondary)
                        Text(bluetooth.lastReceived)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 15))

                    Text("Checkpoint 2: Phone controls send Bluetooth messages only. Actual motor control remains on the Raspberry Pi keyboard.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                }
                .padding()
            }
            .navigationTitle("PARMCO")
        }
    }
}

#Preview {
    ContentView()
}
