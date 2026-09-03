
# Highly Available Web Application on AWS using Terraform

## Project Overview

This project demonstrates how to build and deploy a highly available web application infrastructure on AWS using Terraform.

The infrastructure is designed to distribute incoming HTTP traffic across two Nginx web servers running on Amazon EC2 instances in separate Availability Zones.

The entire infrastructure is defined as code using Terraform, allowing it to be created, modified, and destroyed consistently without manually configuring each AWS resource through the AWS Management Console.

### Key AWS Services Used

- Amazon VPC
- Amazon EC2
- Application Load Balancer (ALB)
- Target Groups
- Internet Gateway
- Route Tables
- Security Groups
- Availability Zones

### Infrastructure as Code

- Terraform
- AWS Provider
- HCL (HashiCorp Configuration Language)

## Architecture

The application is deployed in the AWS Mumbai Region (`ap-south-1`).

The architecture consists of a Virtual Private Cloud (VPC) with two public subnets distributed across two Availability Zones.

An internet-facing Application Load Balancer receives HTTP requests from users and distributes the requests across two EC2 instances running Nginx.

<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/98ee0021-c7c6-4cfc-865c-156f4599b145" />

### Request Flow

The application follows this traffic flow:

```text
User
  |
  | HTTP :80
  v
Internet Gateway
  |
  v
Application Load Balancer
  |
  v
ALB Listener :80
  |
  v
Target Group
  |
  +-----------------------+
  |                       |
  v                       v
EC2 Web Server A       EC2 Web Server B
ap-south-1a            ap-south-1b
  |                       |
  v                       v
Nginx                   Nginx

```

## Infrastructure Components

### 1. VPC

A Virtual Private Cloud (VPC) provides the isolated networking environment for the application.

- VPC CIDR: `10.0.0.0/16`
- AWS Region: `ap-south-1`
- DNS support: Enabled
- DNS hostnames: Enabled

The `10.0.0.0/16` CIDR provides a private IP address space containing 65,536 IPv4 addresses.

The VPC is divided into smaller subnet ranges for deploying resources across multiple Availability Zones.

### 2. Public Subnets

Two public subnets are created in separate Availability Zones:

| Subnet | CIDR | Availability Zone |
|---|---|---|
| Public Subnet A | `10.0.1.0/24` | `ap-south-1a` |
| Public Subnet B | `10.0.2.0/24` | `ap-south-1b` |

Each `/24` subnet provides 256 IPv4 addresses, of which AWS reserves 5 addresses for networking purposes.

Using two Availability Zones improves availability because the application is not dependent on a single Availability Zone.

### 3. Internet Gateway

An Internet Gateway (IGW) is attached to the VPC to provide a path between the VPC and the public internet.

The Internet Gateway itself does not automatically make a subnet public.

A route table must contain a route that directs internet-bound traffic to the Internet Gateway.

### 4. Public Route Table

The public route table contains a default route:

| Destination | Target |
|---|---|
| `0.0.0.0/0` | Internet Gateway |

`0.0.0.0/0` represents all IPv4 destinations that are not part of a more specific route.

## Application Load Balancer

An Application Load Balancer (ALB) is used as the single entry point for users accessing the web application.

The ALB is internet-facing and listens for HTTP traffic on port `80`.

Instead of users connecting directly to an EC2 instance, they connect to the ALB. The ALB then forwards the request to a healthy EC2 instance through the Target Group.

### ALB Configuration

- Type: Application Load Balancer
- Scheme: Internet-facing
- Protocol: HTTP
- Listener Port: `80`
- Availability Zones:
  - `ap-south-1a`
  - `ap-south-1b`
- Security Group: `terraform-alb-sg`

The ALB is deployed across both public subnets, allowing it to remain available even if one Availability Zone experiences a failure.

## Target Group

The ALB uses a Target Group to identify the backend servers that can receive application traffic.

The target group created in this project is:

- Name: `terraform-web-tg`
- Target type: EC2 instances
- Protocol: HTTP
- Port: `80`
- Health check protocol: HTTP
- Health check path: `/`
- Healthy threshold: `2`
- Unhealthy threshold: `2`
- Health check interval: `30` seconds

The two EC2 instances are registered as targets in the Target Group.

The route table is associated with both public subnets.

This allows resources with public IP addresses in these subnets to communicate with the internet through the Internet Gateway.

### Health Checks

The ALB periodically sends HTTP health-check requests to the registered EC2 instances.

The health check uses:

```text
Protocol: HTTP
Port: 80
Path: /
```

## EC2 Web Servers

Two Amazon EC2 instances are deployed to provide the backend web application.

| Server | Availability Zone | Subnet | Application |
|---|---|---|---|
| Web Server A | `ap-south-1a` | `10.0.1.0/24` | Nginx |
| Web Server B | `ap-south-1b` | `10.0.2.0/24` | Nginx |

Both instances use the `t3.micro` instance type.

Nginx is installed automatically using Terraform EC2 `user_data`.

### Server A

The startup script installs Nginx, starts the service, and creates:

```text
Hello from Terraform - Server A
```

### Server B

The startup script installs Nginx, starts the service, and creates:

```text
Hello from Terraform - Server B
```



## Security Groups

Two separate Security Groups are used to control network traffic.

### ALB Security Group

The ALB security group allows:

| Direction | Protocol | Port | Source |
|---|---|---:|---|
| Inbound | TCP | 80 | `0.0.0.0/0` |
| Outbound | All | All | `0.0.0.0/0` |

The inbound rule allows users on the internet to send HTTP requests to the ALB.

