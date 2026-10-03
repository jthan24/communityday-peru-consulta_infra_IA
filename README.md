Amazon EKS Infrastructure with Terraform

This repository contains the Infrastructure as Code (IaC) written in Terraform to deploy a production-ready Amazon EKS (Elastic Kubernetes Service) cluster along with all necessary networking components, security groups, IAM roles, and CloudWatch logging.

📐 Architecture Diagram

The diagram below illustrates the AWS infrastructure topology provisioned by this repository, including Multi-AZ public/private subnets, NAT Gateways, Security Groups, and EKS components.

graph TB
    subgraph Internet["🌐 Internet"]
        Users["Usuarios / Clientes"]
    end

    subgraph AWS["☁️ AWS Cloud (us-east-1)"]
        subgraph VPC["VPC (10.0.0.0/16)"]
            
            IGW["Internet Gateway (IGW)"]

            subgraph AZ1["Availability Zone 1 (us-east-1a)"]
                subgraph PubSub1["Subnet Pública 1 (10.0.0.0/24)"]
                    NAT1["NAT Gateway"]
                    ELB_Pub["Public Load Balancers\n(kubernetes.io/role/elb)"]
                end

                subgraph PrivSub1["Subnet Privada 1 (10.0.10.0/24)"]
                    Node1["Worker Node 1\n(t3.medium)"]
                    ELB_Priv["Internal Load Balancers\n(kubernetes.io/role/internal-elb)"]
                end
            end

            subgraph AZ2["Availability Zone 2 (us-east-1b)"]
                subgraph PubSub2["Subnet Pública 2 (10.0.1.0/24)"]
                    PubDummy["Subnet pública secundaria"]
                end

                subgraph PrivSub2["Subnet Privada 2 (10.0.11.0/24)"]
                    Node2["Worker Node 2\n(t3.medium)"]
                end
            end

            subgraph SG_Zone["Security Groups"]
                SG_Cluster["Cluster Security Group\n(Control Plane)"]
                SG_Nodes["Node Security Group\n(Worker Nodes)"]
            end

            subgraph EKS_CP["EKS Managed Control Plane"]
                EKS_API["EKS API Endpoint\n(Kubernetes Control Plane)"]
            end

        end

        subgraph CloudWatch["CloudWatch Logs"]
            LogGroup["/aws/eks/my-eks-cluster/cluster\n(Retention: 30 days)"]
        end
    end

    %% Conexiones
    Users --> IGW
    IGW <--> PubSub1
    IGW <--> PubSub2

    NAT1 --> IGW
    Node1 -- "Egresos a Internet" --> NAT1
    Node2 -- "Egresos a Internet" --> NAT1

    EKS_API <--> SG_Cluster
    SG_Cluster <-->|TLS 443 / Ports 1025-65535| SG_Nodes
    SG_Nodes <--> Node1
    SG_Nodes <--> Node2

    Node1 <--> Node2

    EKS_CP -- "Control Plane Logs" --> LogGroup


🛠️ Components Included

VPC & Networking:

1 Custom VPC (10.0.0.0/16).

2 Public Subnets (across 2 Availability Zones).

2 Private Subnets (across 2 Availability Zones for Worker Nodes).

Internet Gateway (IGW) for public connectivity.

Elastic IP (EIP) & NAT Gateway for outbound connectivity from private subnets.

Public and Private Route Tables.

Standard Kubernetes tags on subnets for auto-discovery of public and internal Elastic Load Balancers (ELB).

Security Groups:

Cluster SG: Controls traffic to and from the EKS Control Plane.

Node SG: Manages intra-node communication and Control Plane access.

IAM Roles & Policies:

EKS Cluster Role: Grants permissions for the control plane to manage AWS resources.

EKS Node Group Role: Provides permissions for worker nodes (AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy, AmazonEC2ContainerRegistryReadOnly).

Observability & Logging:

AWS CloudWatch Log Group: Dedicated log group /aws/eks/my-eks-cluster/cluster with 30-day retention for EKS control plane logs (api, audit, authenticator, controllerManager, scheduler).

Compute & Orchestration:

Amazon EKS Cluster (Control Plane).

EKS Managed Node Group running in private subnets with autoscaling enabled (min: 1, desired: 2, max: 4).

📋 Prerequisites

Before deploying, ensure you have the following installed and configured on your machine:

Terraform >= 1.5.0

AWS CLI configured with valid credentials (aws configure)

kubectl for interacting with the EKS cluster

🚀 Deployment Instructions

1. Clone the Repository & Initialize Terraform

Initialize the working directory to download the required AWS provider plugins:

terraform init


2. Review Execution Plan

Inspect the resources that Terraform will create in your AWS account:

terraform plan


3. Apply Infrastructure

Provision all infrastructure resources:

terraform apply


Note: EKS cluster provision usually takes 8–15 minutes. Confirm the action by typing yes when prompted.

🔌 Connecting to the EKS Cluster

Once Terraform completes execution, configure your local kubectl context using the output EKS cluster name and region:

aws eks update-kubeconfig --region us-east-1 --name my-eks-cluster


Verify connection to the cluster:

kubectl get nodes


Expected output should display the worker nodes in Ready status:

NAME                                         STATUS   ROLES    AGE     VERSION
ip-10-0-10-x.ec2.internal                    Ready    <none>   2m      v1.28.x
ip-10-0-11-x.ec2.internal                    Ready    <none>   2m      v1.28.x


🧹 Destroy Infrastructure

To clean up and destroy all resources created by Terraform to avoid unnecessary costs:

terraform destroy


Confirm the destruction by entering yes when prompted.



aws eks list-clusters
aws eks update-kubeconfig --name community-day-peru --kubeconfig kubeconfig --alias community-day-peru
export KUBECONFIG=$PWD/kubeconfig
kubectl get pods -A 



kubectl run pg-psql -i --tty --image=postgres:15.17 --restart=Never --env="PGPASSWORD=ChangeMeInProduction123!" -- psql -h community-day-peru-db.cvkciuqukkf9.us-west-2.rds.amazonaws.com -U appdb -c "\l" 2>&1

kubectl run pg-psql-allowed -i --tty --image=postgres:15.17 --restart=Never --env="PGPASSWORD=ChangeMeInProduction123!" -- psql -h community-day-peru-db.cvkciuqukkf9.us-west-2.rds.amazonaws.com -U appdb -c "\l" 2>&1
