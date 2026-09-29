# Terraform AWS EC2 with SSH Key + Google Authenticator MFA

Infrastructure-as-Code project using **Terraform** to provision an AWS EC2 instance with secure SSH access using:

* SSH public/private key authentication
* Google Authenticator TOTP-based MFA
* Password authentication disabled
* AWS S3 remote Terraform state
* Automated server configuration using EC2 `user_data`

---

## Architecture

```text
                         GitHub Repository
                                │
                                │ Terraform
                                ▼
                         ┌───────────────┐
                         │     AWS       │
                         │               │
                         │  VPC          │
                         │  Subnet       │
                         │  Security     │
                         │  Group        │
                         │               │
                         │  ┌─────────┐  │
                         │  │  EC2    │  │
                         │  │ Ubuntu  │  │
                         │  └────┬────┘  │
                         └───────┼───────┘
                                 │
                         SSH Private Key
                                 +
                         Google Authenticator
                                 │
                                 ▼
                              SSH Login

                         Terraform State
                                │
                                ▼
                       ┌─────────────────┐
                       │    AWS S3       │
                       │ Remote Backend  │
                       └─────────────────┘
```

---

# Features

## Infrastructure

Terraform provisions:

* AWS EC2 instance
* Existing AWS VPC/subnet networking
* Security group
* SSH access
* Public IP association
* S3 bucket for Terraform remote state

## SSH Security

The EC2 instance is configured for:

```text
SSH Private Key
       +
Google Authenticator OTP
       ↓
    SSH Login
```

Normal Linux password authentication is disabled.

The effective SSH configuration is:

```text
PasswordAuthentication no
KbdInteractiveAuthentication yes
UsePAM yes
```

---

# Project Structure

```text
terraform-aws-ssh-mfa/
│
├── main.tf
├── backend.tf
├── user_data.sh
├── .gitignore
└── README.md
```

### `main.tf`

Contains the AWS infrastructure resources.

### `backend.tf`

Configures the Terraform S3 remote backend.

### `user_data.sh`

Automatically configures the EC2 server during its first boot.

It:

1. Updates Ubuntu packages
2. Installs Google Authenticator PAM
3. Configures SSH
4. Disables password authentication
5. Enables keyboard-interactive authentication
6. Enables PAM
7. Configures Google Authenticator PAM
8. Removes normal PAM password authentication from SSH
9. Validates SSH configuration
10. Restarts SSH

### `.gitignore`

Prevents sensitive Terraform state, SSH keys, and other local files from being uploaded to GitHub.

---

# Prerequisites

Before deploying the project, install:

* AWS CLI
* Terraform
* Git
* An AWS account
* An existing AWS VPC and subnet
* An EC2 SSH key pair

Verify Terraform:

```bash
terraform version
```

Verify AWS CLI:

```bash
aws --version
```

Verify Git:

```bash
git --version
```

---

# 1. Configure AWS CLI

Configure your AWS credentials:

```bash
aws configure
```

Provide:

```text
AWS Access Key ID
AWS Secret Access Key
Default region name
Default output format
```

For this project, the region is:

```text
us-east-1
```

Verify AWS access:

```bash
aws sts get-caller-identity
```

---

# 2. Configure the EC2 SSH Key

The EC2 instance uses an AWS key pair.

The Terraform configuration should reference the AWS key pair:

```hcl
key_name = "linux_practice"
```

Make sure the corresponding private key is available locally.

For example:

```text
linux_practice.pem
```

Set secure permissions:

```bash
chmod 400 linux_practice.pem
```

**Never upload the private key to GitHub.**

---

# 3. Configure the AWS Network

This project uses an existing VPC.

Example:

```text
VPC CIDR: 10.20.0.0/16
Region:   us-east-1
```

The Terraform EC2 resource should use a valid subnet:

```hcl
subnet_id = "YOUR_SUBNET_ID"
```

The subnet should have connectivity required for the EC2 instance.

For SSH from the internet, the subnet must have appropriate routing through an Internet Gateway and the instance must have a public IPv4 address.

---

# 4. Configure the Security Group

SSH access requires TCP port `22`.

Example:

```hcl
ingress {
  description = "SSH"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["YOUR_IP/32"]
}
```

For better security, restrict SSH access to your own public IP instead of:

```text
0.0.0.0/0
```

Avoid exposing SSH to the entire internet unless there is a specific reason.

---

# 5. Terraform Backend Bootstrap

This project uses an S3 bucket for Terraform remote state.

