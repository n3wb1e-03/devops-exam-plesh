resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = "norwayeast"
}

# 1. VPC (VNet)
resource "azurerm_virtual_network" "vpc" {
  name                = "${var.prefix}-vpc"
  address_space       = ["10.10.10.0/24"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vpc.name
  address_prefixes     = ["10.10.10.0/24"]
}

# 2. Фаєрвол (NSG)
resource "azurerm_network_security_group" "firewall" {
  name                = "${var.prefix}-firewall"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  dynamic "security_rule" {
    for_each = ["22", "80", "443", "8000", "8001", "8002", "8003"]
    content {
      name                       = "Allow-${security_rule.value}"
      priority                   = 100 + index(["22", "80", "443", "8000", "8001", "8002", "8003"], security_rule.value)
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  security_rule {
    name                       = "Allow-All-Outbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "1-65535"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Публічна IP та мережевий інтерфейс
resource "azurerm_public_ip" "pip" {
  name                = "${var.prefix}-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.firewall.id
}

# 3. ВМ (Node)
resource "azurerm_linux_virtual_machine" "node" {
  name                = "${var.prefix}-node"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_D2s_v3" # 2 vCPU, 8GB RAM для Minikube
  admin_username      = "adminuser"
  
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "adminuser"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

# 4. Сховище для обʼєктів (Bucket)
resource "azurerm_storage_account" "bucket" {
  name                     = "${var.prefix}bucket" # Лише малі літери і цифри
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
