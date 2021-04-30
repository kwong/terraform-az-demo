

resource "azurerm_resource_group" "ci_rg" {
  name     = "ci-rg"
  location = "West Europe"
}

resource "azurerm_virtual_network" "ci_vnet" {
  name                = "ci-vnet"
  address_space       = ["10.0.0.0/16"]
  resource_group_name = azurerm_resource_group.ci_rg.name
  location            = azurerm_resource_group.ci_rg.location
}

resource "azurerm_subnet" "ci_subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.ci_rg.name
  virtual_network_name = azurerm_virtual_network.ci_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# resource "azurerm_public_ip" "ci_public_ip" {
#   name = "ci_public_ip"
#   location = azurerm_resource_group.ci_rg.location
#   resource_group_name = azurerm_resource_group.ci_rg.name
#   allocation_method = "Dynamic"

# }

resource "azurerm_network_interface" "ci_netint" {
  name                = "vm-nic"
  location            = azurerm_resource_group.ci_rg.location
  resource_group_name = azurerm_resource_group.ci_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ci_subnet.id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id = azurerm_public_ip.ci_public_ip.id
  }
}


resource "azurerm_network_security_group" "ci_nsg" {
  name                = "ci_nsg"
  location            = azurerm_resource_group.ci_rg.location
  resource_group_name = azurerm_resource_group.ci_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

resource "azurerm_network_interface_security_group_association" "ci_nic_assoc" {
  network_interface_id      = azurerm_network_interface.ci_netint.id
  network_security_group_id = azurerm_network_security_group.ci_nsg.id
}

resource "azurerm_linux_virtual_machine" "ci_vm" {
  name                = "cipib4-packer-vm"
  resource_group_name = azurerm_resource_group.ci_rg.name
  location            = azurerm_resource_group.ci_rg.location
  size                = "Standard_B2s"
  admin_username      = "rbuser"

  network_interface_ids = [azurerm_network_interface.ci_netint.id]

  admin_ssh_key {
    username   = var.admin_user
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

### BASTION


resource "azurerm_subnet" "bastion_sn" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.ci_rg.name
  virtual_network_name = azurerm_virtual_network.ci_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "bastion_ip" {
  name                = "cipib4_bastion_ip"
  location            = azurerm_resource_group.ci_rg.location
  resource_group_name = azurerm_resource_group.ci_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion_host" {
  name                = "cipib4_bastion_host"
  location            = azurerm_resource_group.ci_rg.location
  resource_group_name = azurerm_resource_group.ci_rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_sn.id
    public_ip_address_id = azurerm_public_ip.bastion_ip.id
  }
}