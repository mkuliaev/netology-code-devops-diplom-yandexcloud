terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.89.0"
    }
  }

#  backend "s3" {
#  endpoint = "https://storage.yandexcloud.net"
#  bucket     = "kuliaev-diplom"
#  key        = "terraform.tfstate"
#  region     = "ru-central1"
  
#  access_key = ""  # backend.hcl
#  secret_key = ""
  
#  skip_region_validation      = true
#  skip_credentials_validation = true
  
#    }
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
  family = "ubuntu-2204-lts"
}

#data "yandex_compute_image" "ubuntu" {
#  family = "ubuntu-2004-lts"  # <- похоже для РФ отключили репы или вообще отключили их
#}

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
  count       = 4
  name        = "mkuliaev-worker-${count.index + 1}"
  platform_id = "standard-v2"
  zone        = count.index == 0 ? "ru-central1-a" : "ru-central1-b" 
 
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

#Network Load 
# Создаем статические IP-адреса
resource "yandex_vpc_address" "grafana_ip" {
  name = "grafana-lb-ip"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

resource "yandex_vpc_address" "web_app_ip" {
  name = "web-app-lb-ip"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

# ЦГ для Grafana (воркеры 1 и 2)
resource "yandex_lb_target_group" "grafana_workers" {
  name = "mkuliaev-grafana-workers-tg"

  dynamic "target" {
    for_each = slice(yandex_compute_instance.worker, 0, 2) # Берем первые 2 воркера
    content {
      subnet_id = target.value.network_interface[0].subnet_id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

# ЦГ для Web App (воркеры 3 и 4)
resource "yandex_lb_target_group" "web_workers" {
  name = "mkuliaev-web-workers-tg"

  dynamic "target" {
    for_each = slice(yandex_compute_instance.worker, 2, 4) # Берем последние 2 воркера
    content {
      subnet_id = target.value.network_interface[0].subnet_id
      address   = target.value.network_interface[0].ip_address
    }
  }
}
#  балансировщики разные целевые группы
resource "yandex_lb_network_load_balancer" "grafana_lb" {
  name = "mkuliaev-grafana-nlb"

  listener {
    name        = "grafana-listener"
    port        = 80        # внешний — 80
    target_port = 30080     # NodePort Grafana

    external_address_spec {
      address    = yandex_vpc_address.grafana_ip.external_ipv4_address[0].address
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.grafana_workers.id

    healthcheck {
      name = "grafana-hc"
      http_options {
        port = 30080
        path = "/api/health"
      }
    }
  }
}

resource "yandex_lb_network_load_balancer" "web_app_lb" {
  name = "mkuliaev-web-app-nlb"

  listener {
    name        = "web-app-listener"
    port        = 80        
    target_port = 30081    

    external_address_spec {
      address    = yandex_vpc_address.web_app_ip.external_ipv4_address[0].address
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.web_workers.id

    healthcheck {
      name = "web-app-hc"
      http_options {
        port = 30081
        path = "/"
      }
    }
  }
}

# Вывод IP-адресов балансировщиков
output "grafana_lb_ip" {
  value = yandex_vpc_address.grafana_ip.external_ipv4_address[0].address
}

output "web_app_lb_ip" {
  value = yandex_vpc_address.web_app_ip.external_ipv4_address[0].address
}
output "master_public_ip" {
  value = yandex_compute_instance.master.network_interface.0.nat_ip_address
}

output "worker_public_ips" {
  value = yandex_compute_instance.worker[*].network_interface.0.nat_ip_address
}


#output "http_load_balancer_ip" {
#  value = yandex_lb_network_load_balancer.http_lb.listener[0].external_address_spec[0].address
#}

#output "http_load_balancer_ip" {
#  value = one(yandex_lb_network_load_balancer.http_lb.listener[*].external_address_spec[*].address)
#}


