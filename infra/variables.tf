variable "aws_region" {
  description = "Região AWS para provisionar os recursos"
  type        = string
  default     = "us-east-1" 
}

variable "vpc_cidr_block" {
  description = "Bloco CIDR para a VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_block" {
  description = "Bloco CIDR para a sub-rede pública"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr_block" {
  description = "Bloco CIDR para a sub-rede privada"
  type        = string
  default     = "10.0.2.0/24"
}

variable "instance_type" {
  description = "Tipo de instância EC2 a ser usada"
  type        = string
  default     = "t2.micro" 
}

variable "ami_id" {
  description = "ID da AMI (Amazon Machine Image) para as instâncias EC2 (Ubuntu LTS)"
  type        = string
  default     = "ami-0c7217cdde317cfec" 
}

