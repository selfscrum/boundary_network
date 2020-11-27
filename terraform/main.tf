variable "access_token" {}
variable "env_name"  { }
variable "env_stage" { }
variable "location" { }
variable "system_function" {}
variable "postgres_image" {}
variable "postgres_type" {}
variable "worker_image" {}
variable "worker_type" {}
variable "controller_image" {}
variable "controller_type" {}
variable "keyname" {} 
variable "lb_type" {}
variable "network_zone" {}
variable "router_type" {}
variable "private_key" {}
variable "router_password" {}
variable "router_user" {}
variable "router_commands" {}

provider "hcloud" {
  token = var.access_token
}

data "hcloud_ssh_key" "serverkey" {
    name = "tfh_key"
}

data "hcloud_certificate" "selftest" {
    name = "selftest"
}

resource "hcloud_network" "mynet" {
  name = "zcluster"
  ip_range = "10.0.0.0/16"
}

output "network_id" {
  description = "Hetzner ID of the private network"
  value = hcloud_network.mynet.id
}

resource "hcloud_network_subnet" "public" {
  network_id = hcloud_network.mynet.id
  type = "cloud"
  network_zone = "eu-central"
  ip_range   = "10.0.1.0/24"
}

resource "hcloud_network_subnet" "private" {
  network_id = hcloud_network.mynet.id
  type = "cloud"
  network_zone = "eu-central"
  ip_range   = "10.0.2.0/24"
}

output "private_subnet_id" {
  description = "Hetzner ID of the private subnet"
  value = hcloud_network_subnet.private.id
}

module "routeros-router" {
  source  = "selfscrum/routeros-router/hcloud"
  version = "0.1.0"
  system_name = var.env_name
  system_stage = var.env_stage
  router_type = var.router_type
  location = var.location
  server_key = var.keyname
  private_key = var.private_key
  router_user = var.router_user
  router_password = var.router_password
}

resource "hcloud_server_network" "external_router" {
  network_id = hcloud_network.mynet.id
  server_id  = module.routeros-router.router_id
  ip = cidrhost(hcloud_network_subnet.public.ip_range, 1)
}

output "router_ip" {
    value = module.routeros-router.router_ip
}

module "routeros-router-configuration" {
  source  = "selfscrum/routeros-router-configuration/hcloud"
  version = "0.1.0"

  depends_on = [ hcloud_server_network.external_router ]    

  system_name = var.env_name
  system_stage = var.env_stage
  router_ip = module.routeros-router.router_ip
  router_user = var.router_user
  router_password = var.router_password
  router_commands = var.router_commands
}

resource "hcloud_network_route" "to_router" {
  network_id = hcloud_network.mynet.id
  destination = "0.0.0.0/0"
  gateway = hcloud_server_network.external_router.ip
}

/*
####
# Load Balancer
#
#

resource "hcloud_load_balancer" "external_interface" {
  name = "external-interface"
  load_balancer_type = var.lb_type
  network_zone = var.network_zone
}

output "load_balancer_ip" {
    value = hcloud_load_balancer.external_interface.ipv4
}

resource "hcloud_load_balancer_network" "frontnet" {
  load_balancer_id = hcloud_load_balancer.external_interface.id
  network_id = hcloud_network.mynet.id
  ip = cidrhost(hcloud_network_subnet.public.ip_range, 2) 
}

resource "hcloud_load_balancer_service" "load_balancer_service" {
    load_balancer_id = hcloud_load_balancer.external_interface.id
    protocol = "https"
    listen_port = 9200
    destination_port = 9200
    http { certificates = [ data.hcloud_certificate.selftest.id ] }
}

resource "hcloud_load_balancer_target" "load_balancer_target" {
  type             = "label_selector"
  load_balancer_id = hcloud_load_balancer.external_interface.id
  label_selector   = "CONTROLLER"
  use_private_ip   = true
  depends_on = [ hcloud_load_balancer_network.frontnet, hcloud_server_network.external_controller ]  
}
*/

