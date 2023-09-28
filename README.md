# Terraform AWS K3s Deployment 🚀

## Prerequisites 📋
- If you're new to SSH or wish to create a new key pair specifically for this project, run the following::
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/deployer_key
```

## AWS Credentials 🛅
- AWS User Setup: Create a user with AdministratorAccess. This is solely for testing purposes, and remember to keep your AWS credentials confidential.
- Environment Configuration: Set up your environment variables:
```
export AWS_ACCESS_KEY_ID=A...
export AWS_SECRET_ACCESS_KEY=O...
export AWS_DEFAULT_REGION=us-east-1
```


## Terraform Setup 🌱
- Hosted Zone Configuration: For optimal results with the Terraform code, configure your hosted zone ID. If you're running with a public IP only, comment out the local records code in the Terraform configurations.
- Terraform Commands: Initialize and apply Terraform configurations:
```
terraform init
terraform apply
```

## Observability
- Datadog:
```
helm repo add datadog https://helm.datadoghq.com
helm repo update
helm install datadogv1 -f observability/datadog/values.yaml --set datadog.apiKey=key datadog/datadog
helm uninstall datadogv1
```
- Optional:
```
helm plugin install https://github.com/databus23/helm-diff
helm diff upgrade datadogv1 -f observability/datadog/values.yaml --set datadog.apiKey=key datadog/datadog
```

# ⚠️ Important Safety Tips
- Cleanup: After you're done experimenting, ensure you remove the AWS user and any resources created to avoid unexpected costs. Run:
```
terraform destroy
```
- Security: Always prioritize your AWS account's security. Avoid leaving users or resources that you're no longer using.
## Wrapping Up 🎁
- Thank you for using this guide! We hope it provided a valuable learning experience. Keep exploring, stay safe, and happy coding!