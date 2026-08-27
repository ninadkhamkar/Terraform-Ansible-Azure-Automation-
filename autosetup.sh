#!/bin/bash

sudo apt-get upgrade -y;
sudo apt-add-repository ppa:ansible/ansible;
echo "---------------------------------------------------Please press enter-------------------------------------------------------";
sudo apt-get update;
sudo apt-get install ansible -y;
sudo apt-get install python -y;
echo "---------------------------------------------------Checking Python is installed-------------------------------------------------------";
echo "---------------------------------------------------Installation Complete starting ssh key process-------------------------------------------------------";
mkdir ~/.azure && cd ~/.azure;
echo "------------------------------------------------IMPORTANT------------------------------------------------------------------------";
echo "Please create ~/.azure/credentials using credentials.example as a template and input your Azure Service Principal values";
echo "------------------------------------------------IMPORTANT------------------------------------------------------------------------";
cd ~/;
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!starting keygen process!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
ssh-keygen;
echo "------------------------------------------------Please copy this key into your node server-----------------------------------------------------";
echo "--------------------------------------------------------------------------------------------------------------------------------------------------";
cat ~/.ssh/id_rsa.pub;
echo "------------------------------------------------Please copy this key into your node server-----------------------------------------------------";
echo "------------------------------------------------Send this ssh key to your node by using this command-----------------------------------------------------";
echo "------------------------------------------------ssh-copy-id <NODE_IP_ADDRESS>-----------------------------------------------------";
