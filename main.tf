terraform {
  required_version = ">= 1.8.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
  subscription_id     = "4ac7e4ba-2b33-4c38-8852-1a6ba4098aa3"
}

variable "location" {
  default = "UK South"
}

variable "resource_group_name" {
  default = "craig-pay-sandbox-rg"
}

# Get current client config (for tenant ID, etc.)
data "azurerm_client_config" "current" {}

# Source IP
data "http" "icanhazip" {
  url = "https://ipv4.icanhazip.com/"
}

data "azurerm_resource_group" "resource_group" {
  name = var.resource_group_name
}

resource "azurerm_automation_account" "aa_startstoptest" {
  name                = "aa-startstoptest"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "vm_contributor_role" {
  scope                = data.azurerm_resource_group.resource_group.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_automation_account.aa_startstoptest.identity[0].principal_id
}


resource "azurerm_automation_runbook" "rb_stop_start_vms" {
  name                    = "rb-start-stop-vms"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_startstoptest.name
  log_verbose             = true
  log_progress            = true
  runbook_type            = "PowerShell"
  content                 = file("start-stop-vms.ps1")
}

resource "azurerm_automation_runbook" "rb_stop_start_kubernetes" {
  name                    = "rb-start-stop-kubernetes"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_startstoptest.name
  log_verbose             = true
  log_progress            = true
  runbook_type            = "PowerShell"
  content                 = file("start-stop-kubernetes.ps1")
}

resource "azurerm_automation_schedule" "schedule_on_the_hour" {
  name                    = "schedule-on-the-hour"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_startstoptest.name
  frequency               = "Hour"
  interval                = 1
  timezone                = "UTC"
  start_time              = timeadd(timestamp(), "${60 - tonumber(formatdate("mm", timestamp()))}m")
}

resource "azurerm_automation_schedule" "schedule_15_minutes_past" {
  name                    = "schedule-15-minutes-past"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_startstoptest.name
  frequency               = "Hour"
  interval                = 1
  timezone                = "UTC"
  start_time              = timeadd(timestamp(), "${75 - tonumber(formatdate("mm", timestamp()))}m")
}

resource "azurerm_automation_schedule" "schedule_30_minutes_past" {
  name                    = "schedule-30-minutes-past"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_startstoptest.name
  frequency               = "Hour"
  interval                = 1
  timezone                = "UTC"
  start_time              = timeadd(timestamp(), "${90 - tonumber(formatdate("mm", timestamp()))}m")
}

resource "azurerm_automation_schedule" "schedule_45_minutes_past" {
  name                    = "schedule-45-minutes-past"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa_startstoptest.name
  frequency               = "Hour"
  interval                = 1
  timezone                = "UTC"
  start_time              = timeadd(timestamp(), "${105 - tonumber(formatdate("mm", timestamp()))}m")
}

resource "azurerm_automation_job_schedule" "job_schedule_on_the_hour" {
  automation_account_name = azurerm_automation_account.aa_startstoptest.name
  resource_group_name     = var.resource_group_name
  runbook_name            = azurerm_automation_runbook.rb_stop_start_vms.name
  schedule_name           = azurerm_automation_schedule.schedule_on_the_hour.name
}

resource "azurerm_automation_job_schedule" "job_schedule_15_minutes_past" {
  automation_account_name = azurerm_automation_account.aa_startstoptest.name
  resource_group_name     = var.resource_group_name
  runbook_name            = azurerm_automation_runbook.rb_stop_start_vms.name
  schedule_name           = azurerm_automation_schedule.schedule_15_minutes_past.name
}

resource "azurerm_automation_job_schedule" "job_schedule_30_minutes_past" {
  automation_account_name = azurerm_automation_account.aa_startstoptest.name
  resource_group_name     = var.resource_group_name
  runbook_name            = azurerm_automation_runbook.rb_stop_start_vms.name
  schedule_name           = azurerm_automation_schedule.schedule_30_minutes_past.name
}

resource "azurerm_automation_job_schedule" "job_schedule_45_minutes_past" {
  automation_account_name = azurerm_automation_account.aa_startstoptest.name
  resource_group_name     = var.resource_group_name
  runbook_name            = azurerm_automation_runbook.rb_stop_start_vms.name
  schedule_name           = azurerm_automation_schedule.schedule_45_minutes_past.name
}

resource "azurerm_automation_job_schedule" "job_schedule_on_the_hour_kubernetes" {
  automation_account_name = azurerm_automation_account.aa_startstoptest.name
  resource_group_name     = var.resource_group_name
  runbook_name            = azurerm_automation_runbook.rb_stop_start_kubernetes.name
  schedule_name           = azurerm_automation_schedule.schedule_on_the_hour.name
}

resource "azurerm_automation_job_schedule" "job_schedule_15_minutes_past_kubernetes" {
  automation_account_name = azurerm_automation_account.aa_startstoptest.name
  resource_group_name     = var.resource_group_name
  runbook_name            = azurerm_automation_runbook.rb_stop_start_kubernetes.name
  schedule_name           = azurerm_automation_schedule.schedule_15_minutes_past.name
}

resource "azurerm_automation_job_schedule" "job_schedule_30_minutes_past_kubernetes" {
  automation_account_name = azurerm_automation_account.aa_startstoptest.name
  resource_group_name     = var.resource_group_name
  runbook_name            = azurerm_automation_runbook.rb_stop_start_kubernetes.name
  schedule_name           = azurerm_automation_schedule.schedule_30_minutes_past.name
}

resource "azurerm_automation_job_schedule" "job_schedule_45_minutes_past_kubernetes" {
  automation_account_name = azurerm_automation_account.aa_startstoptest.name
  resource_group_name     = var.resource_group_name
  runbook_name            = azurerm_automation_runbook.rb_stop_start_kubernetes.name
  schedule_name           = azurerm_automation_schedule.schedule_45_minutes_past.name
}

