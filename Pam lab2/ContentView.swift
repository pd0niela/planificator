// ContentView.swift - Romence anlık bildirimli versiyon

import SwiftUI
import UserNotifications

// MARK: - FileManager Extension
extension FileManager {
    static var documentsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

// MARK: - Model
struct MoodEntry: Identifiable, Codable {
    var id: UUID
    var date: Date
    var moodType: MoodType
    var notes: String
    
    init(id: UUID = UUID(), date: Date = Date(), moodType: MoodType = .neutru, notes: String = "") {
        self.id = id
        self.date = date
        self.moodType = moodType
        self.notes = notes
    }
}

enum MoodType: String, Codable, CaseIterable {
    case fericit = "Fericit"      // Mutlu
    case bucuros = "Bucuros"      // Neşeli
    case neutru = "Neutru"        // Nötr
    case trist = "Trist"          // Üzgün
    case furios = "Furios"        // Kızgın
    case anxios = "Anxios"        // Endişeli
    
    var emoji: String {
        switch self {
        case .fericit: return "😄"
        case .bucuros: return "😊"
        case .neutru: return "😐"
        case .trist: return "😢"
        case .furios: return "😡"
        case .anxios: return "😰"
        }
    }
    
    var color: Color {
        switch self {
        case .fericit: return .yellow
        case .bucuros: return .green
        case .neutru: return .gray
        case .trist: return .blue
        case .furios: return .red
        case .anxios: return .purple
        }
    }
    
    // Romence bildirim başlıkları
    var notificationTitle: String {
        switch self {
        case .fericit: return "Felicitări!"
        case .bucuros: return "Minunat!"
        case .neutru: return "Bună"
        case .trist: return "Zi dificilă?"
        case .furios: return "Te simți frustrat?"
        case .anxios: return "Te simți anxios?"
        }
    }
    
    // Romence bildirim içerikleri
    var notificationBody: String {
        switch self {
        case .fericit:
            return "Dispoziția ta este excelentă astăzi. Bucură-te de această zi specială!"
        case .bucuros:
            return "Mă bucur să văd că te simți bine astăzi. Continuă așa!"
        case .neutru:
            return "Ai înregistrat o dispoziție neutră. Poate o activitate plăcută ar putea îmbunătăți ziua ta?"
        case .trist:
            return "Ai înregistrat că te simți trist. Încearcă să vorbești cu cineva drag sau să faci o activitate care te bucură de obicei."
        case .furios:
            return "Ai înregistrat că te simți furios. Încearcă să iei o pauză și să faci ceva relaxant pentru a-ți calma emoțiile."
        case .anxios:
            return "Ai înregistrat că te simți anxios. Încearcă exerciții de respirație sau o scurtă plimbare în aer liber."
        }
    }
}

// MARK: - NotificationService
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    private let xmlBinaryPath = FileManager.documentsDirectory.appendingPathComponent("MoodEntries.xml")
    
    init() {
        requestNotificationPermission()
    }
    
    // Bildirim izni iste
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Permisiuni de notificare acordate")
            } else {
                print("Permisiuni de notificare refuzate: \(String(describing: error))")
            }
        }
        
        // Delegasyonu ayarla (bildirimlerin uygulama açıkken görünmesi için)
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
    }
    
    // Seçilen duygu için anlık bildirim gönder
    func sendMoodNotification(for mood: MoodType) {
        let content = UNMutableNotificationContent()
        content.title = mood.notificationTitle
        content.body = mood.notificationBody
        content.sound = UNNotificationSound.default
        
        // Hemen göster (1 saniye gecikme)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "mood-notification-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Eroare de notificare: \(error.localizedDescription)")
            } else {
                print("Notificare de dispoziție programată cu succes")
            }
        }
    }
    
    // Test bildirim gönder
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Notificare de test"
        content.body = "Aceasta este o notificare de test. Dacă o puteți vedea, notificările funcționează!"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-notification-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Eroare de notificare de test: \(error.localizedDescription)")
            } else {
                print("Notificare de test trimisă cu succes")
            }
        }
    }
}

// MARK: - NotificationHandler (Delegate for displaying notifications when app is in foreground)
class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Uygulama açıkken de bildirimleri göster
        completionHandler([.banner, .sound])
    }
}

