variable "subscription_id" { default = "x" }
variable "client_id" { default = "x" }
variable "client_secret" { default = "x" }
variable "tenant_id" { default = "x" }

variable "count" { default = "5" }

variable "location" { default = "West Europe" }

variable "name" { default = "trnsdfs3" }
variable "vm_size" { default = "Standard_DS2" }

variable "storagetype" { default = "Premium_LRS"}

variable "publisher" { default = "MicrosoftVisualStudio" }
variable "offer" { default = "VisualStudio" }
variable "sku" { default = "VS-2015-Comm-AzureSDK-2.9-W10T-Win10-N" }
variable "version" { default = "latest" }


variable "username" { default = "adminuser" }
variable "password" { default = "Pass654321" }

# Configure the Azure Resource Manager Provider
provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

resource "azurerm_resource_group" "trainingvms" {
    name = "${var.name}resourcegroup"
    location = "${var.location}"
}

resource "azurerm_virtual_network" "vnet" {
    name = "${var.name}vnet"
    address_space = ["10.0.0.0/16"]
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.trainingvms.name}"
}

resource "azurerm_subnet" "subnet" {
    name = "${var.name}subnet"
    resource_group_name = "${azurerm_resource_group.trainingvms.name}"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"
    address_prefix = "10.0.2.0/24"
}


resource "azurerm_public_ip" "publicip" {
    count = "${var.count}"
    name = "${var.name}${count.index}"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.trainingvms.name}"
    public_ip_address_allocation = "static"
}


resource "azurerm_network_interface" "nic" {
    count = "${var.count}"
    name = "${var.name}nic${count.index}"
    location = "${var.location}"
    resource_group_name = "${azurerm_resource_group.trainingvms.name}"

    ip_configuration {
        name = "testconfiguration1"
        subnet_id = "${azurerm_subnet.subnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id = "${element(azurerm_public_ip.publicip.*.id, count.index)}"
    }
}


resource "azurerm_storage_account" "storage" {
    name = "${var.name}srg123"
    resource_group_name = "${azurerm_resource_group.trainingvms.name}"
    location = "${var.location}"
    account_type = "${var.storagetype}"
}

resource "azurerm_storage_container" "container" {
    name = "vhds"
    resource_group_name = "${azurerm_resource_group.trainingvms.name}"
    storage_account_name = "${azurerm_storage_account.storage.name}"
    container_access_type = "private"
}


resource "azurerm_virtual_machine" "vm" {
  count = "${var.count}"
  name                  = "${var.name}${count.index}"
  location              = "${var.location}"	
  resource_group_name   = "${azurerm_resource_group.trainingvms.name}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  vm_size               = "${var.vm_size}"

  storage_image_reference {
    publisher = "${var.publisher}"
    offer     = "${var.offer}"
    sku       = "${var.sku}"
    version   = "${var.version}"
  }

  storage_os_disk {
    name          = "${var.name}${count.index}"
    vhd_uri       = "${azurerm_storage_account.storage.primary_blob_endpoint}${azurerm_storage_container.container.name}/${var.name}${count.index}-osdisk.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "${var.name}${count.index}"
    admin_username = "${var.username}"
    admin_password = "${var.password}"
  }
}

output "ip" {
  value = "${join(", ", azurerm_public_ip.publicip.*.ip_address)}"
}
