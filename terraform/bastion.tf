resource "aws_security_group" "bastion" {
  name        = "${local.cluster_name}-bastion-sg"
  description = "Security group for bastion host and Wireguard"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Wireguard VPN"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # À restreindre à votre IP publique en production
    description = "SSH Access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.cluster_name}-bastion-sg"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = module.vpc.public_subnets[0]

  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y wireguard
              umask 077
              wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
              # Configuration simplifiée (à enrichir avec les peers pour un usage complet)
              cat <<EOWG > /etc/wireguard/wg0.conf
              [Interface]
              Address = 10.8.0.1/24
              SaveConfig = true
              ListenPort = 51820
              PrivateKey = $(cat /etc/wireguard/privatekey)
              EOWG
              systemctl enable wg-quick@wg0
              systemctl start wg-quick@wg0
              EOF

  tags = {
    Name = "${local.cluster_name}-bastion"
  }
}

output "bastion_public_ip" {
  description = "IP publique du bastion pour accès SSH/Wireguard"
  value       = aws_instance.bastion.public_ip
}