// MARK: - MoodStore
class MoodStore: ObservableObject {
    @Published var moodEntries: [MoodEntry] = []
    private let savePath = FileManager.documentsDirectory.appendingPathComponent("MoodEntries.xml")
    
    init() {
        loadData()
    }
    
    func loadData() {
        do {
            if FileManager.default.fileExists(atPath: savePath.path) {
                let data = try Data(contentsOf: savePath)
                let decoder = PropertyListDecoder()
                moodEntries = try decoder.decode([MoodEntry].self, from: data)
            }
        } catch {
            print("Eroare la încărcarea datelor: \(error.localizedDescription)")
            moodEntries = []
        }
    }
    
    // Kaydet
    func save() {
        do {
            let encoder = PropertyListEncoder()
            let data = try encoder.encode(moodEntries)
            try data.write(to: savePath, options: [.atomic, .completeFileProtection])
        } catch {
            print("Eroare la salvarea datelor: \(error.localizedDescription)")
        }
    }
    
    // Yeni duygu ekle ve bildirim gönder
    func addMood(_ entry: MoodEntry) {
        moodEntries.append(entry)
        save()
        
        // Bu duygu durumu için hemen bildirim gönder
        NotificationService.shared.sendMoodNotification(for: entry.moodType)
    }
    
    // Duygu güncelle ve bildirim gönder
    func updateMood(_ entry: MoodEntry) {
        if let index = moodEntries.firstIndex(where: { $0.id == entry.id }) {
            moodEntries[index] = entry
            save()
            
            // Güncellenen duygu durumu için bildirim gönder
            NotificationService.shared.sendMoodNotification(for: entry.moodType)
        }
    }
    
    func deleteMood(at indexSet: IndexSet) {
        moodEntries.remove(atOffsets: indexSet)
        save()
    }
    
    func deleteMood(withId id: UUID) {
        if let index = moodEntries.firstIndex(where: { $0.id == id }) {
            moodEntries.remove(at: index)
            save()
        }
    }
    
    func getMoods(for date: Date) -> [MoodEntry] {
        return moodEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    func searchMoods(withKeyword keyword: String) -> [MoodEntry] {
        if keyword.isEmpty { return moodEntries }
        
        return moodEntries.filter { entry in
            entry.notes.lowercased().contains(keyword.lowercased()) ||
            entry.moodType.rawValue.lowercased().contains(keyword.lowercased())
        }
    }
}

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var moodStore = MoodStore()
    @State private var selectedDate = Date()
    @State private var showingAddMood = false
    @State private var showingUpdateMood = false
    @State private var selectedMoodEntry: MoodEntry?
    @State private var searchText = ""
    
