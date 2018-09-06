pipeline {
    agent {
        label "jenkins-go"
    }
    environment {
      ORG               = 'acm-workshop'
      APP_NAME          = 'catalogue'
      GIT_PROVIDER      = 'github.com'
      CHARTMUSEUM_CREDS = credentials('jenkins-x-chartmuseum')
    }
    stages {
      stage('CI Build and push snapshot') {
        when {
          branch 'PR-*'
        }
        environment {
          PREVIEW_VERSION = "0.0.0-SNAPSHOT-$BRANCH_NAME-$BUILD_NUMBER"
          PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
          HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
        }
        steps {
          dir ('/home/jenkins/go/src/github.com/acm-workshop/catalogue') {
            checkout scm
            container('go') {
              sh "make linux"
              sh 'export VERSION=$PREVIEW_VERSION && skaffold build -f skaffold.yaml'


              sh "jx step post build --image $DOCKER_REGISTRY/$ORG/$APP_NAME:$PREVIEW_VERSION"
            }
          }
          dir ('/home/jenkins/go/src/github.com/acm-workshop/catalogue/charts/preview') {
            container('go') {
              sh "make preview"
              sh "jx preview --app $APP_NAME --dir ../.."
            }
          }
        }
      }
      stage('Build Release') {
        when {
          branch 'master'
        }
        steps {
          container('go') {
            dir ('/home/jenkins/go/src/github.com/acm-workshop/catalogue') {
              checkout scm
            }
            dir ('/home/jenkins/go/src/github.com/acm-workshop/catalogue/charts/catalogue') {
                // ensure we're not on a detached head
                sh "git checkout master"
                // until we switch to the new kubernetes / jenkins credential implementation use git credentials store
                sh "git config --global credential.helper store"

                sh "jx step git credentials"
            }
            dir ('/home/jenkins/go/src/github.com/acm-workshop/catalogue') {
              // so we can retrieve the version in later steps
              sh "echo \$(jx-release-version) > VERSION"
            }
            dir ('/home/jenkins/go/src/github.com/acm-workshop/catalogue/charts/catalogue') {
              sh "make tag"
            }
            dir ('/home/jenkins/go/src/github.com/acm-workshop/catalogue') {
              container('go') {
                sh "./scripts/build.jb.sh"
                //sh "make release"
                sh 'export VERSION=`cat VERSION`' // && skaffold build -f skaffold.yaml'
                sh "docker build -t $DOCKER_REGISTRY/$ORG/$APP_NAME:\$(cat VERSION) -f ./build/docker/catalogue/Dockerfile ./build/docker"
                sh "docker push $DOCKER_REGISTRY/$ORG/$APP_NAME:\$(cat VERSION)"
                sh "jx step post build --image $DOCKER_REGISTRY/$ORG/$APP_NAME:\$(cat VERSION)"
              }
            }
          }
        }
      }
      stage('Promote to Staging') {
        when {
          branch 'master'
        }
        steps {
          dir ('/home/jenkins/go/src/github.com/acm-workshop/catalogue/charts/catalogue') {
            container('go') {
              sh 'jx step changelog --version v\$(cat ../../VERSION)'

              // release the helm chart
              sh 'jx step helm release'

              // promote through all 'Auto' promotion Environments
              sh 'jx promote --env staging --timeout 1h --version \$(cat ../../VERSION) $APP_NAME'
            }
          }
        }
      }
      stage('Health Check Staging') {
        steps {
          build job: 'jmeter-as-container/master', 
            parameters: [
              string(name: 'BUILD_JMETER', value: 'no'), 
              string(name: 'SCRIPT_NAME', value: 'basiccheck.jmx'), 
              string(name: 'SERVER_URL', value: '$APP_NAME.jx-staging.35.233.18.9.nip.io'),
              string(name: 'SERVER_PORT', value: '80'),
              string(name: 'CHECK_PATH', value: '/health'),
              string(name: 'VUCount', value: '1'),
              string(name: 'LoopCount', value: '1'),
              string(name: 'DT_LTN', value: 'HealthCheck'),
              string(name: 'FUNC_VALIDATION', value: 'yes'),
              string(name: 'AVG_RT_VALIDATION', value: '0')
            ]
        }
      }
      stage('Functional Check Staging') {
        steps {
          build job: 'jmeter-as-container/master', 
            parameters: [
              string(name: 'BUILD_JMETER', value: 'no'), 
              string(name: 'SCRIPT_NAME', value: 'catalogue_load.jmx'), 
              string(name: 'SERVER_URL', value: '$APP_NAME.jx-staging.35.233.18.9.nip.io'),
              string(name: 'SERVER_PORT', value: '80'),
              string(name: 'CHECK_PATH', value: '/health'),
              string(name: 'VUCount', value: '1'),
              string(name: 'LoopCount', value: '1'),
              string(name: 'DT_LTN', value: 'FuncCheck_${BUILD_NUMBER}'),
              string(name: 'FUNC_VALIDATION', value: 'yes'),
              string(name: 'AVG_RT_VALIDATION', value: '0')
            ]
        }
      }
      stage('Performance Check Staging') {
        steps {
          build job: 'jmeter-as-container/master', 
            parameters: [
              string(name: 'BUILD_JMETER', value: 'no'), 
              string(name: 'SCRIPT_NAME', value: 'catalogue_load.jmx'), 
              string(name: 'SERVER_URL', value: '$APP_NAME.jx-staging.35.233.18.9.nip.io'),
              string(name: 'SERVER_PORT', value: '80'),
              string(name: 'CHECK_PATH', value: '/health'),
              string(name: 'VUCount', value: '10'),
              string(name: 'LoopCount', value: '10000'),
              string(name: 'DT_LTN', value: 'PerfCheck_${BUILD_NUMBER}'),
              string(name: 'FUNC_VALIDATION', value: 'no'),
              string(name: 'AVG_RT_VALIDATION', value: '250')
            ]
        }
      }
    }
    post {
        always {
            cleanWs()
        }
    }
  }
