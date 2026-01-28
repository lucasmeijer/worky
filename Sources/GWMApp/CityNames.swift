struct CityNamePicker {
    let names: [String]
    let randomIndex: (Int) -> Int

    init(names: [String] = CityNames.list, randomIndex: @escaping (Int) -> Int = { upper in
        Int.random(in: 0..<max(upper, 1))
    }) {
        self.names = names
        self.randomIndex = randomIndex
    }

    func pick(used: Set<String>) -> String {
        guard !names.isEmpty else { return "worktree" }
        let start = randomIndex(names.count)
        for offset in 0..<names.count {
            let idx = (start + offset) % names.count
            let candidate = names[idx]
            if !used.contains(candidate) {
                return candidate
            }
        }
        let base = names[start]
        var suffix = 2
        while used.contains("\(base)-\(suffix)") {
            suffix += 1
        }
        return "\(base)-\(suffix)"
    }
}

enum CityNames {
    static let list: [String] = [
        "amsterdam", "athens", "auckland", "austin", "bangalore", "bangkok", "barcelona", "beijing",
        "belgrade", "berlin", "bogota", "boston", "brisbane", "bristol", "brooklyn", "brussels",
        "bucharest", "budapest", "buenos-aires", "cairo", "calgary", "cape-town", "caracas",
        "casablanca", "chicago", "cincinnati", "copenhagen", "dallas", "delhi", "denver",
        "detroit", "doha", "dublin", "dubai", "edinburgh", "florence", "frankfurt", "geneva",
        "glasgow", "guadalajara", "guangzhou", "hamburg", "hanoi", "helsinki", "ho-chi-minh",
        "hong-kong", "honolulu", "houston", "hyderabad", "istanbul", "jakarta", "jerusalem",
        "johannesburg", "karachi", "kiev", "kyoto", "lagos", "lahore", "lausanne", "lima",
        "lisbon", "ljubljana", "london", "los-angeles", "lyon", "madrid", "manchester",
        "manila", "melbourne", "mexico-city", "miami", "milan", "minneapolis", "montreal",
        "moscow", "mumbai", "munich", "nairobi", "naples", "new-orleans", "new-york",
        "nice", "nicosia", "osaka", "oslo", "ottawa", "palermo", "paris", "perth",
        "philadelphia", "phoenix", "porto", "porto-alegre", "prague", "quebec",
        "reykjavik", "rio", "riyadh", "rome", "rotterdam", "san-diego", "san-francisco",
        "santiago", "sao-paulo", "seattle", "seoul", "shanghai", "shenzhen", "singapore",
        "sofia", "stockholm", "stuttgart", "sydney", "taipei", "tallinn", "tel-aviv",
        "tokyo", "toronto", "valencia", "vancouver", "venice", "vienna", "warsaw",
        "washington", "wellington", "winnipeg", "zurich"
    ]
}
