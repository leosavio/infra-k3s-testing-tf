# Configure AWS provider 
provider "aws" {
  region = "us-east-1"
}

# Create an SSH Key Pair for EC2
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/deployer_key.pub") # Ensure you have this public key
}

# Create a Security Group for EC2
resource "aws_security_group" "k3s_sg" {
  name        = "k3s_sg"
  description = "Allow SSH and k3s related ports"
  vpc_id = "vpc-2a78644f"

  ingress {
    description = "access 22"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "access 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "access 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "access 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "remote kubectl access"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Add more ingress/egress rules as needed
}

# Create EC2 instance for k3s
resource "aws_instance" "k3s" {
  ami           = "ami-0261755bbcb8c4a84" # Ubuntu 20.04 AMI
  associate_public_ip_address = true
  instance_type = "c5n.2xlarge" #"m6a.2xlarge" #"m5a.xlarge" # "m5d.xlarge" "c5.large"
  key_name      = aws_key_pair.deployer.key_name
  subnet_id = "subnet-e25d34c9"
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  #spot_price           = "0.29" # Set your bid price here
  instance_market_options {
    market_type = "spot"
  }

  tags = {
    Name = "k3s"
  }

  #excluding k3s conf at destroy
  # provisioner "local-exec" {
  #   when    = destroy
  #   command = <<-EOT
  #     "rm -rf /workspace/k3s-remote-config.yaml"
  #   EOT
  # }
  
} 

# javars Hosted Zone
data "aws_route53_zone" "selected" {
  zone_id = "Z0069603133FFNI50HCF"
}

# randon for generating route53 custom records
resource "random_id" "subdomain" {
  byte_length = 2  # This will generate a 4-character hexadecimal string
  keepers = {
    # Change the value here to generate a new ID
    instance_id = aws_instance.k3s.id
  }
}

# Create A record pointing to k3s IP
resource "aws_route53_record" "k3s" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "k3s-${random_id.subdomain.hex}.java.rs"
  type    = "A"
  ttl     = "60"
  records = [aws_instance.k3s.public_ip]
  depends_on = [aws_instance.k3s]
}

# Install and start k3s on EC2 instance
resource "null_resource" "k3s_setup_remote" {
  provisioner "remote-exec" {
    connection {
        host = aws_instance.k3s.public_ip
        user = "ubuntu"
        private_key = file("~/.ssh/deployer_key")
    }

    inline = [
      "curl -fsSL https://raw.githubusercontent.com/portalnetcar/infra-docker-install-auto/main/install_docker.sh | bash",
      "curl -sfL https://get.k3s.io | sh -",
      "sudo chmod 644 /etc/rancher/k3s/k3s.yaml"
    ] 
  }

  depends_on = [aws_instance.k3s]
}

# configure local kubectl
resource "null_resource" "k3s_setup_local" {

  provisioner "local-exec" {
    command = <<-EOT
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      chmod +x kubectl
      sudo mv kubectl /usr/local/bin/
      scp -o StrictHostKeyChecking=no -i ~/.ssh/deployer_key ubuntu@${aws_instance.k3s.public_ip}:/etc/rancher/k3s/k3s.yaml ../k3s-remote-config.yaml
      sed -i 's|https://127.0.0.1:6443|https://${aws_instance.k3s.public_ip}:6443|g' ../k3s-remote-config.yaml
      export KUBECONFIG=../k3s-remote-config.yaml
      alias kubectl="kubectl --kubeconfig=../k3s-remote-config.yaml --insecure-skip-tls-verify"
      kubectl apply -f whoami.yaml
    EOT
  }

  depends_on = [null_resource.k3s_setup_remote]
}






# Deploy Nginx to k3s 
# (Ensure kubectl is configured to connect to the k3s instance)
# resource "null_resource" "deploy_nginx" {
#   provisioner "remote-exec" {
#     connection {
#         host = aws_instance.k3s.public_ip
#         user = "ubuntu"
#         private_key = file("~/.ssh/deployer_key")
#     }
#     inline = [
#        "kubectl apply -f https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/application/nginx-app.yaml"
#     ]
#   }

#   depends_on = [aws_instance.k3s]
# }

output "record_name" {
  value = aws_route53_record.k3s.name
}