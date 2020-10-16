terraform {
    backend "local" {
    }
}

provider "azurerm" {
  alias  = "production"

  features {}

  subscription_id = var.subscription_production

  version = "~>2.21.0"
}

provider "azurerm" {
    #alias = "target"

    features {}

    subscription_id = var.environment == "production" ? var.subscription_production : var.subscription_test

    version = "~>2.21.0"
}

provider "azuread" {
  version = "=0.11.0"

  subscription_id = var.environment == "production" ? var.subscription_production : var.subscription_test
}


#
# LOCALS
#

locals {
  location_map = {
    australiacentral = "auc",
    australiacentral2 = "auc2",
    australiaeast = "aue",
    australiasoutheast = "ause",
    brazilsouth = "brs",
    canadacentral = "cac",
    canadaeast = "cae",
    centralindia = "inc",
    centralus = "usc",
    eastasia = "ase",
    eastus = "use",
    eastus2 = "use2",
    francecentral = "frc",
    francesouth = "frs",
    germanynorth = "den",
    germanywestcentral = "dewc",
    japaneast = "jpe",
    japanwest = "jpw",
    koreacentral = "krc",
    koreasouth = "kre",
    northcentralus = "usnc",
    northeurope = "eun",
    norwayeast = "noe",
    norwaywest = "now",
    southafricanorth = "zan",
    southafricawest = "zaw",
    southcentralus = "ussc",
    southeastasia = "asse",
    southindia = "ins",
    switzerlandnorth = "chn",
    switzerlandwest = "chw",
    uaecentral = "aec",
    uaenorth = "aen",
    uksouth = "uks",
    ukwest = "ukw",
    westcentralus = "uswc",
    westeurope = "euw",
    westindia = "inw",
    westus = "usw",
    westus2 = "usw2",
  }
}

locals {
  environment_short = substr(var.environment, 0, 1)
  location_short = lookup(local.location_map, var.location, "aue")
}

# Name prefixes
locals {
  name_prefix = "${local.environment_short}-${local.location_short}"
  name_prefix_tf = "${local.name_prefix}-tf-${var.category}-${var.spoke_id}"
}

locals {
  common_tags = {
    category    = "${var.category}"
    datacenter  = "${var.datacenter}-${var.spoke_id}"
    environment = "${var.environment}"
    image_version = "${var.resource_version}"
    location    = "${var.location}"
    source      = "${var.meta_source}"
    version     = "${var.meta_version}"
  }

  extra_tags = {
  }
}

locals {
  admin_username = "thebigkahuna"
}

data "azurerm_client_config" "current" {}

locals {
  spoke_base_name = "t-aue-tf-nwk-spoke-${var.spoke_id}"
  spoke_resource_group = "${local.spoke_base_name}-rg"
  spoke_vnet = "${local.spoke_base_name}-vn"
  service_discovery_base_name = "t-aue-tf-cv-core-sd-${var.spoke_id}"
}

data "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name = "p-aue-tf-analytics-law-logs"
  provider = azurerm.production
  resource_group_name = "p-aue-tf-analytics-rg"
}

data "azurerm_subnet" "sn" {
  name = "${local.spoke_base_name}-sn"
  virtual_network_name = local.spoke_vnet
  resource_group_name = local.spoke_resource_group
}

data "azuread_group" "proxy_server_discovery" {
  name = "${local.spoke_base_name}-adg-consul-cloud-join"
}

data "azurerm_resource_group" "proxy_server_discovery" {
    name = "${local.service_discovery_base_name}-rg"
}


#
# RESOURCE GROUP
#

resource "azurerm_resource_group" "rg" {
    name = "${local.name_prefix_tf}-rg"
    location = var.location

    tags = merge( local.common_tags, local.extra_tags, var.tags )
}

#
# Azure load balancer
#

resource "azurerm_lb" "lb" {
    location = var.location
    name = "${local.name_prefix_tf}-lb"
    resource_group_name = azurerm_resource_group.rg.name

    frontend_ip_configuration {
        name = "${local.name_prefix_tf}-lb-ipc"
        subnet_id = data.azurerm_subnet.sn.id
    }

    tags = merge(
        local.common_tags,
        local.extra_tags,
        var.tags,
        {
        } )
}

