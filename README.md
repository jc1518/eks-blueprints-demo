# EKS Blueprints Demo

## Introduction

EKS Blueprints is a collection of Infrastructure as Code (IaC) modules that will help you configure and deploy consistent, batteries-included EKS clusters across accounts and regions. It is available in both Terraform and CDK.

- [EKS Blueprints for Terraform](https://aws-ia.github.io/terraform-aws-eks-blueprints/main/)
- [EKS Blueprints for CDK](https://aws-quickstart.github.io/cdk-eks-blueprints/)

There are 3 core concepts in EKS Blueprints which perfectly matches the design of a Shared Services Platform (SSP) for Kubernetes.

| Concept | Description                                                                                   |
| ------- | --------------------------------------------------------------------------------------------- |
| Cluster | An Amazon EKS Cluster and associated worker groups.                                           |
| Add-on  | Operational software that provides key functionality to support your Kubernetes applications. |
| Team    | A logical grouping of IAM identities that have access to Kubernetes                           |

In a typical SSP environment, the platform team is responsbile for managing the platform foundation which inclueds the Kubernetes cluster and all sorts of operational tools (normally referred as add-ons). As platform service consumers, the application teams only need to focus on their own applications without worrying about the availabitliy, security and capacity of underlying infrastructure.

![eks-blueprints](./assets/eks-blueprints.png)

## Usage

This repository is to demostrate how to quickly bootstrap a new EKS cluster by using EKS Blueprints.

- For **Terraform** lovers, please `cd terraform`.

  _*Note*: If you used EKS Blueprints for Terraform before. There are some [notables changes since V5](https://github.com/aws-ia/terraform-aws-eks-blueprints/blob/main/docs/v4-to-v5/motivation.md), you might be interested to check it out._

  - Create cluster

    ```
    terraform init
    terraform plan
    terraform apply
    ```

  - Delete cluster

    ```
    terraform destroy
    ```

- For **CDK** lovers, please `cd cdk`. (coming soon)

  - Create cluster

    ```
    cdk synth
    cdk deploy
    ```

  - Delete cluster

    ```
    cdk destroy
    ```