Example:

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state-bucket-ahmad-2026"
    key    = "path/to/my/terraform.tfstate"
    region = "us-east-1"
  }
}
```

There is an important Terraform limitation:

> Terraform cannot use an S3 backend before the S3 bucket exists.

Therefore, the first deployment requires a bootstrap process.

---

## First Deployment

Temporarily disable the backend:

```bash
mv backend.tf backend.tf.disable
```

Initialize Terraform:

```bash
terraform init -reconfigure
```

Create the infrastructure:

```bash
terraform apply
```

Confirm:

```text
yes
```

Terraform will create the S3 bucket and EC2 infrastructure using local state.

---

# 6. Enable the S3 Backend

After the S3 bucket has been created:

```bash
mv backend.tf.disable backend.tf
```

Initialize Terraform again and migrate the local state:

```bash
terraform init -migrate-state
```

Terraform will ask whether the existing local state should be copied to the new backend.

Answer:

```text
yes
```

Now Terraform state is stored remotely in S3.

Verify:

```bash
terraform plan
```

Expected result:

```text
No changes. Your infrastructure matches the configuration.
```

---

# 7. Deploy the EC2 Instance

Initialize Terraform:

```bash
terraform init
```

Format the configuration:

```bash
terraform fmt
```

Validate the configuration:

```bash
terraform validate
```

Review the deployment:

```bash
terraform plan
```

Apply:

```bash
terraform apply
```

Confirm with:

```text
yes
```

---

# 8. Connect to the EC2 Instance

Find the EC2 public IP from AWS or Terraform output.

SSH using:

```bash
ssh -i linux_practice.pem ubuntu@YOUR_PUBLIC_IP
```

The authentication flow is:

```text
SSH Private Key
       ↓
Google Authenticator OTP
       ↓
Ubuntu Shell
```

The Linux account password is not used for SSH authentication.

---

# 9. Configure Google Authenticator

The Terraform `user_data.sh` installs and configures the PAM module, but it does **not** store a user's Google Authenticator secret.

This is intentional.

After connecting to the server, run:

```bash
google-authenticator
```

Follow the prompts and scan the QR code using the Google Authenticator application.

This creates:

```text
~/.google_authenticator
```

for the user.

The secret should never be committed to Git.

---

# 10. Verify SSH MFA Configuration

On the EC2 instance:

```bash
sudo sshd -T | grep -E 'passwordauthentication|kbdinteractiveauthentication|usepam'
```

Expected:

```text
passwordauthentication no
kbdinteractiveauthentication yes
usepam yes
```

Check the PAM configuration:

```bash
sudo cat /etc/pam.d/sshd
```

The Google Authenticator module should be present:

```text
auth required pam_google_authenticator.so
```

Normal SSH password authentication should not be enabled through:

```text
@include common-auth
```

---

# 11. Test SSH Safely

Always keep your existing SSH session open while changing SSH configuration.

Before restarting SSH:

```bash
sudo sshd -t
```

If there is no output, the configuration is valid.

Then:

```bash
sudo systemctl restart ssh
```

Open a **second terminal** and test:

```bash
ssh -i linux_practice.pem ubuntu@YOUR_PUBLIC_IP
```

You should be asked for the Google Authenticator verification code.

You should not receive:

```text
ubuntu@YOUR_PUBLIC_IP's password:
```

---

# 12. Verify Terraform Remote State

Check the S3 bucket:

```bash
aws s3 ls s3://terraform-state-bucket-ahmad-2026/
```

You can also inspect the backend configuration:

```bash
terraform show
```

Terraform should now use the S3 backend instead of storing the active state only on the local machine.

---

# 13. GitHub Setup

Initialize Git:

```bash
git init
```

Add the files:

```bash
git add .
```

Check what will be committed:

```bash
git status
```

Commit:

```bash
git commit -m "Add Terraform AWS SSH MFA infrastructure"
```

Add the GitHub repository:

```bash
git remote add origin git@github.com:Ahmadraza9091/terraform-aws-ssh-mfa.git
```

Set the main branch:

```bash
git branch -M main
```

Push:

```bash
git push -u origin main
```

---

# Security

The following files must **never** be committed:

```text
*.pem
*.key
terraform.tfstate
terraform.tfstate.*
.terraform/
.google_authenticator
.env
```

Terraform state can contain sensitive infrastructure information, so it should remain outside the Git repository.

The `.gitignore` file protects these files from accidental commits.

---

# Why Google Authenticator Secrets Are Not in Terraform

The Google Authenticator secret is user-specific.

It should not be h
