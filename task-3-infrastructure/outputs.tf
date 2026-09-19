output "acr_login_server" {
  description = "ACR login server used by the CI/CD pipelines."
  value       = azurerm_container_registry.main.login_server
}

output "aks_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.main.name
}

output "postgres_host" {
  description = "Private PostgreSQL fully qualified domain name."
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "key_vault_uri" {
  description = "Key Vault URI used by the workload secrets provider."
  value       = azurerm_key_vault.main.vault_uri
}
