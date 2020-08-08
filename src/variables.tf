#
# CLUSTER
#

variable "admin_password" {
    description = "The password of the administrator user for the machines"
    type = string
}

variable "cluster_size" {
    default = "3"
    description = "The size of the cluster"
}

variable "resource_version" {
    default = "1.2.0"
    description = "The version of the proxy-edge image."
}

#
# ENVIRONMENT
#

variable "category" {
    default = "cv-core-ingress"
    description = "The name of the category that all the resources are running in."
}

variable "datacenter" {
    default = "calvinverse-test"
    description = "The name of the environment that all the resources are running in. Used as the name of the Consul data center"
}

variable "domain" {
    default = "consulverse"
    description = "The name of the DNS domain that all the resources are running in. Used to resolve the static resources, e.g. Consul servers"
}

variable "domain_consul" {
    default = "consulverse"
    description = "The name of the Consul DNS domain that all the resources are running in. Used as the domain of the Consul data center"
}

variable "encrypt_consul" {
    description = "The Consul encrypt key"
    type = string
}

variable "environment" {
    default = "test"
    description = "The name of the environment that all the resources are running in."
}

#
# LOCATION
#

variable "location" {
    default = "australiaeast"
    description = "The full name of the Azure region in which the resources should be created."
}

#
# META
#

variable "meta_source" {
    description = "The commit ID of the current commit from which the plan is being created."
    type = string
}

variable "meta_version" {
    description = "The version of the infrastructure as it is being generated."
    type = string
}

#
# SPOKE
#

variable "spoke_id" {
    default = "01"
    description = "The ID of the spoke into which the consul server cluster should be placed."
}

#
# SUBSCRIPTIONS
#

variable "subscription_production" {
    description = "The subscription ID of the production subscription. Used to find the log analytics resources."
    type = string
}

variable "subscription_test" {
    description = "The subscription ID of the test subscription."
    type = string
}

#
# TAGS
#

variable "tags" {
  description = "Tags to apply to all resources created."
  type = map(string)
  default = { }
}
