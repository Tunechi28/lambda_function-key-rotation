variable "aws_access_key" {
    type            = string
    default         = ""
}

variable "aws_secret_key" {
    type            = string
    default         = ""
}

variable "cidr_block" {
    type            = string
    description     = "VPC cidr block."
    default         = "10.0.0.0/16"
}

variable "aws_region" {    
    default = "us-east-2"
}