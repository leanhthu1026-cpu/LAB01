import SwiftUI

struct ContentView: View {
    @StateObject private var store = LibraryStore()
    @State private var selectedRole: UserRole = .student

    var body: some View {
        NavigationStack {
            ZStack {
                // Background Image "AT1"
                Image("AT1")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(100)

                VStack(spacing: 0) {
                    Picker("Vai trò người dùng", selection: $selectedRole) {
                        ForEach(UserRole.allCases) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    List(store.resources) { item in
                        NavigationLink(destination: ResourceDetailView(resource: item, userRole: selectedRole)) {
                            ResourceRowView(resource: item)
                        }
                        .listRowBackground(Color.white.opacity(0.75))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Thư Viện Đại Học")
        }
    }
}

struct ResourceRowView: View {
    @ObservedObject var resource: LibraryResource

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(resource.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(resource.typeTag)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            HStack {
                Text("Năm XB: \(String(resource.publicationYear))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                statusTag
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusTag: some View {
        switch resource.status {
        case .available:
            Text("Sẵn sàng").font(.caption).bold().foregroundColor(.green)
        case .borrowed:
            Text("Đang được mượn").font(.caption).bold().foregroundColor(.orange)
        case .referenceOnly:
            Text("Đọc tại chỗ").font(.caption).bold().foregroundColor(.purple)
        case .licenseExpired:
            Text("Hết hạn quyền").font(.caption).bold().foregroundColor(.red)
        }
    }
}

struct ResourceDetailView: View {
    @ObservedObject var resource: LibraryResource
    let userRole: UserRole

    @State private var requestedDays: Double = 3
    @State private var overdueDays: Double = 0
    @State private var alertErrorMessage: String?
    @State private var showAlert = false

    var body: some View {
        ZStack {
            // Background Image "AT1"
            Image("AT1")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.18)

            Form {
                Section("Thông Tin Chi Tiết") {
                    LabeledContent("Tiêu đề", value: resource.title)
                    LabeledContent("Năm xuất bản", value: String(resource.publicationYear))
                    LabeledContent("Phân loại", value: resource.typeTag)

                    if let book = resource as? PrintedBook {
                        LabeledContent("Tác giả", value: book.author)
                        LabeledContent("Mã ISBN", value: book.isbn)
                        LabeledContent("Chính sách mượn", value: book.isShortLoan ? "Ngắn hạn (Tối đa 3 ngày)" : "Tiêu chuẩn (21 ngày)")
                    } else if let journal = resource as? AcademicJournal {
                        LabeledContent("Số tập (Volume)", value: String(journal.volume))
                        LabeledContent("Số phát hành (Issue)", value: String(journal.issue))
                        LabeledContent("Lưu hành", value: journal.isReferenceOnly ? "Chỉ đọc tại chỗ" : "Được phép mượn")
                    } else if let digital = resource as? DigitalMaterial {
                        LabeledContent("Số chỗ đang dùng", value: "\(digital.activeSeats) / \(digital.maxSeats)")
                        LabeledContent("Ngày hết hạn bản quyền", value: digital.licenseExpiration.formatted(date: .numeric, time: .omitted))
                    }
                }
                .listRowBackground(Color.white.opacity(0.85))

                Section("Mô Phỏng Tính Phí") {
                    Stepper("Thời gian mượn: \(Int(requestedDays)) ngày", value: $requestedDays, in: 1...30)
                    Stepper("Số ngày trễ hạn: \(Int(overdueDays)) ngày", value: $overdueDays, in: 0...30)

                    let totalFee = resource.calculateFee(days: Int(requestedDays), overdueDays: Int(overdueDays), role: userRole)
                    LabeledContent("Tổng phí áp dụng", value: String(format: "$%.2f", totalFee))
                        .bold()
                }
                .listRowBackground(Color.white.opacity(0.85))

                Section("Thao Tác Nghiệp Vụ") {
                    if let digital = resource as? DigitalMaterial {
                        Button("Truy Cập Trực Tuyến") {
                            handleAction { try digital.accessOnline() }
                        }
                        Button("Kết Thúc Phiên Truy Cập") {
                            digital.releaseOnline()
                        }
                        .foregroundColor(.secondary)
                    } else {
                        Button("Mượn Tài Nguyên") {
                            handleAction {
                                try resource.borrow(by: userRole, days: Int(requestedDays))
                            }
                        }
                        .disabled(!resource.isAvailable)

                        Button("Trả Tài Nguyên (Hợp lệ)") {
                            handleAction {
                                try resource.returnResource()
                            }
                        }
                        .disabled(resource.isAvailable || resource.isReferenceOnly)

                        Button("Thao Tác Sai: Cố tình trả khi chưa mượn") {
                            handleAction {
                                try resource.returnResource()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
                .listRowBackground(Color.white.opacity(0.85))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Chi Tiết Tài Nguyên")
        .alert("Thao Tác Bị Từ Chối", isPresented: $showAlert) {
            Button("Đã hiểu", role: .cancel) { }
        } message: {
            Text(alertErrorMessage ?? "Lỗi xác thực không xác định.")
        }
    }

    private func handleAction(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            self.alertErrorMessage = error.localizedDescription
            self.showAlert = true
        }
    }
}
