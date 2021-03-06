terraform {
  required_version = "~> 0.14"
}


# Fetch the latest Ubuntu 18.04 version
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-18.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]

}

# Create Jenkins server Launch configuration
resource "aws_launch_configuration" "jenkinslc" {
  name_prefix     = "aws_lc-"
  image_id        = data.aws_ami.ubuntu.id
  instance_type   = var.instance_type
  key_name        = var.ssh_key_name
  security_groups = [aws_security_group.Jenkins-SG.id]
  user_data       = <<-EOF
              #!/bin/bash
              sudo apt-get -y update
              sudo apt-get install -y unzip
              sudo apt-get install -y nfs-common
              sudo mkdir -p /var/lib/jenkins
              sudo adduser -m -d /var/lib/jenkins jenkins
              sudo groupadd jenkins
              sudo usermod -a -G jenkins jenkins
              sudo chown -R jenkins:jenkins /var/lib/jenkins
              while ! (sudo mount -t nfs4 -o vers=4.1 $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone).${aws_efs_file_system.JenkinsEFS.dns_name}:/ /var/lib/jenkins); do sleep 10; done
              # Edit fstab so EFS automatically loads on reboot
              while ! (echo ${aws_efs_file_system.JenkinsEFS.dns_name}:/ /var/lib/jenkins nfs defaults,vers=4.1 0 0 >> /etc/fstab) ; do sleep 10; done
              sudo apt-get -y install openjdk-11-jdk
              sudo wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
              echo "deb https://pkg.jenkins.io/debian-stable binary/" | sudo tee -a /etc/apt/sources.list
              sudo apt-get -y update
              sudo apt-get -y install jenkins
              EOF
}



