# Opsfleet EKS

Configuration in this directory creates an AWS EKS cluster with [Karpenter](https://karpenter.sh/) provisioned for managing compute resource scaling. In the example provided, Karpenter is provisioned on top of an EKS Managed Node Group.

Note: This configuration allows you to deploy the cluster with all the basic functionalities, with karpenter handling autoscaling, node provisioning etcetera. More granular configurations such as network segregation, rbac, etc will require more configurations.

## Usage

To provision the provided configurations you need to execute:

```bash
$ terraform init
$ terraform plan
$ terraform apply --auto-approve
```

However, the above commands have been automated using a Github Actions Pipeline. Follow the steps below to run the pipeline

```bash
- create and environment on github actions called "dev"
- on the environment, create secrets for your required credentials, in this case the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
- create variables for your other parameters such as the backend configuration
- once done, head to "actions", the pipeline is created for a workflow_dispatch meaning you have to manually trigger this, it is designed to allow you choose the environment to deploy to, which in turn chooses the appropriate .tfvars containing your environment's values and run pipeline.

```

Once the cluster is up and running, you can check that Karpenter is functioning as intended with the following command:

```bash
# First, make sure you have updated your local kubeconfig
aws eks --region eu-west-1 update-kubeconfig --name ex-karpenter
```

Also ensure that the role karpenter uses, has the necessary permissions to request spot instances AmazonEC2SpotFleetTaggingRole

```bash
# Second, deploy the Karpenter NodeClass/NodePool
kubectl apply -f karpenter.yaml

# Second, deploy the example deployment
kubectl apply -f inflate.yaml
kubectl apply -f postgres.yaml

# You can watch Karpenter's controller logs with
kubectl logs -f -n kube-system -l app.kubernetes.io/name=karpenter -c controller
```

- The above is only required if you prefer to run commands directly on the cluster, however, the current configration runs all these automatically via terraform.

NOTE: since the manifests are dependent on the cluster being up and running on "main.tf" in the root folder line 117-135 is commented out. Once the pipeline runs and cluster is fully healthy you can uncomment and rerun pipeline

Validate if the Amazon EKS Addons Pods are running in the Managed Node Group and the `inflate` and `postgres` application Pods are running on Karpenter provisioned Nodes.

```bash
kubectl get nodes -L karpenter.sh/registered
```

```text
NAME                                        STATUS   ROLES    AGE   VERSION               REGISTERED
ip-10-0-12-155.eu-west-1.compute.internal   Ready    <none>   9m26s   v1.33.1-eks-f5be8fb   true
ip-10-0-47-204.eu-west-1.compute.internal   Ready    <none>   94m     v1.33.3-eks-3abbec1   
ip-10-0-5-134.eu-west-1.compute.internal    Ready    <none>   94m     v1.33.3-eks-3abbec1
```

```sh
kubectl get pods -A -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```

```text
NAME                           NODE
inflate-7b4df768d6-d4w4r       ip-10-0-47-204.eu-west-1.compute.internal
inflate-7b4df768d6-l4p6f       ip-10-0-12-155.eu-west-1.compute.internal
inflate-7b4df768d6-sjc49       ip-10-0-5-134.eu-west-1.compute.internal
postgres-6b579788c4-6vx7m      ip-10-0-47-204.eu-west-1.compute.internal
postgres-6b579788c4-l6wjf      ip-10-0-47-204.eu-west-1.compute.internal
postgres-6b579788c4-nm4pr      ip-10-0-5-134.eu-west-1.compute.internal
aws-node-jhnm7                 ip-10-0-12-155.eu-west-1.compute.internal
aws-node-jvmmj                 ip-10-0-47-204.eu-west-1.compute.internal
aws-node-xdwxt                 ip-10-0-5-134.eu-west-1.compute.internal
coredns-6c6d59c954-4gh8z       ip-10-0-5-134.eu-west-1.compute.internal
coredns-6c6d59c954-66xjl       ip-10-0-47-204.eu-west-1.compute.internal
eks-pod-identity-agent-7sb64   ip-10-0-47-204.eu-west-1.compute.internal
eks-pod-identity-agent-md4zd   ip-10-0-5-134.eu-west-1.compute.internal
eks-pod-identity-agent-zjslr   ip-10-0-12-155.eu-west-1.compute.internal
karpenter-6f8db6ddc-474fj      ip-10-0-5-134.eu-west-1.compute.internal
karpenter-6f8db6ddc-79tjp      ip-10-0-47-204.eu-west-1.compute.internal
kube-proxy-kmq6z               ip-10-0-5-134.eu-west-1.compute.internal
kube-proxy-n4blb               ip-10-0-47-204.eu-west-1.compute.internal
kube-proxy-xchg4               ip-10-0-12-155.eu-west-1.compute.internal
```

### Tear Down & Clean-Up

Because Karpenter manages the state of node resources outside of Terraform, Karpenter created resources will need to be de-provisioned first before removing the remaining resources with Terraform.

1. Remove the example deployment created above and any nodes created by Karpenter

```bash
kubectl delete deployment inflate
kubectl delete deployment postgres
```

2. DELETE NODES AND NODEGROUPS CREATED BY KARPENTER

3. Remove the resources created by Terraform

```bash
- another pipeline "Infra - Terraform Destroy" has been created for Infra Destroy purposes
- on actions, click on the pipeline, choose the environmet and check the "Run infrastructure deployment actions" box and run. This would destroy your created resources.
```

Note that this example may create resources which cost money. Run `terraform destroy` when you don't need these resources.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.9 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.9 |
| <a name="provider_aws.virginia"></a> [aws.virginia](#provider\_aws.virginia) | >= 6.9 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | ../.. | n/a |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | ../../modules/karpenter | n/a |
| <a name="module_karpenter_disabled"></a> [karpenter\_disabled](#module\_karpenter\_disabled) | ../../modules/karpenter | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 6.0 |

## Resources

| Name | Type |
|------|------|
| [helm_release.karpenter](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_ecrpublic_authorization_token.token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecrpublic_authorization_token) | data source |

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->
