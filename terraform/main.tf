terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.89.0"
    }
  }

#  backend "s3" {
#    bucket   = "kuliaev-bucket"
#    key      = "terraform.tfstate"
#    region   = "ru-central1"
#    endpoint = "storage.yandexcloud.net"
##    access_key = var.access_key
##    secret_key = var.secret_key
#    access_key = ""
#    secret_key = ""
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
  name = "kuliaev-network"                   # <- поаправить на mkuliaev
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
    subnet_id = yandex_vpc_subnet.subnet_d.id  # Используем подсеть в зоне d
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.public_key_path)}"
  }
}

# Рабочие узлы
resource "yandex_compute_instance" "worker" {
  count       = 2
  name        = "mkuliaev-worker-${count.index}"
  platform_id = "standard-v2"
  zone        = count.index == 0 ? "ru-central1-a" : "ru-central1-b"  # Чередуем зоны a и b

  scheduling_policy {
    preemptible = true
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

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2004-lts"
}

# Добовляем Network Load Balancer
# Целевая группа для рабочих узлов
resource "yandex_lb_target_group" "workers" {
  name = "workers-target-group"

  dynamic "target" {
    for_each = yandex_compute_instance.worker
    content {
      subnet_id = target.value.network_interface[0].subnet_id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

# Сетевой балансировщик нагрузки
resource "yandex_lb_network_load_balancer" "my_balancer" {
  name = "mkuliaev-network-lb"

  listener {
    name = "http-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.workers.id

    healthcheck {
      name = "http-healthcheck"
      http_options {
        port = 80
        path = "/"
      }
      interval            = 2
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

output "load_balancer_public_ip" {
  value = [
    for listener in yandex_lb_network_load_balancer.my_balancer.listener :
    tolist(listener.external_address_spec)[0].address
  ]
}






