import SwiftUI

struct ContentView: View {
    @State private var status = ESPStatus()
    @State private var connected = false
    @State private var loading = false
    @State private var errorMessage: String?

    @State private var selectedDay = 0
    @State private var selectedTime = Date()
    @State private var schedules: [DaySchedule] = ContentView.defaultSchedules

    private let client = ESP32Client.shared

    static let dayNames = ["Lunedì","Martedì","Mercoledì","Giovedì","Venerdì","Sabato","Domenica"]

    static var defaultSchedules: [DaySchedule] {
        dayNames.enumerated().map { i, name in
            DaySchedule(
                id: i, name: name,
                morning: TimeSlot(id: i*2, start: i < 5 ? "05:40" : "08:00", end: i < 5 ? "06:30" : "00:00"),
                afternoon: TimeSlot(id: i*2+1, start: i < 5 ? "14:00" : "00:00", end: i < 5 ? "23:30" : "00:00")
            )
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    statusCard
                    quickActions
                    dateTimeCard
                    schedulesCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ESP32 Timer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(loading)
                }
            }
            .alert("Errore", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task { await refresh() }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Controllo luci")
                    .font(.title2.bold())
                Text(connected ? "ESP32 connesso" : "Connessione in attesa")
                    .font(.subheadline)
                    .foregroundStyle(connected ? .green : .secondary)
            }
            Spacer()
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 34))
                .foregroundStyle(status.ledOn ? .yellow : .secondary)
                .padding(12)
                .background(.thinMaterial, in: Circle())
        }
    }

    private var statusCard: some View {
        HStack(spacing: 14) {
            StatView(icon: "clock.fill", title: "Ora", value: status.time)
            Divider().frame(height: 48)
            StatView(icon: "lightbulb.fill", title: "Luci", value: status.ledOn ? "ON" : "OFF")
            Divider().frame(height: 48)
            StatView(icon: "wifi", title: "Wi‑Fi", value: status.wifiOn ? "ON" : "OFF")
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comando manuale").font(.headline)
            HStack(spacing: 12) {
                Button { Task { await setLED(true) } } label: {
                    Label("Accendi", systemImage: "lightbulb.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)

                Button { Task { await setLED(false) } } label: {
                    Label("Spegni", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            Text("Il comando manuale resta attivo per 10 minuti, come nel firmware ESP32.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dateTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ora e giorno ESP32").font(.headline)
            Picker("Giorno", selection: $selectedDay) {
                ForEach(0..<7) { Text(Self.dayNames[$0]).tag($0) }
            }
            DatePicker("Ora", selection: $selectedTime, displayedComponents: .hourAndMinute)
            Button {
                Task { await setDateTime() }
            } label: {
                Label("Imposta su ESP32", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .cardStyle()
    }

    private var schedulesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Programmazione settimanale").font(.headline)
                Spacer()
                Button("Salva") { Task { await saveSchedules() } }
                    .buttonStyle(.borderedProminent)
            }

            ForEach($schedules) { $day in
                DisclosureGroup {
                    ScheduleRow(title: "Mattina", start: $day.morning.start, end: $day.morning.end)
                    ScheduleRow(title: "Pomeriggio", start: $day.afternoon.start, end: $day.afternoon.end)
                } label: {
                    HStack {
                        Text(day.name).font(.body.weight(.semibold))
                        Spacer()
                        Text("\(day.morning.start)–\(day.morning.end)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .cardStyle()
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        do {
            let html = try await client.getRoot()
            status = client.parseStatus(from: html)
            connected = true
        } catch {
            connected = false
            errorMessage = "Impossibile raggiungere l'ESP32. Assicurati che l'iPhone sia collegato alla rete ESP32-TIMER."
        }
    }

    private func setLED(_ on: Bool) async {
        do {
            if on { try await client.turnOn() } else { try await client.turnOff() }
            status.ledOn = on
            connected = true
        } catch {
            errorMessage = "Comando non riuscito."
        }
    }

    private func setDateTime() async {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        do {
            try await client.setDateTime(day: selectedDay, time: f.string(from: selectedTime))
            await refresh()
        } catch {
            errorMessage = "Non è stato possibile impostare data e ora."
        }
    }

    private func saveSchedules() async {
        do {
            try await client.save(schedule: schedules)
            await refresh()
        } catch {
            errorMessage = "Salvataggio non riuscito."
        }
    }
}

struct StatView: View {
    let icon: String
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ScheduleRow: View {
    let title: String
    @Binding var start: String
    @Binding var end: String

    var body: some View {
        HStack {
            Text(title).frame(width: 85, alignment: .leading)
            TimeTextField(text: $start)
            Text("–")
            TimeTextField(text: $end)
        }
        .padding(.vertical, 5)
    }
}

struct TimeTextField: View {
    @Binding var text: String
    var body: some View {
        TextField("HH:MM", text: $text)
            .keyboardType(.numbersAndPunctuation)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 100)
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}
