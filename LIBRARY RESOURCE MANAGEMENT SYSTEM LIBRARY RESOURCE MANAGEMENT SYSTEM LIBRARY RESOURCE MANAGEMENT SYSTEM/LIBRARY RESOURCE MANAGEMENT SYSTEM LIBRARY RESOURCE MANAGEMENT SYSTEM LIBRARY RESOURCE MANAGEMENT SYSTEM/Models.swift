import Foundation
import SwiftUI
import Combine

// MARK: - Error Handling
enum LibraryError: LocalizedError {
    case alreadyBorrowed(dueDate: Date)
    case referenceOnlyItem
    case licenseExpired
    case concurrencyLimitReached(limit: Int)
    case invalidLoanPeriod(maxDays: Int)
    case itemNotBorrowed

    var errorDescription: String? {
        switch self {
        case .alreadyBorrowed(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "Tài nguyên hiện đang được mượn đến ngày \(formatter.string(from: date))."
        case .referenceOnlyItem:
            return "Tài liệu này chỉ được phép đọc tại chỗ trong thư viện."
        case .licenseExpired:
            return "Bản quyền tài liệu điện tử đã hết hạn. Truy cập bị từ chối."
        case .concurrencyLimitReached(let limit):
            return "Đã đạt giới hạn tối đa (\(limit) người dùng đồng thời). Vui lòng thử lại sau."
        case .invalidLoanPeriod(let max):
            return "Vượt quá thời gian mượn tối đa cho phép (\(max) ngày)."
        case .itemNotBorrowed:
            return "Không thể trả tài nguyên chưa từng được mượn."
        }
    }
}

// MARK: - Enums & Supporting Types
enum UserRole: String, CaseIterable, Identifiable {
    case student = "Sinh viên"
    case lecturer = "Giảng viên"
    var id: String { rawValue }
}

enum BorrowStatus: Equatable {
    case available
    case borrowed(dueDate: Date, borrowerId: String)
    case referenceOnly
    case licenseExpired
}

// MARK: - Base Class
class LibraryResource: Identifiable, ObservableObject {
    let id: UUID
    let title: String
    let publicationYear: Int
    let isReferenceOnly: Bool
    
    @Published private(set) var status: BorrowStatus

    init(id: UUID = UUID(), title: String, publicationYear: Int, isReferenceOnly: Bool = false, status: BorrowStatus = .available) {
        self.id = id
        self.title = title
        self.publicationYear = publicationYear
        self.isReferenceOnly = isReferenceOnly
        self.status = isReferenceOnly ? .referenceOnly : status
    }

    var isAvailable: Bool {
        status == .available
    }

    var typeTag: String {
        "Tài nguyên chung"
    }

    func borrow(by user: UserRole, days: Int) throws {
        guard !isReferenceOnly else { throw LibraryError.referenceOnlyItem }
        guard case .available = status else {
            if case .borrowed(let dueDate, _) = status {
                throw LibraryError.alreadyBorrowed(dueDate: dueDate)
            }
            throw LibraryError.itemNotBorrowed
        }
        let due = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        status = .borrowed(dueDate: due, borrowerId: user.rawValue)
    }

    func returnResource() throws {
        guard case .borrowed = status else {
            throw LibraryError.itemNotBorrowed
        }
        status = .available
    }

    func calculateFee(days: Int, overdueDays: Int, role: UserRole) -> Double {
        return 0.0
    }
}

// MARK: - Subclasses
class PrintedBook: LibraryResource {
    let author: String
    let isbn: String
    let isShortLoan: Bool

    init(title: String, publicationYear: Int, author: String, isbn: String, isShortLoan: Bool = false) {
        self.author = author
        self.isbn = isbn
        self.isShortLoan = isShortLoan
        super.init(title: title, publicationYear: publicationYear)
    }

    override var typeTag: String { isShortLoan ? "Sách mượn ngắn hạn" : "Sách tiêu chuẩn" }

    override func borrow(by user: UserRole, days: Int) throws {
        if isShortLoan && days > 3 {
            throw LibraryError.invalidLoanPeriod(maxDays: 3)
        }
        try super.borrow(by: user, days: days)
    }

    override func calculateFee(days: Int, overdueDays: Int, role: UserRole) -> Double {
        let deposit = isShortLoan ? 10.0 : 5.0
        let overdueRate = (role == .student) ? 1.0 : 0.5
        return deposit + (Double(overdueDays) * overdueRate)
    }
}

class AcademicJournal: LibraryResource {
    let volume: Int
    let issue: Int

    init(title: String, publicationYear: Int, volume: Int, issue: Int, isReferenceOnly: Bool) {
        self.volume = volume
        self.issue = issue
        super.init(title: title, publicationYear: publicationYear, isReferenceOnly: isReferenceOnly)
    }

    override var typeTag: String { "Tạp chí học thuật" }

    override func calculateFee(days: Int, overdueDays: Int, role: UserRole) -> Double {
        guard !isReferenceOnly else { return 0.0 }
        return Double(overdueDays) * 3.0
    }
}

class DigitalMaterial: LibraryResource {
    let licenseExpiration: Date
    let maxSeats: Int
    @Published private(set) var activeSeats: Int = 0

    init(title: String, publicationYear: Int, licenseExpiration: Date, maxSeats: Int) {
        self.licenseExpiration = licenseExpiration
        self.maxSeats = maxSeats
        super.init(title: title, publicationYear: publicationYear)
    }

    override var typeTag: String { "Tài liệu số" }

    override var isAvailable: Bool {
        Date() <= licenseExpiration && activeSeats < maxSeats
    }

    func accessOnline() throws {
        guard Date() <= licenseExpiration else {
            throw LibraryError.licenseExpired
        }
        guard activeSeats < maxSeats else {
            throw LibraryError.concurrencyLimitReached(limit: maxSeats)
        }
        activeSeats += 1
    }

    func releaseOnline() {
        if activeSeats > 0 { activeSeats -= 1 }
    }

    override func calculateFee(days: Int, overdueDays: Int, role: UserRole) -> Double {
        return role == .lecturer ? 0.0 : 2.50
    }
}
