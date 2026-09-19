locals {
  name_prefix = "${var.app_name}-${substr(md5(var.resource_group_name), 0, 8)}"
  common_tags = {
    application = var.app_name
    managed_by  = "terraform"
  }
}

data "azurerm_resource_group" "main" {
  # The deployment targets an existing resource group supplied by the caller.
  name = var.resource_group_name
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name_prefix}-logs"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

resource "azurerm_network_security_group" "public" {
  name                = "${local.name_prefix}-public-nsg"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.common_tags

  security_rule {
    name                       = "allow-https"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "private_db" {
  name                = "${local.name_prefix}-private-db-nsg"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.common_tags

  security_rule {
    name                       = "allow-postgres-from-aks"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = var.aks_subnet_prefixes[0]
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "main" {
  # The VNet separates internet-facing, AKS, and private database traffic.
  name                = "${local.name_prefix}-vnet"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = var.vnet_address_space
  tags                = local.common_tags
}

resource "azurerm_subnet" "public" {
  # Public subnet reserved for ingress or other internet-facing components.
  name                 = "public"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.public_subnet_prefixes
}

resource "azurerm_subnet" "private_db" {
  # PostgreSQL is delegated to this private subnet and has public access disabled.
  name                 = "private-db"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.private_db_subnet_prefixes
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "postgresql-flexible-server"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "private_db" {
  subnet_id                 = azurerm_subnet.private_db.id
  network_security_group_id = azurerm_network_security_group.private_db.id
}

resource "azurerm_subnet" "aks" {
  # AKS nodes run in their own subnet and reach PostgreSQL through private networking.
  name                 = "aks"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.aks_subnet_prefixes
}

resource "azurerm_container_registry" "main" {
  # ACR admin credentials stay disabled; AKS pulls through its managed identity.
  name                = replace("${local.name_prefix}acr", "-", "")
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "${local.name_prefix}.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${local.name_prefix}-postgres-dns-link"
  resource_group_name   = data.azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_postgresql_flexible_server" "main" {
  # The database uses the delegated private subnet and private DNS zone.
  name                          = "${local.name_prefix}-postgres"
  resource_group_name           = data.azurerm_resource_group.main.name
  location                      = data.azurerm_resource_group.main.location
  version                       = "16"
  delegated_subnet_id           = azurerm_subnet.private_db.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  administrator_login           = var.postgres_admin_login
  administrator_password        = var.postgres_admin_password
  storage_mb                    = 32768
  sku_name                      = "B_Standard_B1ms"
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = false
  tags                          = local.common_tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.postgres_database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_key_vault" "main" {
  # RBAC authorization avoids broad, legacy access policies.
  name                       = "${local.name_prefix}-kv"
  location                   = data.azurerm_resource_group.main.location
  resource_group_name        = data.azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
  public_network_access_enabled = true
  enable_rbac_authorization  = true
  tags                       = local.common_tags
}

resource "azurerm_key_vault_secret" "postgres_password" {
  # The password enters Terraform as a sensitive value and is persisted in Key Vault.
  name         = "postgres-admin-password"
  value        = var.postgres_admin_password
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.terraform_key_vault_secrets_officer]
}

resource "azurerm_kubernetes_cluster" "main" {
  # AKS runs the application container with Azure RBAC and workload identity enabled.
  name                = "${local.name_prefix}-aks"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = "${local.name_prefix}-dns"
  sku_tier            = "Free"
  kubernetes_version  = null
  tags                = local.common_tags

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name           = "system"
    node_count     = var.aks_node_count
    vm_size        = var.aks_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  # Grant only image-pull permission on this registry to the AKS kubelet identity.
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "aks_key_vault_secrets_user" {
  # Allow the Key Vault Secrets Provider identity to read secrets, without write access.
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].object_id
}

resource "azurerm_role_assignment" "terraform_key_vault_secrets_officer" {
  # Terraform needs narrowly scoped secret-management access to create the initial secret.
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

data "azurerm_client_config" "current" {}
