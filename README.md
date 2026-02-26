# 🚀 EasyCRUD – Cloud-Native Student Registration System on AWS (EKS + RDS + Docker)
EasyCRUD is a full-stack CRUD web application deployed using modern **DevOps** and **cloud-native technologies**.  
This project demonstrates **containerization with Docker**, **Kubernetes orchestration on AWS EKS**, **managed database integration with Amazon RDS**, and a **scalable microservices architecture**.


### Deployed Using

- Docker
- AWS EKS (Kubernetes)
- AWS RDS (MariaDB)
- Kubernetes Services
- Load Balancer 

## 🛠️ Technologies Used

- **Frontend:** React  
- **Backend:** Spring Boot  
- **Database:** Amazon RDS (MariaDB)  
- **Containers:** Docker & Docker Hub  
- **Orchestration:** Kubernetes (AWS EKS)  
- **Cloud Platform:** AWS EC2, EKS, RDS  
## 📂 This Repository Contains

- ✔ Database setup on **AWS RDS**
- ✔ Backend Dockerization and deployment
- ✔ Frontend Dockerization and deployment
- ✔ Kubernetes pod and service configurations
- ✔ Complete production-ready DevOps workflow

---
## 🟢  1: Database Setup (Amazon RDS – MariaDB)

📘 Follow the complete database setup guide (**Step 1 to Step 6**) here:  
👉 [Database Setup Documentation](https://github.com/pranavmisal1002/EasyCrud-Docker#-phase-1-database-setup-amazon-rds--mariadb)

---  

## 🟢  2: Create AWS EKS Cluster

📘 Follow the complete AWS EKS cluster setup guide here:  
👉 [AWS EKS Setup Documentation](https://github.com/pranavmisal1002/AWS-EKS-Setup)

---


## 🔵 3 Backend Deployment Steps (Docker + DockerHub + EKS)

## Step 1: Install Docker

Install Docker on the EC2 instance and start the Docker service.

```bash
sudo apt install docker.io -y
sudo systemctl start docker
```

## Step 2: Clone Project Repository

Clone the EasyCRUD project repository and navigate to the backend directory.

```bash
git clone https://github.com/Rohit-1920/EasyCRUD-Updated.git
```
Move to backend directory
```bash
cd EasyCRUD/backend/
```

## Step 3: Configure Backend Application

Copy the `application.properties` file to the backend root directory and edit it.

```bash
cp src/main/resources/application.properties .
```
```bash
nano application.properties
```
### Update Configuration Values

Update the following values in the `application.properties` file:

- **RDS Endpoint**
- **Database Name:** `student_db`
- **Database Username**
- **Database Password**

```bash
server.port=8080
spring.datasource.url=jdbc:mariadb://<RDS-EndPoint>:3306/student_db
spring.datasource.username=<username>
spring.datasource.password=<password>
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
```

## Step 4: Create Dockerfile for Backend

Create a Dockerfile for the backend application.

```bash
nano Dockerfile
```
Add the following content to the Dockerfile:

```bash
FROM maven:3.8.5-openjdk-17
COPY . /opt/
WORKDIR /opt
RUN rm -rf src/main/resources/application.properties
RUN cp -r application.properties src/main/resources/
RUN mvn clean package
WORKDIR target/
CMD ["java","-jar","student-registration-backend-0.0.1-SNAPSHOT.jar"]
```
## Step 5: Build Backend Docker Image

Build the Docker image for the backend application and verify the image creation.
```bash
docker build -t <images-name>:<tag> <dockerfile-path>
```
Example :
```bash
docker build -t backend:v1 .
```
Verify Docker images
```bash
docker images
```
### Step 6: Run Backend Container Locally (Testing)

Run the backend Docker container on port `8080`:

```bash
docker run -d -p 8080:8080 backend:v1
```
Check running containers:
```bash
docker ps
```
✅ Verify backend in browser:
```bash
http://<BACKEND_EC2_PUBLIC_IP>:8080
```
> ✅ **Note:** Once the Docker image is built, rename (tag) it using the `docker tag` command before pushing it to Docker Hub.
### Tag the Docker Image for Docker Hub
**Syntax:**

```bash
docker tag <LOCAL_IMAGE_NAME>:<TAG> <DOCKERHUB_USERNAME>/<REPOSITORY_NAME>:<TAG>
```
**Example:**

```bash
docker tag backend:v1 pranavmisal1002/backend:v1
```
### Step 7: Push Backend Image to Docker Hub

Login to Docker Hub:

```bash
docker login -u <username>
```
Push the backend image to Docker Hub repository:
```bash
docker push pranavmisal1002/backend:v1
```
✅ Backend image is now available for deployment on EKS.

### ______________________________________________________________________________________________________

## ✅ Deploy Backend on EKS Kubernetes Cluster
### Step 8: Login to EKS Master / Bastion Node

Login to the EC2 instance where `kubectl` is configured (EKS access node).

Verify EKS cluster connectivity:

```bash
kubectl get nodes
```
### Step 9: Create Backend Pod YAML

Create a Kubernetes manifest file for the backend pod and Service:

```bash
nano backend-deployment.yml
```

> ✅ **Note:** Please update the image name in both `frontend-deployment.yml` and `backend-deployment.yml` according to your Docker image name and tag.

### 📄 Backend Deployment & Service Manifest (`backend-deployment.yml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-dep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      name: backend-pod
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: pranavmisal1002/backend2:v1
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
spec:
  type: LoadBalancer
  selector:
    app: backend
  ports:
    - name: lb
      protocol: TCP
      port: 8080
      targetPort: 8080
```
### Step 10: Deploy Backend Pod and Service

Create the backend pod and service:

```bash
kubectl apply -f backend-deployment.yml
```
Verify that the pod is running:
```bash
kubectl get pods -o wide
```
Verify that the service is created:
```bash
kubectl get svc
```
### Step 11: Verify Backend on EKS

Check the backend service external IP (LoadBalancer):

```bash
kubectl get svc backend-service
```
Once the EXTERNAL-IP is available, open in your browser:
```bash
http://<LOADBALANCER_EXTERNAL_IP>:8080
```
🎉 Backend pod setup on EKS is complete!

---

## 🔵 4 Frontend Deployment Steps (Docker + DockerHub + EKS)

### Step 1: Navigate to Frontend Directory

Go to the frontend project directory:

```bash
cd EasyCRUD/frontend/
```
Check hidden files such as .env:
```bash
ls -a
```
### Step 2: Edit `.env` File (Add Backend LoadBalancer URL)

Edit the frontend environment configuration file:

```bash
nano .env
```
Add the following backend API endpoint in the `.env` file:

```env
# Backend API LoadBalancer URL
REACT_APP_BACKEND_URL=http://<BACKEND_LOADBALANCER_DNS>:8080
```
## Step 3: Create Frontend Dockerfile

Create a Dockerfile for the frontend application.

```bash
nano Dockerfile
```
Add the following content to the Dockerfile:
```bash
FROM node:25-alpine
COPY . /opt/
WORKDIR /opt
RUN npm install
RUN npm run build
RUN apk update && apk add apache2
RUN cp -rf dist/* /var/www/localhost/htdocs/
EXPOSE 80
CMD ["httpd","-D","FOREGROUND"]
```
### Step 4: Build Frontend Docker Image

Build the frontend Docker image with Docker Hub tag:

```bash
docker build -t pranavmisal1002/frontend:v1 .
```
Verify Docker images:
```bash
docker images
```
### Step 5: Run Frontend Container Locally (Testing)

Run the frontend Docker container on port `80`:

```bash
docker run -d -p 80:80 pranavmisal1002/frontend:v1
```
Check running containers:
```bash
docker ps
```
✅ Verify frontend in browser:
```bash
http://<FRONTEND_EC2_PUBLIC_IP>
```
### Step 6: Push Frontend Image to Docker Hub

Login to Docker Hub:

```bash
docker login
```
Push the frontend image to Docker Hub:
```bash
docker push pranavmisal1002/frontend:v1
```
✅ Frontend image is now available for deployment on EKS.

### _________________________________________________________________________________________________
##  Deploy Frontend on EKS (Kubernetes)

### Step 7: Login to EKS Master / Bastion Node

Login to the EC2 instance where `kubectl` is configured (EKS access node).

Verify EKS cluster connectivity:

```bash
kubectl get nodes
```
### Step 8: Create Frontend Deployment and Service YAML

Create a Kubernetes manifest file for the frontend deployment and service:

```bash
nano frontend-deployment.yml
```

> ✅ **Note:** Please update the image name in both `frontend-deployment.yml` and `backend-deployment.yml` according to your Docker image name and tag.

### 📄 Frontend Deployment & Service Manifest (`frontend-deployment.yml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-dep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      name: frontend-pod
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend-pod
          image: pranavmisal1002/frontend5:v1
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: forntend-svc
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
    - name: frontend-lb
      protocol: TCP
      port: 80
      targetPort: 80
```
### Step 9: Deploy Frontend Pod and Service

Deploy the frontend application on the EKS cluster:

```bash
kubectl apply -f frontend-deployment.yml
```
Verify frontend pod status:
```bash
kubectl get pods -o wide
```
Verify frontend service creation:
```bash
kubectl get svc
```
### Step 11: Get LoadBalancer Endpoint and Verify

Retrieve the LoadBalancer external endpoint for the frontend service:

```bash
kubectl get svc frontend-service
```
Copy the LoadBalancer DNS and open in your browser:

```text
http://<FRONTEND_LOADBALANCER_DNS>
```
🎉 Your EasyCRUD application is now live on Kubernetes (AWS EKS)! ✅

---


## 📖 Project Overview

EasyCRUD is a cloud-native student registration system built using a modern DevOps workflow.  
The application is fully containerized with Docker and deployed on AWS using Kubernetes (EKS), with a managed MariaDB database hosted on Amazon RDS.

This project demonstrates real-world practices such as:
  
- Kubernetes orchestration  
- Cloud infrastructure on AWS  
- CI-style container workflows  
- LoadBalancer-based service exposure  

---


---

## 🧪 Verification Checklist

- ✅ Backend reachable via EKS LoadBalancer  
- ✅ Frontend reachable via EKS LoadBalancer  
- ✅ Database connected via RDS endpoint  
- ✅ Pods in Running state  
- ✅ Services exposed properly  

---

## 🛠️ Common Troubleshooting

### Pod not running?
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```
### Service not getting `EXTERNAL-IP`?

Wait for 2–3 minutes (AWS LoadBalancer provisioning takes time), or run:

```bash
kubectl get svc -w
```
Backend not connecting to Amazon RDS?

Check the following:

✔ Security Group inbound rules allow database access

✔ Correct RDS endpoint in application.properties file

