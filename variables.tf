variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  type    = string
  default = "ha-access-log"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "http_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "enable_ssh" {
  type    = bool
  default = false
}

variable "ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "key_name" {
  type    = string
  default = null
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "accesslogdb"
}

variable "db_master_username" {
  type    = string
  default = "appadmin"
}

variable "db_master_password" {
  type      = string
  sensitive = true

  validation {
    condition     = length(var.db_master_password) >= 8 && length(var.db_master_password) <= 41
    error_message = "db_master_password must be 8-41 characters."
  }
}
