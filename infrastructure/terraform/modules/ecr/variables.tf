# Prefix separates this environment's repositories from test and production.
variable "name_prefix" {
  description = "Lowercase project/environment prefix, for example healthops-dev."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,49}$", var.name_prefix))
    error_message = "Use 2–50 lowercase letters, digits or hyphens; start with a letter."
  }
}

# Map keys become the final segment of each repository name.
variable "repositories" {
  description = "Repository suffixes for the application images."
  type        = set(string)
  default     = ["api", "mock-model"]
  validation {
    condition = length(var.repositories) > 0 && alltrue([
      for name in var.repositories : can(regex("^[a-z][a-z0-9-]{0,49}$", name))
    ])
    error_message = "Provide at least one simple lowercase repository suffix."
  }
}

# Clean up unused untagged images, while retaining tagged releases for rollback.
variable "untagged_retention_days" {
  description = "Expire untagged images this many days after their push time."
  type        = number
  default     = 14
  validation {
    condition     = var.untagged_retention_days >= 1 && floor(var.untagged_retention_days) == var.untagged_retention_days
    error_message = "Retention must be a positive whole number of days."
  }
}

# Apply ownership and environment labels to repositories and their shared key.
variable "tags" {
  description = "Project, Environment, ManagedBy and Owner tags supplied by the root."
  type        = map(string)
}
