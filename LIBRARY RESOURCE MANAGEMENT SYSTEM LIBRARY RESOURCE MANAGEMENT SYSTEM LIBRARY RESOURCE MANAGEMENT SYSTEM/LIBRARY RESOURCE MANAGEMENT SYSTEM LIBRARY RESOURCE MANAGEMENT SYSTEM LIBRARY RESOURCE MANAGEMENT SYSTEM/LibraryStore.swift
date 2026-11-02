import Foundation
import SwiftUI
import Combine

class LibraryStore: ObservableObject {
    @Published var resources: [LibraryResource] = []

    init() {
        loadSampleData()
    }

    private func loadSampleData() {
        let pastDate = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let futureDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!

        let book1 = PrintedBook(
            title: "Lập trình iOS với Swift",
            publicationYear: 2023,
            author: "Apple Education",
            isbn: "978-0134494166",
            isShortLoan: false
        )
        let book2 = PrintedBook(
            title: "Tài liệu Dự bị Không gian (Giới hạn)",
            publicationYear: 2024,
            author: "NASA / ESA",
            isbn: "978-1563475313",
            isShortLoan: true
        )
        
        // Mượn trước 1 cuốn để demo trạng thái Checked Out
        try? book1.borrow(by: .student, days: 14)

        let journalRef = AcademicJournal(
            title: "Tạp chí Vật lý Địa cầu & Vũ trụ",
            publicationYear: 2025,
            volume: 48,
            issue: 3,
            isReferenceOnly: true
        )
        let journalCirc = AcademicJournal(
            title: "Nghiên cứu Kỹ thuật Hàng không",
            publicationYear: 2024,
            volume: 12,
            issue: 1,
            isReferenceOnly: false
        )

        let digitalActive = DigitalMaterial(
            title: "Cơ sở dữ liệu Vệ tinh Landsat",
            publicationYear: 2026,
            licenseExpiration: futureDate,
            maxSeats: 2
        )
        let digitalExpired = DigitalMaterial(
            title: "Kho lưu trữ Viễn thám Cũ (Hết hạn)",
            publicationYear: 2019,
            licenseExpiration: pastDate,
            maxSeats: 5
        )

        resources = [book1, book2, journalRef, journalCirc, digitalActive, digitalExpired]
    }
}