/*
####
# Backend Postgres
#
#

resource "hcloud_server" "postgres" {
  name        = format("%s-%s-POSTGRES", var.env_stage, var.env_name)
  image       = var.postgres_image
  server_type = var.postgres_type
  location    = var.location
  labels      = {
      "Name"     = var.env_name
      "Stage"    = var.env_stage
      "POSTGRES" = 0
  }
  ssh_keys    = [ var.keyname ]
  user_data   = <<-POSTGRES_EOF
                #cloud-config
                users:
                  - name: desixma
                    groups: users, admin
                    sudo: ALL=(ALL) NOPASSWD:ALL
                    shell: /bin/bash
                    ssh_authorized_keys:
                      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDH6orvm7dzkp47YBEvxOk3cvvYR5io32OmbbnR96bGjlT7LZleL4oV/aozCAG4Axy6mgByULUsxG9l/JhmFa3zg0/rP9HrklX7oPNdAdN26QAquD6dgaZ3PFP7UXkkNaTTAmJcw02EaCNuCcGLGinKOi0LETN/K+BTfpL7Q5kUbWFnkDjJpiIjqZwNzBqU3G7OfbqpW+EbcCAouBkT+rE09lAUth5BXWgq7MhtF8LrfnIrrf0demkXqqYm2clXd5266M2LgCsu/LayMkO0ig4SH7DotgXxNeXLJQtu7E02rrxFTZuNvazQQ7TwBbZdDELmYB8BdRmTQjYZqMSw6zaf
                packages:
                  - fail2ban
                  - ufw
                package_update: true
                package_upgrade: true
                runcmd:
                  - printf "[sshd]\nenabled = true\nbanaction = iptables-multiport" > /etc/fail2ban/jail.local
                  - systemctl enable fail2ban
                  - ufw allow OpenSSH
                  - ufw enable
                  - sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
                  - sed -i -e '/^PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
                  - sed -i -e '/^X11Forwarding/s/^.*$/X11Forwarding no/' /etc/ssh/sshd_config
                  - sed -i -e '/^#MaxAuthTries/s/^.*$/MaxAuthTries 2/' /etc/ssh/sshd_config
                  - sed -i -e '/^#AllowTcpForwarding/s/^.*$/AllowTcpForwarding no/' /etc/ssh/sshd_config
                  - sed -i -e '/^#AllowAgentForwarding/s/^.*$/AllowAgentForwarding no/' /etc/ssh/sshd_config
                  - sed -i -e '/^#AuthorizedKeysFile/s/^.*$/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config
                  - sed -i '$a AllowUsers desixma' /etc/ssh/sshd_config
                  - sleep 5
                  - apt update -y
                  - apt install -y postgresql postgresql-contrib
                  - reboot
                POSTGRES_EOF  
}

resource "hcloud_server_network" "internal_postgres" {
  network_id = hcloud_network.mynet.id
  server_id  = hcloud_server.postgres.id
  ip = cidrhost(hcloud_network_subnet.private.ip_range, 1) # First host in the private_range
}

output "postgres_ip" {
    value = hcloud_server.postgres.ipv4_address
}
*/


module "wireguard" {
  source = "git::https://github.com/selfscrum/tf_wireguard.git"
  amount         = 2
  connections   = [ hcloud_server.worker.ipv4_address, hcloud_server.controller.ipv4_address ]
  private_ips   = [ "10.10.10.10/32", "10.10.10.11/32"]
  overlay_cidr  = "10.10.10.0/24"
}

###
# Boundary Worker
#
#

resource "hcloud_server" "worker" {
  name        = format("%s-%s-WORKER", var.env_stage, var.env_name)
  image       = var.worker_image
  server_type = var.worker_type
  location    = var.location
  labels      = {
      "Name"     = var.env_name
      "Stage"    = var.env_stage
      "WORKER" = 0
  }
  ssh_keys    = [ var.keyname ]
  user_data   = <<-WORKER_EOF
                #cloud-config
                users:
                  - name: desixma
                    groups: users, admin
                    sudo: ALL=(ALL) NOPASSWD:ALL
                    shell: /bin/bash
                    ssh_authorized_keys:
                      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDH6orvm7dzkp47YBEvxOk3cvvYR5io32OmbbnR96bGjlT7LZleL4oV/aozCAG4Axy6mgByULUsxG9l/JhmFa3zg0/rP9HrklX7oPNdAdN26QAquD6dgaZ3PFP7UXkkNaTTAmJcw02EaCNuCcGLGinKOi0LETN/K+BTfpL7Q5kUbWFnkDjJpiIjqZwNzBqU3G7OfbqpW+EbcCAouBkT+rE09lAUth5BXWgq7MhtF8LrfnIrrf0demkXqqYm2clXd5266M2LgCsu/LayMkO0ig4SH7DotgXxNeXLJQtu7E02rrxFTZuNvazQQ7TwBbZdDELmYB8BdRmTQjYZqMSw6zaf
                packages:
                  - fail2ban
                  - ufw
                package_update: true
                package_upgrade: true
                runcmd:
                  - printf "[sshd]\nenabled = true\nbanaction = iptables-multiport" > /etc/fail2ban/jail.local
                  - systemctl enable fail2ban
                  - ufw allow OpenSSH
                  - ufw enable
                  - sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
                  - sed -i -e '/^PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
                  - sed -i -e '/^X11Forwarding/s/^.*$/X11Forwarding no/' /etc/ssh/sshd_config
                  - sed -i -e '/^#MaxAuthTries/s/^.*$/MaxAuthTries 2/' /etc/ssh/sshd_config
                  - sed -i -e '/^#AllowTcpForwarding/s/^.*$/AllowTcpForwarding no/' /etc/ssh/sshd_config
                  - sed -i -e '/^#AllowAgentForwarding/s/^.*$/AllowAgentForwarding no/' /etc/ssh/sshd_config
                  - sed -i -e '/^#AuthorizedKeysFile/s/^.*$/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config
                  - sed -i '$a AllowUsers desixma' /etc/ssh/sshd_config
                  - sleep 5
                  - reboot
                WORKER_EOF  
}

