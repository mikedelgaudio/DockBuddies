import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteReader {
    private var db: OpaquePointer?

    init?(path: String) {
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
    }

    deinit {
        sqlite3_close(db)
    }

    struct Row {
        let columns: [String: String]
        func string(_ key: String) -> String { columns[key] ?? "" }
        func int(_ key: String) -> Int { Int(columns[key] ?? "0") ?? 0 }
    }

    func query(_ sql: String, params: [String] = []) -> [Row] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        for (i, param) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), param, -1, SQLITE_TRANSIENT)
        }

        var rows: [Row] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let colCount = sqlite3_column_count(stmt)
            var columns: [String: String] = [:]
            for i in 0..<colCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                if let text = sqlite3_column_text(stmt, i) {
                    columns[name] = String(cString: text)
                }
            }
            rows.append(Row(columns: columns))
        }
        return rows
    }
}
