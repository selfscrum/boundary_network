locals {
  system = jsondecode(file("assets/system.json"))
}

resource "tfe_workspace" "boundary_network" {
  name  = format("%s_%s", 
                local.system["env_stage"],
                local.system["workspace"]
                )
  organization = local.system["tfc_organization"]
  queue_all_runs = false
}

resource "tfe_variable" "bn_access_token" {
    key          = "access_token"
    value        = ""
    category     = "environment"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "Workspace that created the Boundary Network"
    sensitive    = true
}

resource "tfe_variable" "bn_env_name" {
    key          = "env_name"
    value        = format("%s_%s", 
                    lookup(local.system, "env_name"),
                    random_pet.name.id
                    )
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "Name of the Component"
}

resource "tfe_variable" "bn_env_stage" {
    key          = "env_stage"
    value        = lookup(local.system, "env_stage")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "Stage of the Component"
}

resource "tfe_variable" "bn_location" {
    key          = "location"
    value        = lookup(local.system, "location")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "Location of the Component"
}

resource "tfe_variable" "bn_system_function" {
    key          = "system_function"
    value        = lookup(local.system, "system_function")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "System Function of the Component"
}

resource "tfe_variable" "bn_postgres_image" {
    key          = "postgres_image"
    value        = lookup(local.system, "postgres_image")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "postgres_image of the Component"
}

resource "tfe_variable" "bn_postgres_type" {
    key          = "postgres_type"
    value        = lookup(local.system, "postgres_type")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "postgres_type of the Component"
}

resource "tfe_variable" "bn_worker_image" {
    key          = "worker_image"
    value        = lookup(local.system, "worker_image")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "worker_image of the Component"
}

resource "tfe_variable" "bn_worker_type" {
    key          = "worker_type"
    value        = lookup(local.system, "worker_type")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "worker_type of the Component"
}

resource "tfe_variable" "bn_controller_image" {
    key          = "controller_image"
    value        = lookup(local.system, "controller_image")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "controller_image of the Component"
}

resource "tfe_variable" "bn_controller_type" {
    key          = "controller_type"
    value        = lookup(local.system, "controller_type")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "controller_type of the Component"
}

resource "tfe_variable" "bn_router_type" {
    key          = "router_type"
    value        = lookup(local.system, "router_type")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "router_type of the Component"
}

resource "tfe_variable" "bn_lb_type" {
    key          = "lb_type"
    value        = lookup(local.system, "lb_type")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "lb_type of the Component"
}

resource "tfe_variable" "bn_keyname" {
    key          = "keyname"
    value        = lookup(local.system, "keyname")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "keyname of the Component"
}

resource "tfe_variable" "bn_network_zone" {
    key          = "network_zone"
    value        = lookup(local.system, "network_zone")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "network_zone of the Component"
}

resource "tfe_variable" "bn_private_key" {
    key          = "private_key"
    value        = lookup(local.system, "private_key")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "private_key of the Component"
    sensitive    = true
}

resource "tfe_variable" "bn_router_password" {
    key          = "router_password"
    value        = lookup(local.system, "router_password")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "router_password of the Component"
    sensitive    = true
}

resource "tfe_variable" "bn_router_user" {
    key          = "router_user"
    value        = lookup(local.system, "router_user")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "router_user of the Component"
    sensitive    = true
}

resource "tfe_variable" "bn_router_commands" {
    key          = "router_commands"
    value        = lookup(local.system, "router_commands")
    category     = "terraform"
    workspace_id = tfe_workspace.boundary_network.id
    description  = "router_commands of the Component"
    hcl = true
}
