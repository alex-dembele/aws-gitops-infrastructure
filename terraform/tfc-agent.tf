variable "tfc_agent_token" {
  description = "Token de l'agent Terraform Cloud"
  type        = string
  sensitive   = true
  default     = "" # À renseigner via Terraform Cloud Variables
}

resource "aws_security_group" "tfc_agent" {
  name        = "${var.cluster_name}-tfc-agent-sg"
  description = "Security group for TFC Agent"
  vpc_id      = module.vpc.vpc_id

  # Pas de règles Ingress nécessaires, le TFC Agent initie des connexions sortantes (Pull)
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-tfc-agent-sg"
  }
}

resource "aws_instance" "tfc_agent" {
  count         = var.tfc_agent_token != "" ? 1 : 0
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  subnet_id     = module.vpc.private_subnets[0] # Dans un subnet privé !

  vpc_security_group_ids = [aws_security_group.tfc_agent.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io unzip
              
              # Démarrage de l'agent TFC en tant que conteneur
              docker run -d \
                --name tfc-agent \
                --restart always \
                -e TFC_AGENT_TOKEN="${var.tfc_agent_token}" \
                -e TFC_AGENT_NAME="aws-gitops-agent" \
                hashicorp/tfc-agent:latest
              EOF

  tags = {
    Name = "${var.cluster_name}-tfc-agent"
  }
}
