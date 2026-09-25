pipeline {
    agent { label 'xxl-job-local' }
    options {
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '10'))
    }
    triggers {
        pollSCM('H/2 * * * *')
    }
    environment {
        JAVA_HOME = '/usr/lib/jvm/java-21-openjdk-amd64'
        PATH = "/usr/lib/jvm/java-21-openjdk-amd64/bin:/usr/bin:/bin:${env.PATH}"
    }
    stages {
        stage('Checkout main') {
            steps {
                deleteDir()
                retry(3) {
                    checkout scm
                }
                sh 'git log -1 --format="%h %s"'
            }
        }
        stage('Check tools') {
            steps {
                sh '''
                    set -eu
                    test "$(id -un)" = jenkins
                    java -version
                    mvn -version
                    git --version
                    test -f pom.xml
                    test -f xxl-job-admin/pom.xml
                '''
            }
        }
        stage('Build admin and dependencies') {
            steps {
                // 仓库当前默认跳过测试；首次部署保留此行为。
                // 根 POM 的 ci profile 保留编译参数，关闭 release 发布插件。
                sh '''
                    set -eu
                    mvn -B -ntp '-Pci,!release' \
                        -pl xxl-job-admin -am \
                        -Dmaven.test.skip=true clean package
                    test -s xxl-job-admin/target/xxl-job-admin.jar
                    jar tf xxl-job-admin/target/xxl-job-admin.jar > jar-contents.txt
                    grep -q '^BOOT-INF/' jar-contents.txt
                '''
            }
        }
        stage('Archive') {
            steps {
                archiveArtifacts artifacts: 'xxl-job-admin/target/xxl-job-admin.jar', fingerprint: true
            }
        }
        stage('Deploy and health check') {
            steps {
                sh '''
                    set -eu
                    /usr/local/bin/deploy-xxl-job-admin \
                        "$WORKSPACE/xxl-job-admin/target/xxl-job-admin.jar" \
                        "$BUILD_NUMBER-$(git rev-parse --short=12 HEAD)"
                '''
            }
        }
    }
    post {
        success { echo 'xxl-job-admin deployed: health check passed.' }
        failure { echo 'Failed. Read the failing stage and server service logs.' }
    }
}
