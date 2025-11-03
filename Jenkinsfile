pipeline {
    agent any

    // These variables will be used in the stages
    environment {
        // ---!!! YOU MUST EDIT THESE VALUES !!!---
        AWS_ACCOUNT_ID    = "YOUR_AWS_ACCOUNT_ID"       // Find this in your AWS console
        AWS_REGION        = "us-east-1"                 // The region for your ECR/EC2
        ECR_REPO_NAME     = "my-web-app"                // The ECR repo name you will create
        TARGET_EC2_IP     = "YOUR_TARGET_EC2_PUBLIC_IP" // The IP of your deployment server
        TARGET_EC2_USER   = "ubuntu"                    // We are using an Ubuntu server
        // ---!!! -----------------------------!!!---

        // These are calculated automatically
        ECR_REPO_URL      = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_NAME        = "${ECR_REPO_NAME}:${env.BUILD_NUMBER}"
        IMAGE_NAME_LATEST = "${ECR_REPO_NAME}:latest"
    }

    stages {
        stage('1. Checkout Code') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
            }
        }

        stage('2. Build Application') {
            steps {
                echo 'Installing Node.js dependencies...'
                sh 'npm install'
            }
        }

        stage('3. Run Tests') {
            steps {
                echo 'Running tests...'
                sh 'npm test'
            }
        }

        stage('4. Build Docker Image') {
            steps {
                echo "Building Docker image: ${IMAGE_NAME}"
                sh "docker build -t ${IMAGE_NAME} ."
                sh "docker tag ${IMAGE_NAME} ${IMAGE_NAME_LATEST}"
            }
        }

        stage('5. Push to AWS ECR') {
            steps {
                echo 'Logging in to AWS ECR...'
                // Jenkins uses its attached IAM Role for credentials
                sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URL}"

                echo "Pushing image ${ECR_REPO_URL}/${IMAGE_NAME}..."
                sh "docker tag ${IMAGE_NAME} ${ECR_REPO_URL}/${IMAGE_NAME}"
                sh "docker push ${ECR_REPO_URL}/${IMAGE_NAME}"

                echo "Pushing image ${ECR_REPO_URL}/${IMAGE_NAME_LATEST}..."
                sh "docker tag ${IMAGE_NAME_LATEST} ${ECR_REPO_URL}/${IMAGE_NAME_LATEST}"
                sh "docker push ${ECR_REPO_URL}/${IMAGE_NAME_LATEST}"
            }
        }

        stage('6. Deploy to EC2') {
            steps {
                echo "Deploying application to ${TARGET_EC2_IP}..."
                // 'target-ec2-ssh' is the Credential ID we will create in Jenkins
                sshagent(credentials: ['target-ec2-ssh']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${TARGET_EC2_USER}@${TARGET_EC2_IP} '

                            # Log in to ECR on the target machine (uses its own IAM Role)
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URL}

                            # Stop and remove the old container, if it exists
                            docker stop my-web-app || true
                            docker rm my-web-app || true

                            # Pull the new 'latest' image from ECR
                            docker pull ${ECR_REPO_URL}/${IMAGE_NAME_LATEST}

                            # Run the new container, mapping port 80 (public) to 8080 (app)
                            docker run -d -p 80:8080 --name my-web-app ${ECR_REPO_URL}/${IMAGE_NAME_LATEST}
                        '
                    """
                }
            }
        }
    }

    // This block runs after all stages
    post {
        always {
            echo 'Cleaning up the Jenkins workspace...'
            // Removes the built docker images from the Jenkins server to save space
            sh "docker rmi ${IMAGE_NAME} || true"
            sh "docker rmi ${IMAGE_NAME_LATEST} || true"
        }
        success {
            // You can configure the 'Mailer' plugin to send an email
            echo "Pipeline Succeeded! App is live at http://${TARGET_EC2_IP}"
        }
        failure {
            echo 'Pipeline Failed.'
        }
    }
}