/*
resource "hcloud_server_network" "external_worker" {
  network_id = hcloud_network.mynet.id
  server_id  = hcloud_server.worker.id
  ip = cidrhost(hcloud_network_subnet.public.ip_range, 3)
}


output "worker_ip" {
    value = hcloud_server.worker.ipv4_address
}
*/


###
# Boundary Controller
#
#


resource "hcloud_server" "controller" {
  name        = format("%s-%s-CONTROLLER", var.env_stage, var.env_name)
  image       = var.controller_image
  server_type = var.controller_type
  location    = var.location
  labels      = {
      "Name"     = var.env_name
      "Stage"    = var.env_stage
      "CONTROLLER" = 0
  }
  ssh_keys    = [ var.keyname ]
  user_data   = <<-CONTROLLER_EOF
                #cloud-config
                users:
                  - name: desixma
                    groups: users, admin
                    sudo: ALL=(ALL) NOPASSWD:ALL
                    shell: /bin/bash
                    ssh_authorized_keys:
                      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDH6orvm7dzkp47YBEvxOk3cvvYR5io32OmbbnR96bGjlT7LZleL4oV/aozCAG4Axy6mgByULUsxG9l/JhmFa3zg0/rP9HrklX7oPNdAdN26QAquD6dgaZ3PFP7UXkkNaTTAmJcw02EaCNuCcGLGinKOi0LETN/K+BTfpL7Q5kUbWFnkDjJpiIjqZwNzBqU3G7OfbqpW+EbcCAouBkT+rE09lAUth5BXWgq7MhtF8LrfnIrrf0demkXqqYm2clXd5266M2LgCsu/LayMkO0ig4SH7DotgXxNeXLJQtu7E02rrxFTZuNvazQQ7TwBbZdDELmYB8BdRmTQjYZqMSw6zaf
                packages:
                  - fail2ban
                  - ufw
                package_update: true
                package_upgrade: true
                runcmd:
                  - printf "[sshd]\nenabled = true\nbanaction = iptables-multiport" > /etc/fail2ban/jail.local
                  - systemctl enable fail2ban
                  - ufw allow OpenSSH
                  - ufw allow 9200/tcp
                  - ufw enable
                  - sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
                  - sed -i -e '/^PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
                  - sed -i -e '/^X11Forwarding/s/^.*$/X11Forwarding no/' /etc/ssh/sshd_config
                  - sed -i -e '/^#MaxAuthTries/s/^.*$/MaxAuthTries 2/' /etc/ssh/sshd_config
                  - sed -i -e '/^#AllowTcpForwarding/s/^.*$/AllowTcpForwarding no/' /etc/ssh/sshd_config
                  - sed -i -e '/^#AllowAgentForwarding/s/^.*$/AllowAgentForwarding no/' /etc/ssh/sshd_config
                  - sed -i -e '/^#AuthorizedKeysFile/s/^.*$/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config
                  - sed -i '$a AllowUsers desixma' /etc/ssh/sshd_config
                  - sleep 5
                  - reboot
                CONTROLLER_EOF  
}
/*
resource "hcloud_server_network" "external_controller" {
  network_id = hcloud_network.mynet.id
  server_id  = hcloud_server.controller.id
  ip = cidrhost(hcloud_network_subnet.public.ip_range, 4) 
}

output "controller_ip" {
    value = hcloud_server.controller.ipv4_address
}
*/