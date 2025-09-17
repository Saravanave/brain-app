# React Brain App Deployment on AWS EKS with CI/CD

This project demonstrates a robust Continuous Integration and Continuous Delivery (CI/CD) pipeline for deploying a React application to an Amazon Elastic Kubernetes Service (EKS) cluster using AWS CodePipeline, CodeBuild, and ECR.

## Project Overview

The goal of this project is to automate the build, containerization, and deployment of a React application.

**Key Components & Technologies Used:**

  * **Application:** React JS (Vite-based)
  * **Containerization:** Docker
  * **Container Registry:** AWS Elastic Container Registry (ECR)
  * **Orchestration:** Kubernetes on AWS Elastic Kubernetes Service (EKS)
  * **CI/CD Pipeline:** AWS CodePipeline
      * **Source:** GitHub
      * **Build:** AWS CodeBuild (Builds Docker image, pushes to ECR, prepares Kubernetes manifests)
      * **Deploy:** AWS CodePipeline's native EKS deployment action
  * **Monitoring:** AWS CloudWatch Logs

## Project Structure

Your repository should have the following core files at its root:

```
React_Brain_App_Deployment/
├── Dockerfile                  # Defines the Docker image for the React app
├── buildspec.yml               # CodeBuild instructions for CI
├── deployment.yaml             # Kubernetes Deployment manifest
├── service.yaml                # Kubernetes Service (LoadBalancer) manifest
├── appspec.yml
|── React project folder (here it is dist)
└── ... (other React source files like src/, vite.config.js, etc.)
```

## Setup & Deployment Guide

Follow these steps to set up and deploy your React application.

### Step 1: Prepare Your Application Files

Ensure the following files are present at the root of your `Brain_App_Deployment` GitHub repository:

1.  **`Dockerfile`**: Defines the multi-stage Docker build for your React application.

    ```dockerfile
    # Use the official NGINX image
    FROM nginx:alpine

    # Copy static site to NGINX public directory
    COPY dist/ /usr/share/nginx/html

    # Expose port 80
    EXPOSE 80

    # Start NGINX
    CMD ["nginx", "-g", "daemon off;"]

    ```

2.  **`deployment.yaml`**: Kubernetes manifest for your application's deployment. Replace `913524942450.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks-app` with your ECR URI. The `image` field will be updated by CodePipeline.

   ```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: brain-tasks-app
  labels:
    app: brain-tasks-app
spec:
  replicas: 2 # You can adjust the number of replicas
  selector:
    matchLabels:
      app: brain-tasks-app
  template:
    metadata:
      labels:
        app: brain-tasks-app
    spec:
      containers:
      - name: brain-tasks-container
        image: 913524942450.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks-app:latest
        ports:
        - containerPort: 80
      imagePullSecrets:
      - name: ecr-secret
 ```

3.  **`service.yaml`**: Kubernetes manifest to expose your application via an AWS LoadBalancer.

   ```yaml
    apiVersion: v1
kind: Service
metadata:
  name: brain-tasks-service
  labels:
    app: brain-tasks-app # Ensure this matches your deployment's app label
spec:
  type: LoadBalancer
  selector:
    app: brain-tasks-app # Selects pods with this label
  ports:
  - protocol: TCP
    port: 80 # Service port
    targetPort: 80 # Container port
   ```

4.  **`buildspec.yml`**: Instructions for AWS CodeBuild to build, containerize, and prepare deployment artifacts.

   ```yaml
    version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 913524942450.dkr.ecr.ap-south-1.amazonaws.com
  build:
    commands:
      - echo Building Docker image...
      - docker build -t brain-tasks-app .
      - docker tag brain-tasks-app:latest 913524942450.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks-app:latest
  post_build:
    commands:
      - echo Pushing Docker image to ECR...
      - docker push 218451864494.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks-app:latest
      - echo Writing image definitions...
      - printf '[{"name":"brain-tasks-container","imageUri":"913524942450.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks-app:latest"}]' > imagedefinitions.json
artifacts:
  files:
    - appspec.yml
    - deployment.yaml
    - service.yaml
    - imagedefinitions.json
   ```


4.  **`appspec.yml`**:
 ```yaml
version: 0.0
# This is for a CodeDeploy deployment type 'ECS', but we're leveraging its hooks for EKS
# Resource property values are placeholders as CodeDeploy doesn't directly manage EKS resources
# Instead, we use a script in the hooks to run kubectl commands.
Resources:
  - myApp:
      Type: AWS::ECS::Service # Placeholder, CodeDeploy doesn't have an EKS resource type
      Properties:
        TaskDefinition: "arn:aws:ecs:ap-south-1:913524942450:task-definition/dummy:1" # Dummy ARN
        LoadBalancerInfo:
          ContainerName: "brain-tasks-container" # Must match container name in imagedefinitions.json
          ContainerPort: 80 # Must match container port in imagedefinitions.json
Hooks:
  AfterInstall:
    - location: scripts/deploy_to_eks.sh
      timeout: 300
      runas: root
```
**Commit these files to the root of your GitHub repository.**

### Step 2: Set up AWS CodePipeline

