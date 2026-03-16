extension String {
    /// Trim whitespace and newlines, return nil if result is empty
    public func trimmingBlank() -> String? {
        let trimmedString = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedString.isEmpty ? nil : trimmedString
    }
}
