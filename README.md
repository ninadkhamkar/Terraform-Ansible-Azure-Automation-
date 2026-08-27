# Terraform Ansible Azure

Terraform Infrastructure as Code project that provisions Linux virtual machines on Microsoft Azure, and uses a bash automation script to set up Ansible for configuration management of those remote hosts.

## 📖 Table of Contents

- [Introduction](#introduction)
- [Ansible Glossary](#ansible-glossary)
- [File Structure](#file-structure)
- [What is Terraform](#what-is-terraform)
- [What Gets Deployed](#what-gets-deployed)
- [Prerequisites](#prerequisites)
- [Terraform Deployment Template Setup for Ansible](#terraform-deployment-template-setup-for-ansible)
- [Deploy Terraform Infrastructure Commands](#deploy-terraform-infrastructure-commands)
- [Connecting to Terraform Cloud Remote Backend](#connecting-to-terraform-cloud-remote-backend)
- [Create an Azure Blob Storage Container for tfstate Backend (Alternative)](#create-an-azure-blob-storage-container-for-tfstate-backend-alternative)
- [Create a Service Principal with a Client Secret](#create-a-service-principal-with-a-client-secret)
- [Configuring the Service Principal in Terraform](#configuring-the-service-principal-in-terraform)
- [Create SSH Service Connection in Azure DevOps](#create-ssh-service-connection-in-azure-devops)
- [Run the Shell Script](#run-the-shell-script)
- [Ansible Installation on Ubuntu Linux (Manual)](#ansible-installation-on-ubuntu-linux-manual)
- [Configure Ansible Inventory](#configure-ansible-inventory)
- [Configure Ansible to Run as a Specific User](#configure-ansible-to-run-as-a-specific-user)
- [Ansible Playbooks for Azure](#ansible-playbooks-for-azure)
- [Ansible Tower Installation on Ubuntu Linux](#ansible-tower-installation-on-ubuntu-linux)
- [Security Notes](#security-notes)
- [Notes](#notes)
- [Bugs or Errors](#bugs-or-errors)

## Introduction

This project uses Terraform to provision Linux virtual machines on Microsoft Azure, and a custom bash script to automate the setup of Ansible so it can control and push configurations to those remote hosts. It is intended as a rapid lab/educational environment for practicing Infrastructure as Code alongside configuration management.

The overall flow is:

1. **Terraform** provisions the Azure infrastructure (resource group, network, VMs, NSG, public IPs).
2. **A bash script (`autosetup.sh`)** installs Ansible and generates an SSH key pair on the control node.
3. **Ansible** is then pointed at the provisioned VMs via an inventory file, and used to push configuration/playbooks to them.

## Ansible Glossary

The following Ansible-specific terms are used throughout this guide:

- **Inventory File** — a file that contains information about the servers Ansible controls, typically located at `/etc/ansible/hosts`.
- **Playbook** — a file containing a series of tasks to be executed on a remote server.
- **Remote Host / Node** — a server controlled by Ansible.
- **Ansible Server / Control Node** — the system where Ansible is installed and configured to connect to and execute commands on remote hosts/nodes.
- **Ad-hoc Command** — a one-off Ansible command run directly from the CLI without writing a full playbook (e.g. `ansible -m ping all`).
- **Module** — a reusable, standalone script Ansible runs on your behalf, either locally or on a remote node (e.g. `ping`, `apt`, `copy`).
- **Role** — a structured way of organizing playbooks and related files so they can be reused across projects.

## File Structure

| File | Description |
|---|---|
| `main.tf` | Infrastructure as Code — defines all Azure resources |
| `provider.tf` | Azure provider and Terraform Cloud remote backend configuration |
| `variables.tf` | Input variables for the deployment |
| `autosetup.sh` | Automates Ansible installation and SSH key generation on the control node |
| `credentials.example` | Template for Azure Service Principal credentials |
| `.gitignore` | Prevents state files, secrets, and SSH keys from being committed |
| `README.md` | This guide |

## What is Terraform

- **Terraform** — an open-source Infrastructure as Code tool that lets you define and provision infrastructure using a declarative configuration language (HCL). Learn more at [terraform.io](https://www.terraform.io/).
- **Microsoft Azure** — the cloud platform this project provisions resources on. Learn more at [azure.microsoft.com](https://azure.microsoft.com/).
- **Ansible** — an open-source automation tool used for configuration management, application deployment, and task automation. Learn more at [ansible.com](https://www.ansible.com/).
- **Bash Script** — used here to automate the repetitive setup commands needed to get Ansible running on the control node.

## What Gets Deployed

Running `terraform apply` on this configuration creates the following resources in Azure:

- 1 Resource Group
- 1 Virtual Network with 1 subnet (`10.0.0.0/16` → `10.0.2.0/24`)
- 1 Network Security Group with an inbound rule allowing SSH (port 22 by default)
- 2 Public IP addresses (Static, Standard SKU)
- 4 Network Interfaces — 2 per VM (one public-facing "main" NIC, one "internal" NIC)
- 2 Linux Virtual Machines (Ubuntu 22.04 LTS, `Standard_B1s`)
- 2 randomly generated VM passwords (`random_string.password`)

### Randomized Password String

When you deploy this infrastructure, Terraform will print the generated passwords in your terminal, similar to this:

```
random_string.password[0]: Creation complete after 0s [id=*?wq?*2l2GI4x5Bj]
random_string.password[1]: Creation complete after 0s [id=r@Tt4AR?!Yv@2?PI]
```

`password[0]` is assigned to `vm-0`, and `password[1]` is assigned to `vm-1` — the `random_string` resource's `count.index` lines up with the virtual machine's `count.index`.

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell) (if working from Windows)
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [Visual Studio Code](https://code.visualstudio.com/download) (recommended)
- [HashiCorp Terraform Extension for VS Code](https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform)
- An active Azure subscription
- A [Terraform Cloud](https://app.terraform.io/) account (for remote state/backend)

## Terraform Deployment Template Setup for Ansible

This template is built to deploy Linux VMs to Azure using Terraform, in order to automatically provision an environment where Ansible (or Ansible Tower) can be installed and used to configure those VMs rapidly and repeatably — useful for labs, POCs, or quickly spinning up an enterprise-style environment.

You can find the latest Terraform provider documentation and resource examples at:
- [Terraform AzureRM Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [AzureRM Provider Examples](https://github.com/terraform-providers/terraform-provider-azurerm/tree/master/examples)

## Deploy Terraform Infrastructure Commands

Before deploying, update `provider.tf` with your own Terraform Cloud organization/workspace (see below), and review `variables.tf` for anything you want to change (region, prefix, SSH port, etc).

```bash
terraform init      # Initialize the working directory and download providers
terraform fmt        # Auto-format your .tf files
terraform plan        # Preview what Terraform will create/change/destroy
terraform apply        # Apply the changes to provision infrastructure
terraform destroy       # Tear down everything Terraform created
```

## Connecting to Terraform Cloud Remote Backend

Using Terraform Cloud as a remote backend keeps your state file out of version control, supports locking to prevent concurrent conflicting runs, and gives you a run history/UI.

1. Register an account at [app.terraform.io](https://app.terraform.io/) (enabling MFA is recommended).
2. Create an **Organization**, then create a **New Workspace** (CLI-driven workflow works well with this repo).
3. With Azure CLI, PowerShell, and Terraform installed, authenticate locally from your terminal:

   ```bash
   terraform login
   ```

4. Follow the terminal prompts — this opens a browser to generate an API token, which you then paste back into the terminal to complete authentication.
5. Update `provider.tf` with your own organization and workspace name:

   ```hcl
   terraform {
     cloud {
       organization = "your-org-name"

       workspaces {
         name = "your-workspace-name"
       }
     }
   }
   ```

6. Run `terraform init` again to link the working directory to the new remote workspace.

Once linked, `terraform plan` / `apply` / `destroy` run locally from your CLI but execute and store state in Terraform Cloud, and you can review each run's plan output in the Terraform Cloud UI.

## Create an Azure Blob Storage Container for tfstate Backend (Alternative)

If you'd prefer to store your state file in Azure Storage instead of Terraform Cloud, use the `azurerm` backend instead of `cloud` in `provider.tf`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "your-resource-group-name"
    storage_account_name = "your-storage-account-name"
    container_name        = "tfstate"
    key                    = "terraform.tfstate"
  }
}
```

You'll need to pre-create the resource group, storage account, and blob container before running `terraform init` with this backend configured.

## Create a Service Principal with a Client Secret

A Service Principal is an identity Terraform uses to authenticate against your Azure subscription non-interactively. Review the [HashiCorp guide for Azure Service Principal authentication](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) for the full walkthrough, or create one quickly via Azure CLI:

```bash
az ad sp create-for-rbac --name "terraform-ansible-azure-sp" --role="Contributor" --scopes="/subscriptions/<your-subscription-id>"
```

This returns an `appId` (client_id), `password` (client_secret), and `tenant` — save these securely, the secret is only shown once.

## Configuring the Service Principal in Terraform

**Preferred approach — environment variables** (keeps secrets out of your code entirely):

```bash
export ARM_CLIENT_ID="<client_id>"
export ARM_CLIENT_SECRET="<client_secret>"
export ARM_SUBSCRIPTION_ID="<subscription_id>"
export ARM_TENANT_ID="<tenant_id>"
```

On Windows (PowerShell):

```powershell
setx ARM_CLIENT_ID "<client_id>"
setx ARM_CLIENT_SECRET "<client_secret>"
setx ARM_SUBSCRIPTION_ID "<subscription_id>"
setx ARM_TENANT_ID "<tenant_id>"
```

Restart your terminal/VS Code after setting these for the changes to take effect.

**Alternative — explicit provider block** (not recommended for anything beyond quick local testing, since secrets end up in your `.tf` files):

```hcl
provider "azurerm" {
  features {}

  subscription_id = "<subscription_id>"
  client_id       = "<client_id>"
  client_secret   = "<client_secret>"
  tenant_id       = "<tenant_id>"
}
```

Once the infrastructure has been deployed, locate the public IP address from the `terraform apply` output or the Azure Portal, and connect over SSH:

```bash
ssh adminuser@<public-ip-address>
```

## Create SSH Service Connection in Azure DevOps

If you want to push Ansible playbooks to the VM from an Azure DevOps pipeline, set up an SSH service connection:

1. Go to [dev.azure.com](https://dev.azure.com/) → your Project → **Project Settings** → **Service Connections** → **New Service Connection** → select **SSH**.
2. Fill in the connection details: Public IP address of the target VM, the admin username, the password (or private key), and the `id_rsa` contents generated in the next section.
3. Save the connection — it can now be referenced in pipeline tasks that need to SSH into the VM.

## Run the Shell Script

Clone this repository and run the automation script to install Ansible and generate your SSH key:

```bash
git clone <your-repo-url> && cd terraform-ansible-azure

chmod +x autosetup.sh
./autosetup.sh
```

> **Note:** `autosetup.sh` automates the Ansible installation and SSH keygen steps. You still need to manually copy your public key to each remote host and configure the Ansible inventory — see the sections below.

## Ansible Installation on Ubuntu Linux (Manual)

Follow this section if you'd rather install Ansible manually instead of using the script.

**1. Update packages:**

```bash
sudo apt-get upgrade -y
```

**2. Add the official Ansible PPA:**

```bash
sudo apt-add-repository ppa:ansible/ansible
```

**3. Install Ansible and Python:**

```bash
sudo apt-get update
sudo apt-get install ansible -y
sudo apt-get install python3 -y
```

**4. Verify the installed version:**

```bash
ansible --version
```

**5. Set up Azure authentication for the Ansible control node** *(only needed if using Ansible's Azure dynamic inventory / `azure.azcollection` modules)*:

```bash
mkdir ~/.azure && cd ~/.azure
```

Copy `credentials.example` from this repo to `~/.azure/credentials` and fill in your own Service Principal values:

```ini
[default]
subscription_id=<your-Azure-subscription_id>
client_id=<azure-service-principal-appid>
secret=<azure-service-principal-password>
tenant=<azure-service-principal-tenant>
```

**6. Generate an SSH key for the Ansible control node:**

```bash
ssh-keygen
cat ~/.ssh/id_rsa.pub
```

**7. Copy the public key to each remote host you want Ansible to manage:**

Quick option, from the control node:

```bash
ssh-copy-id adminuser@<remote-host-ip>
```

Manual option:
1. Copy the contents of `~/.ssh/id_rsa.pub` from the control node.
2. Log into the remote server, switch to root (`sudo -s`), and open `~/.ssh/authorized_keys` (`sudo nano ~/.ssh/authorized_keys`).
3. Paste the public key on a new line, save, and close.

> Make sure you're checking `authorized_keys` under the correct home directory for the user you intend to connect as — it commonly lives under `/root/.ssh/` or `/home/<user>/.ssh/` depending on which user you SSH in as.

## Configure Ansible Inventory

Edit the default inventory file:

```bash
sudo nano /etc/ansible/hosts
```

Define a group for your Azure VMs, with each host identified by a custom alias — update the IPs to match your deployed VMs' public IP addresses:

```ini
[azureservers]
azureserver  ansible_host=<vm-0-public-ip>
azureserver2 ansible_host=<vm-1-public-ip>

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

View the resolved inventory:

```bash
ansible-inventory --list -y
```

Expected output shape:

```yaml
all:
  children:
    azureservers:
      hosts:
        azureserver:
          ansible_host: <vm-0-public-ip>
          ansible_python_interpreter: /usr/bin/python3
        azureserver2:
          ansible_host: <vm-1-public-ip>
          ansible_python_interpreter: /usr/bin/python3
```

**Test connectivity** to all hosts:

```bash
ansible -m ping all
```

Expected output:

```
azureserver | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
azureserver2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

Ping a specific group only (e.g. if you later define a `[databases]` group):

```bash
ansible -m ping databases
```

**Check remote system info** using an ad-hoc raw command:

```bash
ansible -u adminuser -i /etc/ansible/hosts -m raw -a 'uname -a' azureservers
```

**Check disk usage** across all remote servers:

```bash
ansible all -a "df -h" -u adminuser
```

## Configure Ansible to Run as a Specific User

To have all servers in a group connect as a specific user by default, create a group variables file:

```bash
sudo mkdir /etc/ansible/group_vars
sudo nano /etc/ansible/group_vars/servers
```

Add the username used on the remote hosts:

```yaml
ansible_ssh_user: adminuser
```

You can create a group-specific file (e.g. `/etc/ansible/group_vars/azureservers`) if you want this to apply only to the `[azureservers]` group rather than all hosts.

## Ansible Playbooks for Azure

A **playbook** is a YAML file containing an ordered list of tasks to run against your inventory. A minimal example that installs and starts NGINX on the `azureservers` group:

```yaml
---
- name: Configure web servers
  hosts: azureservers
  become: true
  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present
        update_cache: true

    - name: Ensure nginx is running
      service:
        name: nginx
        state: started
        enabled: true
```

Run it with:

```bash
ansible-playbook -i /etc/ansible/hosts playbook.yml
```

For official Azure-focused playbook examples and the `azure.azcollection` Ansible collection, see the [Microsoft Azure Samples for Ansible](https://docs.microsoft.com/en-us/samples/azure-samples/ansible-playbooks/ansible-playbooks-for-azure/).

## Ansible Tower Installation on Ubuntu Linux

Ansible Tower (now succeeded by the open-source **AWX** project and Red Hat **Ansible Automation Platform**) provides a web UI, REST API, and RBAC on top of Ansible. If you want a UI-driven control plane instead of pure CLI, you can install it on the same Ubuntu control node:

Assuming `ansible-tower-setup-latest.tar.gz` is in `/tmp`:

```bash
cd /tmp
tar -zxvf ansible-tower-setup-latest.tar.gz
cd /tmp/ansible-tower-setup-<version>
vi inventory
```

Example inventory file contents:

```ini
[tower]
localhost ansible_connection=local

[database]

[all:vars]
admin_password=''

pg_host=''
pg_port=''

pg_database='awx'
pg_username='awx'
pg_password=''

rabbitmq_username=tower
rabbitmq_password=''
rabbitmq_cookie=cookiemonster

# Isolated Tower nodes automatically generate an RSA key for authentication.
# To disable this behavior, set this value to false.
isolated_key_generation=true
```

Fill in your own values for `admin_password`, `pg_password`, and `rabbitmq_password` (leave these blank in version control — treat them the same as any other secret).

Start the installation:

```bash
cd /tmp/ansible-tower-setup-<version>
./setup.sh
```

Once installation completes, open a browser to the IP address of your Tower node. Log in with username `admin` and the password you set in `admin_password`.

**Notes on Ansible Tower:**
- Officially supported only up to Ubuntu 16.04 in older releases — it does **not** support Ubuntu 18 or 19.
- For modern Ubuntu (20.04+), use **AWX** (the open-source upstream project) or **Red Hat Ansible Automation Platform** instead.
- Default username is `admin`.

## Security Notes

- **Never commit real credentials.** `.gitignore` in this repo excludes `*.tfstate`, `credentials`, SSH private keys, and `.tfvars` files — keep it that way.
- **Prefer environment variables** (`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, etc.) over hardcoding Service Principal secrets in `provider.tf`.
- **VM passwords are auto-generated** via `random_string.password` rather than hardcoded — don't reintroduce a static default password into `variables.tf`.
- **Lock down the NSG.** The default `azurerm_network_security_group.ansible` rule allows the SSH port from `source_address_prefix = "*"` (any source). Restrict this to your own IP range before using this outside of a throwaway lab.
- **Rotate the Service Principal secret** periodically, and scope its role assignment as narrowly as your workflow allows (avoid `Owner` where `Contributor` suffices).
- **Treat `admin_password` / `pg_password` / `rabbitmq_password`** in the Ansible Tower inventory file the same as any other secret — never commit them with real values.

## Notes

- Default VM size is `Standard_B1s`; adjust in `main.tf` for heavier workloads.
- Default OS image is Ubuntu 22.04 LTS (`Canonical` / `0001-com-ubuntu-server-jammy`).
- Use `terraform fmt` to auto-fix formatting/spacing in your `.tf` files before committing.
- This project is intended for lab, training, and educational use — review and harden the NSG rules, credential handling, and VM sizing before adapting it for production use.

## Bugs or Errors

Found an issue or have an improvement? Feel free to open a Pull Request or submit an Issue on this repository.
