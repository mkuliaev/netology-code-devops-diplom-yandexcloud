variable "yc_token" {
  description = "Yandex Cloud OAuth token"
  type        = string
  sensitive   = true
}

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

variable "s3_access_key" {
  description = "Existing S3 access key"
  type        = string
  sensitive   = true
}

variable "s3_secret_key" {
  description = "Existing S3 secret key"
  type        = string
  sensitive   = true
}