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

                        CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY '$DB_PASS';

                        GRANT ALL PRIVILEGES ON student_db.* TO 'admin'@'%';

                        FLUSH PRIVILEGES;

                        USE student_db;

                        CREATE TABLE IF NOT EXISTS students (
                            id BIGINT NOT NULL AUTO_INCREMENT,
                            name VARCHAR(255) DEFAULT NULL,
                            email VARCHAR(255) DEFAULT NULL,
                            course VARCHAR(255) DEFAULT NULL,
                            student_class VARCHAR(255) DEFAULT NULL,
                            percentage DOUBLE DEFAULT NULL,
                            branch VARCHAR(255) DEFAULT NULL,
                            mobile_number VARCHAR(255) DEFAULT NULL,
                            PRIMARY KEY (id)
                        );

EOF
                    '''
                }
            }
        }

        // ================= UPDATE application.properties =================

        stage('Update application.properties') {
            steps {
                sh """
                    sed -i 's|spring.datasource.url=.*|spring.datasource.url=jdbc:mariadb://${RDS_ENDPOINT}:${DB_PORT}/student_db?sslMode=trust|' backend/src/main/resources/application.properties
                    sed -i 's|spring.datasource.username=.*|spring.datasource.username=admin|' backend/src/main/resources/application.properties
                    sed -i 's|spring.datasource.password=.*|spring.datasource.password=redhat123|' backend/src/main/resources/application.properties
                    sed -i 's|spring.jpa.hibernate.ddl-auto=.*|spring.jpa.hibernate.ddl-auto=update|' backend/src/main/resources/application.properties
                    sed -i 's|spring.jpa.show-sql=.*|spring.jpa.show-sql=true|' backend/src/main/resources/application.properties
                    sed -i 's|spring.datasource.driver-class-name=.*|spring.datasource.driver-class-name=org.mariadb.jdbc.Driver|' backend/src/main/resources/application.properties
                """
            }
        }

        // ================= BUILD BACKEND =================

        stage('Build Backend Image') {
            steps {
                dir('backend') {
                    sh "docker build -t $DOCKER_BACKEND . --no-cache"
                }
            }
        }

        stage('Push Backend Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-cred',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push $DOCKER_BACKEND
                        docker logout
                    '''
                }
            }
        }

        // ================= DEPLOY BACKEND =================

        stage('Deploy Backend & Fetch LB') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {

                    script {
                        sh """
                            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                            export AWS_DEFAULT_REGION=${AWS_REGION}

                            aws eks update-kubeconfig \
                                --region ${AWS_REGION} \
                                --name ${EKS_CLUSTER_NAME}

                            kubectl apply -f k8s/backend-deployment.yml
                            kubectl set image deployment/backend-dep backend=${DOCKER_BACKEND}
                            kubectl rollout status deployment/backend-dep
                        """

                        echo "Waiting for Backend LoadBalancer..."
                        sleep 30

                        env.BACKEND_LB = sh(
                            script: """
                                kubectl get svc backend-svc \
                                -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
                            """,
                            returnStdout: true
                        ).trim()

                        echo "Backend LoadBalancer DNS: ${env.BACKEND_LB}"
                    }
                }
            }
        }

        // ================= UPDATE FRONTEND .env =================

        stage('Update Frontend .env') {
            steps {
                sh """
                    sed -i 's|REACT_APP_BACKEND_URL=.*|REACT_APP_BACKEND_URL=http://${BACKEND_LB}:8080|' frontend/.env
                """
            }
        }

        // ================= BUILD FRONTEND =================

        stage('Build Frontend Image') {
            steps {
                dir('frontend') {
                    sh "docker build -t $DOCKER_FRONTEND . --no-cache"
                }
            }
        }

        stage('Push Frontend Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-cred',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push $DOCKER_FRONTEND
                        docker logout
                    '''
                }
            }
        }

        // ================= DEPLOY FRONTEND =================

        stage('Deploy Frontend to EKS') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {

                    sh """
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                        export AWS_DEFAULT_REGION=${AWS_REGION}

                        kubectl apply -f k8s/frontend-deployment.yml
                        kubectl set image deployment/frontend-dep frontend-pod=${DOCKER_FRONTEND}
                        kubectl rollout status deployment/frontend-dep

                        kubectl get pods
                        kubectl get svc
                    """
                }
            }
        }
    }

    post {
        success {
            echo "🎉 Full CI/CD Pipeline Successful on example-eks-cluster!"
        }
        failure {
            echo "❌ Pipeline Failed!"
        }
    }
}
