extension String {
  public func trimmingBlank() -> String? {
    let trimmedString = self.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedString.isEmpty == true ? nil : trimmedString
  }
}
