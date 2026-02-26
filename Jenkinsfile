pipeline {
    agent any

    environment {
        AWS_REGION = "us-east-1"
        DB_PORT    = "3306"
        IMAGE_TAG  = "${BUILD_NUMBER}"
        EKS_CLUSTER_NAME = "your-eks-cluster-name"
        DOCKER_BACKEND = "orionpax77/easycrud1-jenkins:backend-${BUILD_NUMBER}"
        DOCKER_FRONTEND = "orionpax77/easycrud1-jenkins:frontend-${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/orion-pax77/Project.git'
            }
        }

        // ================= TERRAFORM =================

        stage('Terraform Init & Apply') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        terraform -chdir=terraform init -upgrade
                        terraform -chdir=terraform validate
                        terraform -chdir=terraform apply --auto-approve
                    '''
                }
            }
        }

        stage('Fetch RDS Endpoint') {
            steps {
                script {
                    env.RDS_ENDPOINT = sh(
                        script: "terraform -chdir=terraform output -raw rds_endpoint",
                        returnStdout: true
                    ).trim()

                    echo "RDS Endpoint: ${env.RDS_ENDPOINT}"
                }
            }
        }

        // ================= DATABASE SETUP =================

        stage('Create MariaDB Database & Table') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'rds-creds',
                    usernameVariable: 'DB_USER',
                    passwordVariable: 'DB_PASS'
                )]) {

                    sh '''
                        export MYSQL_PWD="$DB_PASS"

                        mysql -h "$RDS_ENDPOINT" \
                              -P "$DB_PORT" \
                              -u "$DB_USER" <<EOF

                        CREATE DATABASE IF NOT EXISTS student_db;
                        CREATE TABLE IF NOT EXISTS student_db.students (
                            id BIGINT NOT NULL AUTO_INCREMENT,
                            name VARCHAR(255),
                            email VARCHAR(255),
                            course VARCHAR(255),
                            student_class VARCHAR(255),
                            percentage DOUBLE,
                            branch VARCHAR(255),
                            mobile_number VARCHAR(255),
                            PRIMARY KEY (id)
                        );

EOF
                    '''
                }
            }
        }

        // ================= BUILD IMAGES =================

        stage('Build Backend Image') {
            steps {
                dir('backend') {
                    sh "docker build -t $DOCKER_BACKEND . --no-cache"
                }
            }
        }

        stage('Build Frontend Image') {
            steps {
                dir('frontend') {
                    sh "docker build -t $DOCKER_FRONTEND . --no-cache"
                }
            }
        }

        stage('DockerHub Login & Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-cred',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push $DOCKER_BACKEND
                        docker push $DOCKER_FRONTEND
                        docker logout
                    '''
                }
            }
        }

        // ================= EKS CONFIG =================

        stage('Configure kubectl for EKS') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh """
                        aws eks update-kubeconfig \
                        --region $AWS_REGION \
                        --name $EKS_CLUSTER_NAME
                    """
                }
            }
        }

        // ================= KUBERNETES DEPLOY =================

        stage('Deploy Backend to Kubernetes') {
            steps {
                sh """
                    kubectl apply -f k8s/backend-deployment.yml

                    kubectl set image deployment/backend-dep \
                    backend=$DOCKER_BACKEND

                    kubectl rollout status deployment/backend-dep
                """
            }
        }

        stage('Deploy Frontend to Kubernetes') {
            steps {
                sh """
                    kubectl apply -f k8s/frontend-deployment.yml

                    kubectl set image deployment/frontend-dep \
                    frontend-pod=$DOCKER_FRONTEND

                    kubectl rollout status deployment/frontend-dep
                """
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    kubectl get pods -o wide
                    kubectl get svc
                '''
            }
        }
    }

    post {
        success {
            echo "🎉 Infra + Docker + Kubernetes Deployment Successful!"
        }
        failure {
            echo "❌ Pipeline Failed!"
        }
    }
}
