#!/bin/bash

# amazon-linux-extras install -y ansible2 epel

# mkdir /root/ansible
# cd /root/ansible
# wget https://std-ansible.s3.ap-northeast-1.amazonaws.com/ansible/std-ansible.zip
# unzip ./std-ansible.zip
# ansible-playbook site.yaml --tags common

sudo timedatectl set-timezone Asia/Tokyo
sudo yum update 
sudo yum install -y httpd
sudo systemctl start httpd
sudo echo "hello world!" > /var/www/html/index.html

# TODO : newrelic-agentのインストール


exit 0