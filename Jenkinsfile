
pipeline {
    agent any

    environment {
        AWS_REGION = "us-east-1"
        DB_PORT    = "3306"
        IMAGE_TAG  = "latest"
    }

    stages {

        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/orion-pax77/Project.git'
            }
        }

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

        stage('Build Backend Image') {
            steps {
                dir('backend') {
                    sh 'docker build -t orionpax77/easycrud1-jenkins:backend . --no-cache'
                }
            }
        }

        stage('Run Backend Container') {
            steps {
                sh '''
                    docker rm -f easycrud1-backend || true
                    docker run -d \
                        --name easycrud1-backend \
                        -p 8080:8080 \
                        orionpax77/easycrud1-jenkins:backend
                '''
            }
        }

        //  NEW AUTOMATED EC2 IP FETCH
        stage('Fetch EC2 Public IP') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    script {
                        env.EC2_PUBLIC_IP = sh(
                            script: """
                                aws ec2 describe-instances \
                                --region ${AWS_REGION} \
                                --filters Name=instance-state-name,Values=running \
                                --query "Reservations[].Instances[?PublicIpAddress!=null].PublicIpAddress" \
                                --output text | head -n 1
                            """,
                            returnStdout: true
                        ).trim()

                        if (!env.EC2_PUBLIC_IP) {
                            error "No running EC2 instance with Public IP found!"
                        }

                        echo "EC2 Public IP: ${env.EC2_PUBLIC_IP}"
                    }
                }
            }
        }

        stage('Update Frontend .env File') {
            steps {
                sh """
                    if [ -f frontend/.env ]; then
                        sed -i 's|VITE_API_URL=.*|VITE_API_URL=http://${EC2_PUBLIC_IP}:8080/api|' frontend/.env
                    else
                        echo ".env file not found!"
                        exit 1
                    fi
                """
            }
        }

        stage('Build Frontend Image') {
            steps {
                dir('frontend') {
                    sh 'docker build -t orionpax77/easycrud1-jenkins:frontend . --no-cache'
                }
            }
        }

        stage('Run Frontend Container') {
            steps {
                sh '''
                    docker rm -f easycrud1-frontend || true
                    docker run -d \
                        --name easycrud1-frontend \
                        -p 80:80 \
                        orionpax77/easycrud1-jenkins:frontend
                '''
            }
        }

        stage('Docker Hub Login & Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-cred',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push orionpax77/easycrud1-jenkins:backend
                        docker push orionpax77/easycrud1-jenkins:frontend
                        docker logout
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ Full Infra + Deployment Successful!"
        }
        failure {
            echo "❌ Pipeline Failed!"
        }
    }
}