resource "azurerm_lb_backend_address_pool" "lb" {
    loadbalancer_id = azurerm_lb.lb.id
    name = "${local.name_prefix_tf}-lb-be-vmss"
    resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_lb_probe" "lb_probe" {
    interval_in_seconds = 10
    loadbalancer_id = azurerm_lb.lb.id
    name = "${local.name_prefix_tf}-lb-pr-fabio"
    number_of_probes = 3
    port = 9998
    protocol = "Http"
    request_path = "/health"
    resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_lb_rule" "lb_rule_http" {
    backend_port = 80
    backend_address_pool_id = azurerm_lb_backend_address_pool.lb.id
    frontend_ip_configuration_name = "${local.name_prefix_tf}-lb-ipc"
    frontend_port = 80
    loadbalancer_id = azurerm_lb.lb.id
    name = "Http"
    protocol = "Tcp"
    probe_id = azurerm_lb_probe.lb_probe.id
    resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_lb_rule" "lb_rule_ui" {
    backend_port = 9998
    backend_address_pool_id = azurerm_lb_backend_address_pool.lb.id
    frontend_ip_configuration_name = "${local.name_prefix_tf}-lb-ipc"
    frontend_port = 9998
    loadbalancer_id = azurerm_lb.lb.id
    name = "Fabio-UI"
    protocol = "Tcp"
    probe_id = azurerm_lb_probe.lb_probe.id
    resource_group_name = azurerm_resource_group.rg.name
}

#
# DNS name pointing to load balancer
#

# resource "azurerm_dns_a_record" "example" {
#     name = "test"
#     zone_name = azurerm_dns_zone.example.name
#     resource_group_name = azurerm_resource_group.example.name
#     ttl = 300
#     records = ["10.0.180.17"]
# }

#
# Certificate for the DNS record
#

#
# PROXY SERVER
#

locals {
    name_proxy_server = "proxy-server"
}

# Locate the existing proxy image
data "azurerm_image" "search_proxy_server" {
    name = "resource-proxy-edge-${var.resource_version}"
    resource_group_name = "t-aue-artefacts-rg"
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss_proxy" {
    admin_password = var.admin_password
    admin_username = local.admin_username

    automatic_instance_repair {
        enabled = true
    }

    custom_data = base64encode(templatefile(
        "${abspath(path.root)}/cloud_init_client.yaml",
        {
            cluster_size = var.cluster_size,
            consul_cert_bundle = filebase64("${var.consul_cert_path}/${var.domain_consul}-agent-ca.pem"),
            datacenter = "${var.datacenter}-${var.spoke_id}",
            domain = var.domain_consul,
            encrypt = var.encrypt_consul,
            environment_id = local.service_discovery_base_name,
            subscription = var.environment == "production" ? var.subscription_production : var.subscription_test,
            vnet_forward_ip = cidrhost(data.azurerm_subnet.sn.address_prefixes[0], 1)
        }))

    disable_password_authentication = false

    health_probe_id = azurerm_lb_probe.lb_probe.id

    identity {
        type = "SystemAssigned"
    }

    instances = var.cluster_size

    location = var.location

    name = "${local.name_prefix_tf}-vmss-${local.name_proxy_server}"

    network_interface {
        name = "${local.name_prefix_tf}-nic-proxy-server"
        network_security_group_id = data.azurerm_subnet.sn.network_security_group_id
        primary = true

        ip_configuration {
            load_balancer_backend_address_pool_ids = [
                azurerm_lb_backend_address_pool.lb.id
            ]

            name = "${local.name_prefix_tf}-nicconf-proxy-server"

            primary = true
            subnet_id = data.azurerm_subnet.sn.id
        }
    }

    os_disk {
        caching = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    resource_group_name = azurerm_resource_group.rg.name

    sku = "Standard_DS1_v2"

    source_image_id = data.azurerm_image.search_proxy_server.id

    tags = merge(
        local.common_tags,
        local.extra_tags,
        var.tags,
        {
        } )

    upgrade_mode = "Manual" # Use blue-green approach to upgrades

    depends_on = [
        azurerm_lb_rule.lb_rule_http,
        azurerm_lb_rule.lb_rule_ui,
    ]
}

resource "azuread_group_member" "proxy_server_cluster_discovery" {
    group_object_id = data.azuread_group.proxy_server_discovery.id
    member_object_id  = azurerm_linux_virtual_machine_scale_set.vmss_proxy.identity.0.principal_id
}