### EC2 Security Group

The EC2 instances use a separate Security Group that only allows HTTP traffic from the Application Load Balancer.

| Direction | Protocol | Port | Source |
|---|---|---:|---|
| Inbound | TCP | 80 | ALB Security Group |
| Outbound | All | All | `0.0.0.0/0` |

The inbound rule allows HTTP traffic on port `80` only when the traffic originates from the ALB Security Group.

The EC2 instances are therefore not configured to accept HTTP traffic directly from the public internet.

The traffic flow is:

```text
Internet
   |
   | HTTP :80
   v
ALB Security Group
   |
   | HTTP :80
   v
EC2 Security Group
   |
   v
Nginx
```

## Terraform Project Structure

The project uses multiple Terraform configuration files to organize the infrastructure and keep the configuration maintainable.

```text
terraform-aws-ha-webapp/
│
├── .devcontainer/
│
├── main.tf
├── variables.tf
├── versions.tf
├── outputs.tf
├── .gitignore
├── README.md
│
└── screenshots/
    ├── architecture.png
    ├── vpc.png
    ├── subnets.png
    ├── ec2.png
    ├── alb.png
    ├── target-group.png
    ├── server-a.png
    ├── server-b.png
    └── terraform-destroy.png
```

## Terraform Deployment Workflow

The infrastructure is deployed and managed using the standard Terraform workflow.

### 1. Initialize Terraform

```bash
terraform init  
```

### 2. Format the Configuration

```bash
terraform fmt  
```

### 3. Validate the Configuration

```bash
terraform validate
```
Checks the Terraform configuration for syntax and configuration errors.


### 4. Create an Execution Plan

```bash
terraform plan  
```
Shows the infrastructure changes Terraform intends to make before deployment.

### 5. Apply the Configuration

```bash
terraform apply  
```
Creates or updates the infrastructure in AWS according to the Terraform configuration.

### 6. Verify the Deployment

After deployment, the AWS Management Console and Terraform outputs were used to verify the infrastructure.`

### 7. Destroy the Infrastructure

```bash
terraform destroy
```
Removes the infrastructure managed by Terraform.


## VPC and Networking

The project creates an Amazon VPC to provide an isolated network environment for the application.

### VPC Configuration

| Property | Value |
|---|---|
| VPC Name | `terraform-ha-vpc` |
| Region | `ap-south-1` |
| CIDR Block | `10.0.0.0/16` |
| DNS Support | Enabled |
| DNS Hostnames | Enabled |

The VPC uses the `10.0.0.0/16` CIDR block, providing a private IP address range for resources within the VPC.

### Subnets

Two public subnets are created across different Availability Zones to provide high availability.

| Subnet | Availability Zone | CIDR Block |
|---|---|---|
| Public Subnet A | `ap-south-1a` | `10.0.1.0/24` |
| Public Subnet B | `ap-south-1b` | `10.0.2.0/24` |

Each subnet is associated with the VPC and uses a separate `/24` CIDR range.

The subnets are configured to automatically assign public IPv4 addresses to launched EC2 instances.

### Internet Connectivity

An Internet Gateway is attached to the VPC to provide internet connectivity.

A public route table contains a default route:

```text
0.0.0.0/0 → Internet Gateway
```

## Internet Gateway and Routing

An Internet Gateway (IGW) is attached to the VPC to provide internet connectivity for resources in the public subnets.

A public route table is configured with a default route:

```text
0.0.0.0/0 → Internet Gateway
```

## Application Load Balancer

An AWS Application Load Balancer (ALB) distributes incoming HTTP traffic across the two EC2 web servers.

The ALB is deployed across both public subnets:

- `ap-south-1a` → Web Server A
- `ap-south-1b` → Web Server B

### Traffic Flow

```text
Internet
    |
    v
Application Load Balancer
    |
    +--------------------+
    |                    |
    v                    v
Web Server A         Web Server B
ap-south-1a          ap-south-1b
    |                    |
    +-------- Nginx -----+
```

### Deployment Verification

The ALB was successfully accessed through its DNS name.

Both EC2 instances reported a `healthy` status in the target group, confirming that the ALB can successfully communicate with the backend Nginx servers.

<img width="853" height="457" alt="Screenshot 2026-09-01 045115" src="https://github.com/user-attachments/assets/d30ef0b7-0dbd-4f65-ac49-fac586b46dea" />
<img width="853" height="457" alt="Screenshot 2026-09-01 045115" src="https://github.com/user-attachments/assets/9ace7c68-442d-48b9-a140-8c1db84cdd3b" />

## Testing and Verification

The deployed infrastructure was verified using the AWS Management Console, AWS CLI, and the ALB DNS endpoint.

### 1. Verify Terraform Resources

Terraform was used to verify that all expected resources were created successfully.

```bash
terraform plan
```

### 2. Verify Target Group Health

Both EC2 instances were confirmed as healthy targets.
<img width="1901" height="979" alt="image" src="https://github.com/user-attachments/assets/ad1af355-d620-45f2-b816-5d509bdc961c" />

### 3. Test the Application Load Balancer

The ALB successfully served the Nginx application.
<img width="953" height="557" alt="Screenshot 2026-09-01 045115" src="https://github.com/user-attachments/assets/376cf814-8992-47b1-886a-4ea2c87cfe08" />
<img width="953" height="551" alt="Screenshot 2026-09-01 045126" src="https://github.com/user-attachments/assets/ef6e61c7-f2d5-47cb-9c87-f16f77b963d4" />


