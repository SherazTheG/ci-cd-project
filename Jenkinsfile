pipeline {
    agent any
    
    tools {
        nodejs 'NodeJS-20'
    }
    
    environment {
        GCP_PROJECT_ID = 'artisan-project-472013'  // Replace with your GCP project ID
        GCP_REGION = 'us-central1'  // Replace with your region
        ARTIFACT_REGISTRY = "${GCP_REGION}-docker.pkg.dev"
        REPOSITORY_NAME = 'devops-cia2-repo-sheraz'
        IMAGE_NAME = 'devops-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        FULL_IMAGE_PATH = "${ARTIFACT_REGISTRY}/${GCP_PROJECT_ID}/${REPOSITORY_NAME}/${IMAGE_NAME}"
        CONTAINER_NAME = 'devops-app'
        APP_PORT = '80'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '========== Cloning Repository =========='
                checkout scm
            }
        }
        
        stage('Install Dependencies') {
            steps {
                echo '========== Installing npm dependencies =========='
                sh '''
                    node --version
                    npm --version
                    npm install
                '''
            }
        }
        
        stage('Code Quality Analysis - ESLint') {
            steps {
                echo '========== Running ESLint =========='
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    sh 'npm run lint'
                }
            }
        }
        
        stage('Build Application') {
            steps {
                echo '========== Building React application =========='
                sh 'npm run build'
            }
        }
        
        stage('Run Tests') {
            steps {
                echo '========== Running Tests =========='
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    sh 'npm test'
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo '========== Building Docker Image =========='
                script {
                    sh """
                        docker build -t ${FULL_IMAGE_PATH}:${IMAGE_TAG} .
                        docker tag ${FULL_IMAGE_PATH}:${IMAGE_TAG} ${FULL_IMAGE_PATH}:latest
                    """
                }
            }
        }
        
        stage('Push to Artifact Registry') {
            steps {
                echo '========== Pushing Docker Image to GCP Artifact Registry =========='
                script {
                    withCredentials([file(credentialsId: 'gcp-service-account', variable: 'GCP_KEY_FILE')]) {
                        sh """
                            # Authenticate with GCP
                            gcloud auth activate-service-account --key-file=\${GCP_KEY_FILE}
                            gcloud config set project ${GCP_PROJECT_ID}
                            
                            # Configure Docker to use gcloud as credential helper
                            gcloud auth configure-docker ${ARTIFACT_REGISTRY} --quiet
                            
                            # Push images
                            docker push ${FULL_IMAGE_PATH}:${IMAGE_TAG}
                            docker push ${FULL_IMAGE_PATH}:latest
                            
                            echo "✅ Successfully pushed image to Artifact Registry"
                        """
                    }
                }
            }
        }
        
        stage('Deploy Locally') {
            steps {
                echo '========== Deploying Container on Same Server =========='
                script {
                    withCredentials([file(credentialsId: 'gcp-service-account', variable: 'GCP_KEY_FILE')]) {
                        sh """
                            # Authenticate with GCP (for pulling from Artifact Registry)
                            gcloud auth activate-service-account --key-file=\${GCP_KEY_FILE}
                            gcloud config set project ${GCP_PROJECT_ID}
                            gcloud auth configure-docker ${ARTIFACT_REGISTRY} --quiet
                            
                            # Stop and remove old container if exists
                            docker stop ${CONTAINER_NAME} 2>/dev/null || true
                            docker rm ${CONTAINER_NAME} 2>/dev/null || true
                            
                            # Remove dangling images to save space
                            docker image prune -f || true
                            
                            # Pull the latest image
                            docker pull ${FULL_IMAGE_PATH}:latest
                            
                            # Run new container
                            docker run -d \
                                --name ${CONTAINER_NAME} \
                                -p ${APP_PORT}:80 \
                                --restart unless-stopped \
                                ${FULL_IMAGE_PATH}:latest
                            
                            # Wait a moment for container to start
                            sleep 5
                            
                            # Verify container is running
                            if docker ps | grep -q ${CONTAINER_NAME}; then
                                echo "✅ Container ${CONTAINER_NAME} is running successfully"
                                docker ps | grep ${CONTAINER_NAME}
                            else
                                echo "❌ Container failed to start"
                                docker logs ${CONTAINER_NAME}
                                exit 1
                            fi
                        """
                    }
                }
            }
        }
        
        stage('Health Check') {
            steps {
                echo '========== Performing Health Check =========='
                script {
                    sh """
                        # Wait for application to be ready
                        sleep 10
                        
                        # Check if the application responds
                        echo "Testing application at localhost:${APP_PORT}"
                        if curl -f http://localhost:${APP_PORT} > /dev/null 2>&1; then
                            echo "✅ Health check passed - Application is responding"
                        else
                            echo "❌ Health check failed - Application is not responding"
                            docker logs ${CONTAINER_NAME}
                            exit 1
                        fi
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo '========== Pipeline Completed Successfully! =========='
            script {
                def SERVER_IP = sh(script: "curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H 'Metadata-Flavor: Google'", returnStdout: true).trim()
                
                withCredentials([usernamePassword(credentialsId: 'gmail-credentials', usernameVariable: 'EMAIL_USER', passwordVariable: 'EMAIL_PASS')]) {
                    emailext(
                        subject: "✅ Jenkins Build SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                        body: """
                            <html>
                            <body style="font-family: Arial, sans-serif;">
                                <div style="background-color: #4CAF50; color: white; padding: 20px; text-align: center;">
                                    <h1>🎉 Build Successful!</h1>
                                </div>
                                <div style="padding: 20px;">
                                    <h2>Build Details</h2>
                                    <table style="border-collapse: collapse; width: 100%;">
                                        <tr>
                                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Job Name:</strong></td>
                                            <td style="padding: 8px; border: 1px solid #ddd;">${env.JOB_NAME}</td>
                                        </tr>
                                        <tr>
                                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Build Number:</strong></td>
                                            <td style="padding: 8px; border: 1px solid #ddd;">#${env.BUILD_NUMBER}</td>
                                        </tr>
                                        <tr>
                                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Docker Image:</strong></td>
                                            <td style="padding: 8px; border: 1px solid #ddd;">${FULL_IMAGE_PATH}:${IMAGE_TAG}</td>
                                        </tr>
                                        <tr>
                                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Build URL:</strong></td>
                                            <td style="padding: 8px; border: 1px solid #ddd;"><a href="${env.BUILD_URL}">View in Jenkins</a></td>
                                        </tr>
                                    </table>
                                    
                                    <h2 style="margin-top: 30px;">🚀 Application Access</h2>
                                    <div style="background-color: #e3f2fd; padding: 15px; border-radius: 5px; margin: 10px 0;">
                                        <p style="margin: 5px 0;"><strong>Application URL:</strong></p>
                                        <p style="margin: 5px 0; font-size: 18px;">
                                            <a href="http://${SERVER_IP}" style="color: #1976D2; text-decoration: none;">
                                                http://${SERVER_IP}
                                            </a>
                                        </p>
                                    </div>
                                    
                                    <div style="background-color: #fff3e0; padding: 15px; border-radius: 5px; margin: 10px 0;">
                                        <p style="margin: 5px 0;"><strong>Jenkins Dashboard:</strong></p>
                                        <p style="margin: 5px 0;">
                                            <a href="http://${SERVER_IP}:8080" style="color: #F57C00; text-decoration: none;">
                                                http://${SERVER_IP}:8080
                                            </a>
                                        </p>
                                    </div>
                                    
                                    <h2 style="margin-top: 30px;">📦 Deployment Info</h2>
                                    <ul>
                                        <li>Platform: Google Cloud Platform (GCP)</li>
                                        <li>Deployment Type: Docker Container</li>
                                        <li>Container Name: ${CONTAINER_NAME}</li>
                                        <li>Port: ${APP_PORT}</li>
                                        <li>Registry: GCP Artifact Registry</li>
                                    </ul>
                                    
                                    <p style="margin-top: 30px; color: #666;">
                                        <em>This is an automated message from Jenkins CI/CD Pipeline</em>
                                    </p>
                                </div>
                            </body>
                            </html>
                        """,
                        to: 'mdsheraz102@gmail.com',
                        mimeType: 'text/html',
                        from: EMAIL_USER,
                        replyTo: EMAIL_USER
                    )
                }
            }
        }
        
        failure {
            echo '========== Pipeline Failed! =========='
            script {
                def SERVER_IP = sh(script: "curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H 'Metadata-Flavor: Google'", returnStdout: true).trim()
                
                withCredentials([usernamePassword(credentialsId: 'gmail-credentials', usernameVariable: 'EMAIL_USER', passwordVariable: 'EMAIL_PASS')]) {
                    emailext(
                        subject: "❌ Jenkins Build FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                        body: """
                            <html>
                            <body style="font-family: Arial, sans-serif;">
                                <div style="background-color: #f44336; color: white; padding: 20px; text-align: center;">
                                    <h1>⚠️ Build Failed!</h1>
                                </div>
                                <div style="padding: 20px;">
                                    <h2>Build Details</h2>
                                    <table style="border-collapse: collapse; width: 100%;">
                                        <tr>
                                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Job Name:</strong></td>
                                            <td style="padding: 8px; border: 1px solid #ddd;">${env.JOB_NAME}</td>
                                        </tr>
                                        <tr>
                                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Build Number:</strong></td>
                                            <td style="padding: 8px; border: 1px solid #ddd;">#${env.BUILD_NUMBER}</td>
                                        </tr>
                                        <tr>
                                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Build URL:</strong></td>
                                            <td style="padding: 8px; border: 1px solid #ddd;"><a href="${env.BUILD_URL}">View in Jenkins</a></td>
                                        </tr>
                                        <tr>
                                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Console Output:</strong></td>
                                            <td style="padding: 8px; border: 1px solid #ddd;"><a href="${env.BUILD_URL}console">View Console Log</a></td>
                                        </tr>
                                    </table>
                                    
                                    <div style="background-color: #ffebee; padding: 15px; border-radius: 5px; margin: 20px 0;">
                                        <h3 style="margin-top: 0; color: #c62828;">Action Required</h3>
                                        <p>Please check the console output to identify and fix the issue.</p>
                                        <p>
                                            <a href="${env.BUILD_URL}console" style="background-color: #f44336; color: white; padding: 10px 20px; text-decoration: none; border-radius: 3px; display: inline-block;">
                                                View Console Output
                                            </a>
                                        </p>
                                    </div>
                                    
                                    <h3>Jenkins Dashboard</h3>
                                    <p>
                                        <a href="http://${SERVER_IP}:8080">http://${SERVER_IP}:8080</a>
                                    </p>
                                    
                                    <p style="margin-top: 30px; color: #666;">
                                        <em>This is an automated message from Jenkins CI/CD Pipeline</em>
                                    </p>
                                </div>
                            </body>
                            </html>
                        """,
                        to: 'mdsheraz102@gmail.com',
                        mimeType: 'text/html',
                        from: EMAIL_USER,
                        replyTo: EMAIL_USER
                    )
                }
            }
        }
        
        always {
            // *** THIS IS THE FINAL FIX ***
            script {
                echo '========== Cleaning up workspace =========='
                deleteDir()
            }
        }
    }
}
