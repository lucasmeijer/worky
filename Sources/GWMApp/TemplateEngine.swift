struct TemplateEngine {
    func apply(_ parts: [String], variables: [String: String]) -> [String] {
        let keys = variables.keys.sorted { $0.count > $1.count }
        return parts.map { part in
            var result = part
            for key in keys {
                if let value = variables[key] {
                    result = result.replacingOccurrences(of: "$\(key)", with: value)
                }
            }
            return result
        }
    }
}
