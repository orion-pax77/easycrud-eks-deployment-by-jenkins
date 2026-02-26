pipeline {
    agent any

    environment {
        AWS_REGION = "us-east-1"
        DB_PORT    = "3306"
        IMAGE_TAG  = "${BUILD_NUMBER}"
        EKS_CLUSTER_NAME = "example-eks-cluster"

        DOCKER_BACKEND  = "orionpax77/easycrud1-jenkins:backend-${BUILD_NUMBER}"
        DOCKER_FRONTEND = "orionpax77/easycrud1-jenkins:frontend-${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout Code') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/orion-pax77/Project.git'
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

        // ================= UPDATE application.properties =================

        stage('Update application.properties') {
            steps {
                sh """
                    if [ -f backend/src/main/resources/application.properties ]; then
                        sed -i 's|spring.datasource.url=.*|spring.datasource.url=jdbc:mariadb://${RDS_ENDPOINT}:${DB_PORT}/student_db?sslMode=trust|' backend/src/main/resources/application.properties
                        sed -i 's|spring.datasource.username=.*|spring.datasource.username=admin|' backend/src/main/resources/application.properties
                        sed -i 's|spring.datasource.password=.*|spring.datasource.password=redhat123|' backend/src/main/resources/application.properties
                        sed -i 's|spring.jpa.hibernate.ddl-auto=.*|spring.jpa.hibernate.ddl-auto=update|' backend/src/main/resources/application.properties
                        sed -i 's|spring.jpa.show-sql=.*|spring.jpa.show-sql=true|' backend/src/main/resources/application.properties
                        sed -i 's|spring.datasource.driver-class-name=.*|spring.datasource.driver-class-name=org.mariadb.jdbc.Driver|' backend/src/main/resources/application.properties
                    else
                        echo "application.properties not found!"
                        exit 1
                    fi
                """
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

        // ================= CONFIGURE EKS =================

       stage('Configure kubectl for EKS') {
    steps {
        withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws-creds',
            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {

            sh """
                export AWS_DEFAULT_REGION=${AWS_REGION}

                aws eks update-kubeconfig \
                --region ${AWS_REGION} \
                --name example-eks-cluster

                kubectl get nodes
            """
        }
    }
}

        // ================= DEPLOY BACKEND =================

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

        // ================= DEPLOY FRONTEND =================

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
            echo "🎉 Successfully deployed to EKS cluster: example-eks-cluster"
        }
        failure {
            echo "❌ Pipeline Failed!"
        }
    }
}
