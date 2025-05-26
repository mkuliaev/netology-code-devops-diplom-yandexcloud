# Дипломный практикум в Yandex.Cloud
#       "Mikhail Kuliaev"
        


  * [Цели:](#цели)
  * [Этапы выполнения:](#этапы-выполнения)
     * [Создание облачной инфраструктуры](#создание-облачной-инфраструктуры)
     * [Создание Kubernetes кластера](#создание-kubernetes-кластера)
     * [Создание тестового приложения](#создание-тестового-приложения)
     * [Подготовка cистемы мониторинга и деплой приложения](#подготовка-cистемы-мониторинга-и-деплой-приложения)
     * [Установка и настройка CI/CD](#установка-и-настройка-cicd)
  * [Что необходимо для сдачи задания?](#что-необходимо-для-сдачи-задания)
  * [Как правильно задавать вопросы дипломному руководителю?](#как-правильно-задавать-вопросы-дипломному-руководителю)

**Перед началом работы над дипломным заданием изучите [Инструкция по экономии облачных ресурсов](https://github.com/netology-code/devops-materials/blob/master/cloudwork.MD).**

---
## Цели:

1. Подготовить облачную инфраструктуру на базе облачного провайдера Яндекс.Облако.
2. Запустить и сконфигурировать Kubernetes кластер.
3. Установить и настроить систему мониторинга.
4. Настроить и автоматизировать сборку тестового приложения с использованием Docker-контейнеров.
5. Настроить CI для автоматической сборки и тестирования.
6. Настроить CD для автоматического развёртывания приложения.

---
## Этапы выполнения:


### Создание облачной инфраструктуры

Для начала необходимо подготовить облачную инфраструктуру в ЯО при помощи [Terraform](https://www.terraform.io/).

Особенности выполнения:

- Бюджет купона ограничен, что следует иметь в виду при проектировании инфраструктуры и использовании ресурсов;
Для облачного k8s используйте региональный мастер(неотказоустойчивый). Для self-hosted k8s минимизируйте ресурсы ВМ и долю ЦПУ. В обоих вариантах используйте прерываемые ВМ для worker nodes.

Предварительная подготовка к установке и запуску Kubernetes кластера.

1. Создайте сервисный аккаунт, который будет в дальнейшем использоваться Terraform для работы с инфраструктурой с необходимыми и достаточными правами. Не стоит использовать права суперпользователя
2. Подготовьте [backend](https://developer.hashicorp.com/terraform/language/backend) для Terraform:  
   а. Рекомендуемый вариант: S3 bucket в созданном ЯО аккаунте(создание бакета через TF)
   б. Альтернативный вариант:  [Terraform Cloud](https://app.terraform.io/)
3. Создайте конфигурацию Terrafrom, используя созданный бакет ранее как бекенд для хранения стейт файла. Конфигурации Terraform для создания сервисного аккаунта и бакета и основной инфраструктуры следует сохранить в разных папках.
4. Создайте VPC с подсетями в разных зонах доступности.
5. Убедитесь, что теперь вы можете выполнить команды `terraform destroy` и `terraform apply` без дополнительных ручных действий.
6. В случае использования [Terraform Cloud](https://app.terraform.io/) в качестве [backend](https://developer.hashicorp.com/terraform/language/backend) убедитесь, что применение изменений успешно проходит, используя web-интерфейс Terraform cloud.

Ожидаемые результаты:

1. Terraform сконфигурирован и создание инфраструктуры посредством Terraform возможно без дополнительных ручных действий, стейт основной конфигурации сохраняется в бакете или Terraform Cloud
2. Полученная конфигурация инфраструктуры является предварительной, поэтому в ходе дальнейшего выполнения задания возможны изменения.

---
### Создание Kubernetes кластера

На этом этапе необходимо создать [Kubernetes](https://kubernetes.io/ru/docs/concepts/overview/what-is-kubernetes/) кластер на базе предварительно созданной инфраструктуры.   Требуется обеспечить доступ к ресурсам из Интернета.

Это можно сделать двумя способами:

1. Рекомендуемый вариант: самостоятельная установка Kubernetes кластера.  
   а. При помощи Terraform подготовить как минимум 3 виртуальных машины Compute Cloud для создания Kubernetes-кластера. Тип виртуальной машины следует выбрать самостоятельно с учётом требовании к производительности и стоимости. Если в дальнейшем поймете, что необходимо сменить тип инстанса, используйте Terraform для внесения изменений.  
   б. Подготовить [ansible](https://www.ansible.com/) конфигурации, можно воспользоваться, например [Kubespray](https://kubernetes.io/docs/setup/production-environment/tools/kubespray/)  
   в. Задеплоить Kubernetes на подготовленные ранее инстансы, в случае нехватки каких-либо ресурсов вы всегда можете создать их при помощи Terraform.
2. Альтернативный вариант: воспользуйтесь сервисом [Yandex Managed Service for Kubernetes](https://cloud.yandex.ru/services/managed-kubernetes)  
  а. С помощью terraform resource для [kubernetes](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_cluster) создать **региональный** мастер kubernetes с размещением нод в разных 3 подсетях      
  б. С помощью terraform resource для [kubernetes node group](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_node_group)
  
Ожидаемый результат:

1. Работоспособный Kubernetes кластер.
2. В файле `~/.kube/config` находятся данные для доступа к кластеру.
3. Команда `kubectl get pods --all-namespaces` отрабатывает без ошибок.

---
### Создание тестового приложения

Для перехода к следующему этапу необходимо подготовить тестовое приложение, эмулирующее основное приложение разрабатываемое вашей компанией.

Способ подготовки:

1. Рекомендуемый вариант:  
   а. Создайте отдельный git репозиторий с простым nginx конфигом, который будет отдавать статические данные.  
   б. Подготовьте Dockerfile для создания образа приложения.  
2. Альтернативный вариант:  
   а. Используйте любой другой код, главное, чтобы был самостоятельно создан Dockerfile.

Ожидаемый результат:

1. Git репозиторий с тестовым приложением и Dockerfile.
2. Регистри с собранным docker image. В качестве регистри может быть DockerHub или [Yandex Container Registry](https://cloud.yandex.ru/services/container-registry), созданный также с помощью terraform.

---
### Подготовка cистемы мониторинга и деплой приложения

Уже должны быть готовы конфигурации для автоматического создания облачной инфраструктуры и поднятия Kubernetes кластера.  
Теперь необходимо подготовить конфигурационные файлы для настройки нашего Kubernetes кластера.

Цель:
1. Задеплоить в кластер [prometheus](https://prometheus.io/), [grafana](https://grafana.com/), [alertmanager](https://github.com/prometheus/alertmanager), [экспортер](https://github.com/prometheus/node_exporter) основных метрик Kubernetes.
2. Задеплоить тестовое приложение, например, [nginx](https://www.nginx.com/) сервер отдающий статическую страницу.

Способ выполнения:
1. Воспользоваться пакетом [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus), который уже включает в себя [Kubernetes оператор](https://operatorhub.io/) для [grafana](https://grafana.com/), [prometheus](https://prometheus.io/), [alertmanager](https://github.com/prometheus/alertmanager) и [node_exporter](https://github.com/prometheus/node_exporter). Альтернативный вариант - использовать набор helm чартов от [bitnami](https://github.com/bitnami/charts/tree/main/bitnami).

2. Если на первом этапе вы не воспользовались [Terraform Cloud](https://app.terraform.io/), то задеплойте и настройте в кластере [atlantis](https://www.runatlantis.io/) для отслеживания изменений инфраструктуры. Альтернативный вариант 3 задания: вместо Terraform Cloud или atlantis настройте на автоматический запуск и применение конфигурации terraform из вашего git-репозитория в выбранной вами CI-CD системе при любом комите в main ветку. Предоставьте скриншоты работы пайплайна из CI/CD системы.

Ожидаемый результат:
1. Git репозиторий с конфигурационными файлами для настройки Kubernetes.
2. Http доступ на 80 порту к web интерфейсу grafana.
3. Дашборды в grafana отображающие состояние Kubernetes кластера.
4. Http доступ на 80 порту к тестовому приложению.
5. Atlantis или terraform cloud или ci/cd-terraform
---
### Установка и настройка CI/CD

Осталось настроить ci/cd систему для автоматической сборки docker image и деплоя приложения при изменении кода.

Цель:

1. Автоматическая сборка docker образа при коммите в репозиторий с тестовым приложением.
2. Автоматический деплой нового docker образа.

Можно использовать [teamcity](https://www.jetbrains.com/ru-ru/teamcity/), [jenkins](https://www.jenkins.io/), [GitLab CI](https://about.gitlab.com/stages-devops-lifecycle/continuous-integration/) или GitHub Actions.

Ожидаемый результат:

1. Интерфейс ci/cd сервиса доступен по http.
2. При любом коммите в репозиторие с тестовым приложением происходит сборка и отправка в регистр Docker образа.
3. При создании тега (например, v1.0.0) происходит сборка и отправка с соответствующим label в регистри, а также деплой соответствующего Docker образа в кластер Kubernetes.

---
## Что необходимо для сдачи задания?

1. Репозиторий с конфигурационными файлами Terraform и готовность продемонстрировать создание всех ресурсов с нуля.
2. Пример pull request с комментариями созданными atlantis'ом или снимки экрана из Terraform Cloud или вашего CI-CD-terraform pipeline.
3. Репозиторий с конфигурацией ansible, если был выбран способ создания Kubernetes кластера при помощи ansible.
4. Репозиторий с Dockerfile тестового приложения и ссылка на собранный docker image.
5. Репозиторий с конфигурацией Kubernetes кластера.
6. Ссылка на тестовое приложение и веб интерфейс Grafana с данными доступа.
7. Все репозитории рекомендуется хранить на одном ресурсе (github, gitlab)

_______________________________________________________________________________________________________________________

Булат Замилов, Кирилл Касаткин здравствуйте!
Задание сдела, но ксожалению не хватает времени оформить задание. Прошу еще пару дней.



-------------------

Подготавливаем  облачную инфраструктуру в ЯО при помощи [Terraform](https://www.terraform.io/).
```yaml
# Создаем сервисный аккаунта kuliaev-diplom
resource "yandex_iam_service_account" "kuliaev_diplom" {
  name        = "kuliaev-diplom"
  description = "Service account for diploma project"
}

# Назначение роли storage.editor (переделал на "storage.admin")
resource "yandex_resourcemanager_folder_iam_binding" "storage_admin" {
  folder_id = var.yc_folder_id
  role      = "storage.admin"
  members = [
    "serviceAccount:${yandex_iam_service_account.kuliaev_diplom.id}"
  ]
}
```
![11-04-01](https://g)

потом создаем S3 бакета и грузим туда файл! 
пусть будет картинка с зайцем БО!
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/terraform/bucket/image.jpg)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/backet.png)


Теперь 
```yaml
# Создание VPC сети
resource "yandex_vpc_network" "network" {
  name = "mkuliaev-network"                   
}
```

в каждой зоне своя подсеть
```yaml
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
```

Дистрибутив беру ubuntu-2204 (с 2004 - слишком много проблем с репами ! разворачивал на ней)
```yaml
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}
```

Теперь пришло время разобратся с нодами.

Изначально было 3 ноды (1 мастер и 2 воркета)! Пока пробрасывал на хостовую машины с помощью NodePort приложение и графану - было вроде нормально, 
но когда стал перекидывать на балансировщик возникли проблемы из-за того, что группа была либо на одном балансировщике, либо на другом!
Сейчас подготовил  1 мастера и 4 воркера, и разделил их сразу по группам!
```yaml
# Мастер-узел
resource "yandex_compute_instance" "master" {
  name        = "mkuliaev-master"
  zone        = "ru-central1-d"  # Мастер в зоне d 
  platform_id = "standard-v2"    # <- сволоч
}
```

и 

```yaml
# Воркеры
resource "yandex_compute_instance" "worker" {
  count       = 4
  name        = "mkuliaev-worker-${count.index + 1}"
  platform_id = "standard-v2"
  zone        = count.index == 0 ? "ru-central1-a" : "ru-central1-b" 
}
```

Теперь создаём IP адреса для наших балансировщиков

```yaml
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
```

Пришло время для Целевых групп
```yaml
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
```
и

```sql
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
```

Теперь самое главное ))) Настройка балансировщиков!

Тут пробрасываем 30080 NodePort графаны на 80 порт балансировщика "mkuliaev-grafana-nlb" и  не забываем про  "/api/health" для самодиагностики.
 
```sql
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
```

Всё тоже самое, только у NodePort порт 30081 и нет наворотов с самодиагностикой, балансировщик "mkuliaev-web-app-nlb"

```yaml
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
```

Теперь применяем   

terraform apply
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/terraform_install.gif)

![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/terr_apply.png)

Проверяем, что насоздавали ))))

![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/dashbor.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/vm.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/netw.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/groups_c.png)

Вроде всё норм

Берем из вывода master_public_ip = "158.160.164.140" и подключаемся к будущей мастерноде.

Заходим на неё и начинаем обновлятся да устанавливатся ))

```yaml
ssh -A ubuntu@158.160.164.140
sudo apt-get update && sudo apt-get install -y python3-pip git
pip3 install --user ansible==8.5.0
sudo  apt install python3.10-venv
python3 -m venv .venv
source .venv/bin/activate
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
git checkout v2.25.0
pip3 install -r requirements.txt
cp -rfp inventory/sample inventory/mycluster
declare -a IPS=(158.160.164.140 51.250.70.253 89.169.163.63 89.169.170.198 130.193.52.15)
pip3 install ruamel.yaml
CONFIG_FILE=inventory/mycluster/hosts.yaml python3 contrib/inventory_builder/inventory.py ${IPS[@]}
nano inventory/mycluster/inventory.ini
```
nano inventory/mycluster/inventory.ini  
"Оформлено по молодежному" )))

 ```bash                                                                           
[all]
kuliaev-master   ansible_host=158.160.164.140   ip=10.0.2.16  # Мастер
kuliaev-worker-1 ansible_host=51.250.70.253     ip=10.0.0.23  # Воркер 1
kuliaev-worker-2 ansible_host=89.169.163.63     ip=10.0.1.10  # Воркер 2
kuliaev-worker-3 ansible_host=89.169.170.198    ip=10.0.1.5   # Воркер 3
kuliaev-worker-4 ansible_host=130.193.52.15     ip=10.0.1.3   # Воркер 4

[kube_control_plane]
kuliaev-master

[etcd]
kuliaev-master

[kube_node]
kuliaev-worker-1
kuliaev-worker-2
kuliaev-worker-3
kuliaev-worker-4

[calico_rr]

[k8s_cluster:children]
kube_control_plane
kube_node
calico_rr
```

![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/inventory.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/myclaster-install.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/cluster_work.png)
Гифочка
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/kube_install.gif)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/getnod.png)
Вроде готово!

Ставим Helm

 ```bash  
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

 ```bash  
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```
Создаем файл с настройками - values.yaml



 ```bash 
grafana:
  nodeSelector:
    app: grafana
  service:
    type: NodePort
    port: 3000
    targetPort: 3000
    nodePort: 30080 

prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
```
Устанавливаем с настройками выше 
 ```bash 
helm install prometheus prometheus-community/kube-prometheus-stack -f values.yaml
```

Помечаем воркеры 

 ```bash  
kubectl label nodes kuliaev-worker-1 app=grafana
kubectl label nodes kuliaev-worker-2 app=grafana
```
Обновляем

 ```bash  
helm upgrade prometheus prometheus-community/kube-prometheus-stack -f values.yaml
```
Проверяем

 ```bash  
ubuntu@kuliaev-master:~/kubespray$ kubectl get pods -l app.kubernetes.io/name=grafana -o wide
NAME                                  READY   STATUS    RESTARTS   AGE   IP             NODE               NOMINATED NODE   READINESS GATES
prometheus-grafana-659c5875cf-cfzth   3/3     Running   0          12h   10.233.102.4   kuliaev-worker-2   <none>           <none>
```
Проверяем доступность на  mkuliaev-grafana-nlb - 158.160.63.208  по 80 порту

![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/grafana_1.png)

Доступна!

Теперь приложение


[Вэб страничка с Гифкой (my_app)](https://github.com/mkuliaev/my_app/)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/app_rtee.png)

Запускаем и проверяем локально
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/html_360p.gif)
Отлично -Работает! (подтормаживания при видеозахвате-так работает всё плавно)

Готовим докерфайл
 ```bash  
FROM nginx:1.23.1

COPY static /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
```

Тепрь собираем образы и отпвляем на докерхаб с тегами
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/bild_docker_1-00-46.png)

проверяем докерхаб

![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/docker_hub_dowl.png)

Пока всё хорошо!

Теперь идем на наш кластер и запустим там наше приложение! После, проверяем доступность графаны и нашей странички по 80 порту!

Создаём namespace kuliaev-diplom (чтоб было всё по красоте!)
 ```bash
kubectl create namespace kuliaev-diplom
 ```
Создаём деплоймент и сервис к ниму

 ```bash
ubuntu@kuliaev-master:~$ cat app-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kuliaev-diplom.ru
  namespace: kuliaev-diplom
  labels:
    app: web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
        - name: kuliaev-diplom-nginx
          image:  mkuliaev/my-nginx-app:latest
          resources:
             requests:
                cpu: "1"
                memory: "200Mi"
             limits:
                cpu: "2"
                memory: "800Mi"
          ports:
            - containerPort: 80
ubuntu@kuliaev-master:~$ cat app-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: kuliaev-diplom-service
  namespace: kuliaev-diplom
spec:
  type: NodePort
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30081
ubuntu@kuliaev-master:~$ 

```
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/dowl_360p.gif)


Теперь запускаем

 ```bash
kubectl apply -f app-deployment.yaml 
kubectl apply -f app-service.yaml
```








![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/dowl_360p.gif)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/old_9%2003-07-38_360p.gif)



![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/web_brow_app.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/grafana_brouw.png)


![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/nl_balans.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/nl_balans.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/dockerhub_v4.9.png)

![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/add_teg.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/depl.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/my_app.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/rep_app_ci-cd.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/rep_secret.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/workfl.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/deploy_my_app.png)
![11-04-01](https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/png_diplom/deploy_360p.gif)


https://github.com/mkuliaev/my_app/blob/main/.github/workflows/docker-image.yml

https://github.com/mkuliaev/netology-code-devops-diplom-yandexcloud/blob/main/.github/workflows/terraform.yml