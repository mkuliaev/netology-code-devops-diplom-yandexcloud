variable "yc_cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
  sensitive   = true
}

variable "yc_folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
  sensitive   = true
}

variable "yc_token" {
  description = "Yandex Cloud OAuth token"
  type        = string
  sensitive   = true
}

variable "access_key" {
  description = "Access key для S3-хранилища Яндекс Облака"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Secret key для S3-хранилища Яндекс Облака"
  type        = string
  sensitive   = true
}

variable "ssh_user" {
  description = "SSH user name"
  type        = string
  default     = "kuliaev"
}

variable "public_key_path" {
  description = "Path to public SSH key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}