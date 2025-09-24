import Foundation

enum Filter: Int, CaseIterable, Identifiable {
    case all
    case active
    case completed
    
    var id: Int { rawValue }
}

enum Sort: Int, CaseIterable, Identifiable {
    case titleAsc
    case titleDesc
    case status
    
    var id: Int { rawValue }
}
