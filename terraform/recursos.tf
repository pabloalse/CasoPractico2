### Máquina Virtual Ubuntu ###
resource "azurerm_resource_group" "CasoPractico2" {
  name     = "resources"
  location = var.location
}

resource "azurerm_virtual_network" "NetworkCasoPractico2" {
  name                = "network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.CasoPractico2.location
  resource_group_name = azurerm_resource_group.CasoPractico2.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.CasoPractico2.name
  virtual_network_name = azurerm_virtual_network.NetworkCasoPractico2.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "NetworkNicCasoPractico2" {
  name                = "nic"
  location            = azurerm_resource_group.CasoPractico2.location
  resource_group_name = azurerm_resource_group.CasoPractico2.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_public_ip" "public_ip" {
  name                = "publicIP"
  resource_group_name = azurerm_resource_group.CasoPractico2.name
  location            = azurerm_resource_group.CasoPractico2.location
  allocation_method   = "Dynamic"
}

output "public_ip_address" {
  value = azurerm_public_ip.public_ip.ip_address
} 

resource "azurerm_linux_virtual_machine" "VirtualMachineCasoPractico2" {
  name                = "VirtualMachineCasoPractico2"
  resource_group_name = azurerm_resource_group.CasoPractico2.name
  location            = azurerm_resource_group.CasoPractico2.location
  size                = "Standard_B2s"
  admin_username      = var.ssh_user

  network_interface_ids = [
    azurerm_network_interface.NetworkNicCasoPractico2.id,
  ]

  admin_ssh_key {
    username   = var.ssh_user
    public_key = file(var.public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_network_security_group" "SecurityGroupCasoPractico2" {
  name                = "SecurityGroupCasoPractico2"
  location            = azurerm_resource_group.CasoPractico2.location
  resource_group_name = azurerm_resource_group.CasoPractico2.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${trimspace(data.http.myip.body)}"
    destination_address_prefix = "*"
  }
}

output "my_public_ip_address" {
  value = "${data.http.myip.body}/32"
} 

resource "azurerm_network_interface_security_group_association" "interface_security_group_association" {
  network_interface_id      = azurerm_network_interface.NetworkNicCasoPractico2.id
  network_security_group_id = azurerm_network_security_group.SecurityGroupCasoPractico2.id
}

resource "azurerm_ssh_public_key" "sshPublicKeyCasopractico2" {
  name                = "sshPublicKeyCasopractico2"
  resource_group_name = azurerm_resource_group.CasoPractico2.name
  location            = azurerm_resource_group.CasoPractico2.location
  public_key          = file(var.public_key_path)
}

#### Azure Container Registry ###
resource "azurerm_container_registry" "containerRegistryCasoPractico2" {
  name                = "containerRegistryCasoPractico2"
  resource_group_name = azurerm_resource_group.CasoPractico2.name
  location            = azurerm_resource_group.CasoPractico2.location
  sku                 = "Basic"
  admin_enabled       = false
}

#### Azure Kubernetes Cluster ####

resource "azurerm_kubernetes_cluster" "AKSCasoPractico2" {
  name                = "AKSCasoPractico2"
  resource_group_name = azurerm_resource_group.CasoPractico2.name
  location            = azurerm_resource_group.CasoPractico2.location
  dns_prefix          = "DNSCasoPractico2"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

}

resource "azurerm_role_assignment" "roleAssignment" {
  principal_id                     = azurerm_kubernetes_cluster.AKSCasoPractico2.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.containerRegistryCasoPractico2.id
  skip_service_principal_aad_check = true
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.AKSCasoPractico2.kube_config.0.client_certificate
  sensitive = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.AKSCasoPractico2.kube_config_raw

  sensitive = true
}
