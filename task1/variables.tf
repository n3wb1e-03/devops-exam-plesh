variable "ssh_public_key" {
  description = "Public SSH key for the virtual machine"
  type        = string
}

variable "prefix" {
  description = "Prefix for all resources (your lastname)"
  type        = string
  default     = "plesh"
}