    private var filteredMoods: [MoodEntry] {
        if searchText.isEmpty {
            return moodStore.getMoods(for: selectedDate)
        } else {
            return moodStore.searchMoods(withKeyword: searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Calendar View
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                    .onChange(of: selectedDate) { _ in
                        searchText = ""
                    }
                
                // Căutare - Arama
                SearchBar(text: $searchText, placeholder: "Căutare...")
                
                // Duygu Listesi
                List {
                    ForEach(filteredMoods) { entry in
                        MoodRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedMoodEntry = entry
                                showingUpdateMood = true
                            }
                    }
                    .onDelete(perform: deleteMoods)
                    
                    if filteredMoods.isEmpty {
                        Text("Nicio înregistrare pentru această zi")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                // Buttons - Düğmeler (Ekle Düğmesi)
                HStack {
                    Spacer()
                    Button(action: {
                        showingAddMood = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Adăugare")
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .padding(.trailing)
                }
                .padding(.bottom)
            }
            .navigationTitle("Urmăritor de Dispoziție")
            .sheet(isPresented: $showingAddMood) {
                AddMoodView(date: selectedDate, onAdd: { newEntry in
                    moodStore.addMood(newEntry)
                })
            }
            .sheet(isPresented: $showingUpdateMood) {
                if let entry = selectedMoodEntry {
                    UpdateMoodView(entry: entry, onUpdate: { updatedEntry in
                        moodStore.updateMood(updatedEntry)
                    }, onDelete: {
                        if let id = selectedMoodEntry?.id {
                            moodStore.deleteMood(withId: id)
                        }
                        showingUpdateMood = false
                    })
                }
            }
            .onAppear {
                // Bildirim izinlerini kontrol et
                NotificationService.shared.requestNotificationPermission()
            }
        }
    }
    
    // Seçilen duygu durumlarını silme
    private func deleteMoods(at offsets: IndexSet) {
        let entries = offsets.map { filteredMoods[$0] }
        for entry in entries {
            moodStore.deleteMood(withId: entry.id)
        }
    }
}

// MARK: - Supporting Views
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct MoodRow: View {
    let entry: MoodEntry
    
    var body: some View {
        HStack {
            Text(entry.moodType.emoji)
                .font(.title)
                .padding(8)
                .background(entry.moodType.color.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(entry.moodType.rawValue)
                    .font(.headline)
                
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "pencil")
                .foregroundColor(.blue)
                .padding(.trailing, 5)
        }
        .padding(.vertical, 4)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ro_RO")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: entry.date)
    }
}

// MARK: - Add/Edit Views

// 2. AddActivity - Duygu Ekleme Ekranı
struct AddMoodView: View {
    let date: Date
    let onAdd: (MoodEntry) -> Void
    
    @State private var notes = ""
    @State private var selectedMood: MoodType = .neutru
    @State private var selectedTime = Date()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                // Data/Time controller - Tarih/Saat kontrolü
                Section(header: Text("Data și ora")) {
                    DatePicker("", selection: $selectedTime, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // Duygu Seçici
                Section(header: Text("Dispoziție")) {
                    Picker("Selectați dispoziția", selection: $selectedMood) {
                        ForEach(MoodType.allCases, id: \.self) { mood in
                            HStack {
                                Text(mood.emoji)
                                Text(mood.rawValue)
                            }
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // Info TextBox - Metin Kutusu
                Section(header: Text("Notițe")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Adăugare Dispoziție")
            // Buttons - Düğmeler
            .navigationBarItems(
                leading: Button("Anulare") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Salvare") {
                    saveMood()
                }
            )
        }
    }
    
    private func saveMood() {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        
        if let combinedDate = Calendar.current.date(from: dateComponents) {
            let newEntry = MoodEntry(date: combinedDate, moodType: selectedMood, notes: notes)
            onAdd(newEntry)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}

// 3. UpdateActivity - Duygu Güncelleme Ekranı
struct UpdateMoodView: View {
    let entry: MoodEntry
    let onUpdate: (MoodEntry) -> Void
    let onDelete: () -> Void
    
    @State private var notes: String
    @State private var selectedMood: MoodType
    @State private var selectedTime: Date
    @Environment(\.presentationMode) var presentationMode
    
    init(entry: MoodEntry, onUpdate: @escaping (MoodEntry) -> Void, onDelete: @escaping () -> Void) {
        self.entry = entry
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        _notes = State(initialValue: entry.notes)
        _selectedMood = State(initialValue: entry.moodType)
        _selectedTime = State(initialValue: entry.date)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Data/Time controller - Tarih/Saat kontrolü
                Section(header: Text("Data și ora")) {
                    DatePicker("", selection: $selectedTime)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // Duygu Seçici
                Section(header: Text("Dispoziție")) {
                    Picker("Selectați dispoziția", selection: $selectedMood) {
                        ForEach(MoodType.allCases, id: \.self) { mood in
                            HStack {
                                Text(mood.emoji)
                                Text(mood.rawValue)
                            }
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // Info TextBox - Metin Kutusu
                Section(header: Text("Notițe")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                // Delete Button - Silme Düğmesi
                Section {
                    Button(action: {
                        onDelete()
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("Ștergere")
                            Spacer()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Editare Dispoziție")
            // Buttons - Düğmeler
            .navigationBarItems(
                leading: Button("Anulare") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Actualizare") {
                    updateMood()
                }
            )
        }
    }
    
    private func updateMood() {
        let updatedEntry = MoodEntry(id: entry.id, date: selectedTime, moodType: selectedMood, notes: notes)
        onUpdate(updatedEntry)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
