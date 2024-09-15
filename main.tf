data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

data "aws_vpc" "default" {
  default = true
}

module "web_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type

  vpc_security_group_ids = [module.web-sg.security_group_id]

  subnet_id = module.web_vpc.public_subnets[0]

  tags = {
    Name = "HelloWorld"
  }
}

module "web-alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "my-alb"
  vpc_id  = module.web_vpc.vpc_id
  subnets = module.web_vpc.public_subnets

  # Security Group
  security_group_ingress_rules = [module.web-sg .security_group_id]

  target_groups = {
    ex-instance = {
      name_prefix      = "h1"
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
      target_id        = aws_instance.web.id
    }
  }

  listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0 
    }
  ]

  tags = {
    Environment = "Dev"
  }
}

module "web-sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"
  name    = "web_new"

  vpc_id = module.web_vpc.vpc_id

  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

