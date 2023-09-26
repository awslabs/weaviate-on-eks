## Document Process and Query with Weaviate

This repositry includes sample code that can be used to deploy and configure an instance of the Weaviate distributed vector database on EKS.

## Requirements

Ensure that your AWS account meets the following criteria:


1. Infrastructure must be deployed into us-west-2 region
2. EKS cluster deploys 3 g5.2xlarge instance types, you must have quota for this in your account

For the "samsung" workflow:
1. The language model workflows deploy 2 ml.g5.48xlarge instance types as SageMaker Endpoints,  you must have quota for this in your account
2. Your account must have access to Bedrock

## Deployment

1. Install the terraform dependencies

```bash
bash dependencies.sh
```

2. Provision resources as they are defined in the directory with the following. Note - ensure your CLI session is authenticated with AWS to provision resources.

```bash
cd weaviate
terraform init -upgrade=true
terraform plan
```


3. Review the proposed changes and then apply them.

```bash
terraform apply
```

When prompted for whether you want to deploy the resources, respond "yes"

4.  After the resources have deployed successfully, execute these commands in order to collect the external IP for the Network Load Balancer:

```bash
aws eks --region us-west-2 update-kubeconfig --name weaviate
kubectl get all -n weaviate
```

In the example below, the IP address is "k8s-weaviate-weaviate-81fdb6e0b6-99e5be031f5cd317.elb.us-west-2.amazonaws.com".  Collect this information as it will be required to connect to the Weaviate instance.

```
NAME                                         READY   STATUS    RESTARTS   AGE
pod/transformers-inference-8f6cf5c68-qbl6b   1/1     Running   0          127m
pod/weaviate-0                               1/1     Running   0          127m

NAME                             TYPE           CLUSTER-IP      EXTERNAL-IP                                                                     PORT(S)        AGE
service/transformers-inference   ClusterIP      172.20.174.46   <none>                                                                          8080/TCP       127m
service/weaviate                 LoadBalancer   172.20.208.27   k8s-weaviate-weaviate-81fdb6e0b6-99e5be031f5cd317.elb.us-west-2.amazonaws.com   80:30645/TCP   127m
service/weaviate-headless        ClusterIP      None            <none>                                                                          80/TCP         127m

NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/transformers-inference   1/1     1            1           127m

NAME                                               DESIRED   CURRENT   READY   AGE
replicaset.apps/transformers-inference-8f6cf5c68   1         1         1       127m

NAME                        READY   AGE
statefulset.apps/weaviate   1/1     127m
```

5. Navigate to SageMaker in the AWS Console and open the notebook that has been created with the name "weaviate".  There are two groups of tutorials:

wikipedia: An entry level workflow to demonstrate creating a schema, uploading data, and executing queries with the Python SDK

samsung: A more advanced workflow that includes the use of language models to populate and query the database

6.  Cleanup - tear down the infrastructure

```bash
terraform destroy
```

## TODO
- address cleanup items
- add NLP IP to env vars

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

