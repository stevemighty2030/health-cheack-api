variable "subscription_id" {
  description = "Azure subscription ID used for deployment."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group that owns the infrastructure."
  type        = string
}

variable "location" {
  description = "Azure region for the resources."
  type        = string
  default     = "eastus"
}

variable "app_name" {
  description = "Short application name used in resource names."
  type        = string
  default     = "dbhealth"
}

variable "aks_node_count" {
  description = "Number of AKS system nodes."
  type        = number
  default     = 2
}

variable "aks_vm_size" {
  description = "AKS node VM size."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "postgres_admin_login" {
  description = "PostgreSQL administrator login."
  type        = string
  default     = "appadmin"
}

variable "postgres_admin_password" {
  description = "PostgreSQL administrator password, supplied through a secure variable or secret store."
  type        = string
  sensitive   = true
}

variable "postgres_database_name" {
  description = "Application database name."
  type        = string
  default     = "healthdb"
}

variable "vnet_address_space" {
  description = "Virtual network address space."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "public_subnet_prefixes" {
  description = "Public subnet address prefixes."
  type        = list(string)
  default     = ["10.20.1.0/24"]
}

variable "private_db_subnet_prefixes" {
  description = "Private PostgreSQL subnet address prefixes."
  type        = list(string)
  default     = ["10.20.2.0/24"]
}

variable "aks_subnet_prefixes" {
  description = "AKS subnet address prefixes."
  type        = list(string)
  default     = ["10.20.3.0/22"]
}
