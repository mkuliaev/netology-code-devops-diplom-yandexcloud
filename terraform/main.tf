terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.89.0"
    }
  }

# backend "s3" {
#   bucket   = "kuliaev-bucket"
#   key      = "terraform.tfstate"
#   region   = "ru-central1"
#   endpoint = "storage.yandexcloud.net"
#   access_key = var.s3_access_key
#   secret_key = var.s3_secret_key
  
#    access_key = "backend.hcl"
#    secret_key = "backend.hcl"
#
#    skip_region_validation      = true
#    skip_credentials_validation = true
#  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = "ru-central1-a"
}

# Сеть
#resource "yandex_vpc_network" "default" {
#  name = "mkuliaev-net"
#}
# Создание VPC сети
resource "yandex_vpc_network" "network" {
  name = "mkuliaev-network"                   # <- поаправить на mkuliaev
}

# Подсеть в зоне ru-central1-a
resource "yandex_vpc_subnet" "subnet_a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.0.0.0/24"]
}

# Подсеть в зоне ru-central1-b
resource "yandex_vpc_subnet" "subnet_b" {
  name           = "subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

# Подсеть в зоне ru-central1-d
resource "yandex_vpc_subnet" "subnet_d" {
  name           = "subnet-d"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.0.2.0/24"]
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2004-lts"
}

# Мастер-узел
resource "yandex_compute_instance" "master" {
  name        = "mkuliaev-master"
  zone        = "ru-central1-d"  # Мастер в зоне d 
  platform_id = "standard-v2"    # <- сволоч

  resources {
    cores  = 2
    memory = 6
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 50
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet_d.id  #  подсеть в зоне d
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.public_key_path)}"
  }
}

# Воркеры
resource "yandex_compute_instance" "worker" {
  count       = 2
  name        = "mkuliaev-worker-${count.index + 1}"
  platform_id = "standard-v2"
  zone        = count.index == 0 ? "ru-central1-a" : "ru-central1-b"  # Чередуем зоны a и b

  scheduling_policy {
    preemptible = false
  }

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 50
    }
  }

  network_interface {
    subnet_id = count.index == 0 ? yandex_vpc_subnet.subnet_a.id : yandex_vpc_subnet.subnet_b.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.public_key_path)}"
  }
}

#data "yandex_compute_image" "ubuntu" {
#  family = "ubuntu-2204-lts"
#}

# Добовляем Network Load Balancer

# ХА мастер
resource "yandex_lb_target_group" "kubectl_masters" {
  name = "masters-tg"

  target {
    subnet_id = yandex_vpc_subnet.subnet_d.id
    address   = yandex_compute_instance.master.network_interface[0].ip_address
  }
}

resource "yandex_lb_network_load_balancer" "kubectl_lb" {
  name = "mkuliaev-kubectl-lb"

  # Listener на порту 6443
  listener {
    name = "kubectl-listener"
    port = 6443
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.kubectl_masters.id
    healthcheck {
      name = "kubectl-hc"
      tcp_options {
        port = 6443
      }
      interval            = 3
      timeout             = 1
      healthy_threshold   = 2
      unhealthy_threshold = 2
    }
  }
}
 



# хттп воркер
resource "yandex_lb_target_group" "http_workers" {
  name = "workers-tg"

  dynamic "target" {
    for_each = yandex_compute_instance.worker
    content {
      subnet_id = target.value.network_interface[0].subnet_id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

resource "yandex_lb_network_load_balancer" "http_lb" {
  name = "mkuliaev-http-lb"

  listener {
    name = "http-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.http_workers.id
    healthcheck {
      name = "http-hc"
      http_options {
        port = 80
        path = "/"
      }
      interval            = 3
      timeout             = 1
      healthy_threshold   = 2
      unhealthy_threshold = 2
    }
  }
}

output "master_public_ip" {
  value = yandex_compute_instance.master.network_interface.0.nat_ip_address
}

output "worker_public_ips" {
  value = yandex_compute_instance.worker[*].network_interface.0.nat_ip_address
}

#output "kubectl_load_balancer_ip" {
#  value = yandex_lb_network_load_balancer.kubectl_lb.listener[0].external_address_spec[0].address
#}

#output "http_load_balancer_ip" {
#  value = yandex_lb_network_load_balancer.http_lb.listener[0].external_address_spec[0].address
#}
output "kubectl_load_balancer_ip" {
  value = one(yandex_lb_network_load_balancer.kubectl_lb.listener[*].external_address_spec[*].address)
}

output "http_load_balancer_ip" {
  value = one(yandex_lb_network_load_balancer.http_lb.listener[*].external_address_spec[*].address)
}