1.  **Navigate to CodePipeline:** Open the AWS CodePipeline console.
2.  **Create Pipeline:** Click "Create pipeline".
      * **Pipeline Settings:**
          * **Pipeline name:** `BrainTasksAppPipeline`
          * **Service role:** Select `New service role`. (Automatically creates an IAM role).
          * **Artifact store:** `Default location`.
          * Click `Next`.
      * **Source Stage:**
          * **Source provider:** `GitHub (Version 2)`
          * **Connection:** Set up or choose your GitHub connection.
          * **Repository name:** Select your repository (`brain-app`).
          * **Branch name:** `main` (or your relevant branch).
          * Click `Next`.
      * **Build Stage:**
          * **Build provider:** `AWS CodeBuild`.
          * **Region:** Your AWS region (e.g., `ap-south-1`).
          * **Project name:** Click `Create project`.
              * **Project name:** `brain-tasks-app-build`
              * **Environment image:** `Managed image` -\> `Amazon Linux 2` -\> `Standard` -\> Latest image version.
              * **Service role:** `New service role`.
              * **Buildspec:** `Use a buildspec file` (CodeBuild will automatically use `buildspec.yml`).
              * Click `Continue to CodePipeline`.
          * Ensure the `brain-tasks-app-build` project is selected.
          * Click `Next`.
      * **Deploy Stage:**
          * **Deploy provider:** `Amazon EKS`.
          * **Region:** Your AWS region (e.g., `ap-south-1`).
          * **Cluster name:** Select your EKS cluster (e.g., `brain-app-cluster`).
          * **Namespace:** `default` (or your target Kubernetes namespace).
          * **Deployment file:** `deployment.yaml`
          * **Service file:** `service.yaml`
          * **Image definitions file:** `imagedefinitions.json`
          * Click `Next`.
      * **Review:** Review all configurations and click `Create pipeline`.

### Step 3: Grant EKS Permissions to CodePipeline's Service Role

The CodePipeline role needs explicit permissions to interact with your EKS cluster.

1.  **Get CodePipeline Service Role ARN:**
      * Go to the AWS IAM console -\> Roles.
      * Find the role named `AWSCodePipelineServiceRole-<your-pipeline-name>-<region>` (e.g., `AWSCodePipelineServiceRole-ap-south-1-BrainTasksAppPipeline`).
      * **Copy its ARN.**
2.  **Add EKS Access Entry:**
      * Go to the AWS EKS console -\> Clusters -\> Select your cluster (e.g., `brain-app-cluster`).
      * Navigate to the **"Access"** tab -\> **"Access entries"** -\> **"Create access entry"**.
      * **Step 1: Configure IAM access entry:**
          * **IAM principal ARN:** Paste the CodePipeline service role ARN.
          * **Type:** `Standard`.
          * **Groups - Optional:** **Leave this field BLANK.**
          * Click `Next`.
      * **Step 2: Add access policy:**
          * **Policy to associate:** Select `AmazonEKSClusterAdminPolicy`.
          * **Access scope:** `Cluster`.
          * Click `Add policy`.
          * Click `Next`.
      * **Step 3: Review and create:** Review details and click `Create access entry`.

### Step 4: Verify Deployment

1.  **Monitor Pipeline:** After creation, the pipeline will run automatically. Confirm all stages complete successfully.
2.  **Verify Kubernetes Resources:**
      * Ensure `kubectl` is configured to your EKS cluster:
        ```bash
        aws eks update-kubeconfig --region ap-south-1 --name brain-app-cluster
        ```
      * Check your application's deployment status:
        ```bash
        kubectl get deployments -n default brain-tasks-app
        ```
      * Retrieve your LoadBalancer service details and external URL:
        ```bash
        kubectl get services -n default brain-tasks-service
        ```
        The `EXTERNAL-IP` column will show the LoadBalancer's DNS name.
      * Check pod status:
        ```bash
        kubectl get pods -n default -l app=brain-tasks-app
        ```
3.  **Access Application:** Paste the LoadBalancer's `EXTERNAL-IP` (DNS name) into your web browser. Your React application should now be live.

### Monitoring with CloudWatch Logs

  * **CodeBuild Logs:** To view build and push logs, go to the CodeBuild console, select your `brain-tasks-app-build` project, and navigate to "Build history" to view logs for specific builds.
  * **EKS/Application Logs:** Your EKS cluster integrates with CloudWatch Logs.
      * Go to the CloudWatch console.
      * Under "Logs", click "Log groups".
      * You'll find log groups related to your EKS cluster (e.g., `/aws/eks/brain-app-cluster/cluster`, `/aws/containerinsights/brain-app-cluster/application`). Explore these to see EKS control plane logs and your application container logs.

### Application Load Balancer ARN

To find the ARN of the Kubernetes LoadBalancer created for `brain-tasks-service`:

1.  Get the LoadBalancer DNS name from `kubectl get services -n default brain-tasks-service` (the `EXTERNAL-IP`).
2.  Go to the AWS EC2 console -\> Load Balancers.
3.  Find the Load Balancer with the matching DNS name.
4.  In the Load Balancer's details tab, you will find its ARN.

-----

### For more reference please view document file 
<href> https://github.com/ </href>
