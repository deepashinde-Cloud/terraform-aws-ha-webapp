
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
