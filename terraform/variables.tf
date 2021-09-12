variable "HAXELIB_DB_USER" {
  type = string
  default = "terraform"
}
variable "HAXELIB_DB_PASS" {
  type = string
}

variable "HAXELIB_SERVER_IMAGE_DEVELOPMENT" {
  type = string
  default = null
}

variable "HAXELIB_SERVER_IMAGE_MASTER" {
  type = string
  default = null
}
