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
              sh 'jx promote -b --env staging --timeout 1h --version \$(cat ../../VERSION) $APP_NAME'

              // just a quick curl against the deployed app
              sh "curl http://${env.APP_NAME}.${APP_STAGING_DOMAIN} || true"
            }
          }
        }
      }
    stage('DT Deploy Event') {
      // #1 we can either push the deployment event via the Dynatrace CLI and using Monspec
      /*agent {
        label "jenkins-dtcli"
      }
      steps {              
        container('dtcli') {
          checkout scm

          sh "python3 /dtcli/dtcli.py config apitoken ${DT_API_TOKEN} tenanthost ${DT_TENANT_URL}"
          sh "python3 /dtcli/dtcli.py monspec pushdeploy monspec/${APP_NAME}_monspec.json monspec/${APP_NAME}_pipelineinfo.json ${APP_NAME}/Staging JenkinsBuild_${BUILD_NUMBER} ${BUILD_NUMBER}"
        }
      }*/

      // #2 or we can use the built-in pipeline step of the Performance Signature Plugin
      steps {
        createDynatraceDeploymentEvent(
          envId: 'Dynatrace Tenant',
          tagMatchRules: [
            [
              meTypes: [
                [meType: 'SERVICE']
              ],
              tags: [
                [context: 'CONTEXTLESS', key: 'app', value: "${env.APP_NAME}"],
                [context: 'CONTEXTLESS', key: 'environment', value: 'jx-staging']
              ]
            ]
          ]) {
          // we could log anything while deployment event is created!
        }
      }
    }
    stage('Health Check Staging') {
      steps {
        // Lets give the app 30 extra seconds to be up&running
        sleep 30

        build job: "${env.ORG}/jmeter-tests/master",
          parameters: [
            string(name: 'SCRIPT_NAME', value: 'basiccheck.jmx'),
            string(name: 'SERVER_URL', value: "${env.APP_NAME}.${APP_STAGING_DOMAIN}"),
            string(name: 'SERVER_PORT', value: '80'),
            string(name: 'CHECK_PATH', value: '/health'),
            string(name: 'VUCount', value: '1'),
            string(name: 'LoopCount', value: '1'),
            string(name: 'DT_LTN', value: "HealthCheck_${BUILD_NUMBER}"),
            string(name: 'FUNC_VALIDATION', value: 'yes'),
            string(name: 'AVG_RT_VALIDATION', value: '0'),
            string(name: 'RETRY_ON_ERROR', value: 'yes')
          ]
      }
    }
    stage('Functional Check Staging') {
      steps {
        build job: "${env.ORG}/jmeter-tests/master",
          parameters: [
            string(name: 'SCRIPT_NAME', value: "${env.APP_NAME}_load.jmx"),
            string(name: 'SERVER_URL', value: "${env.APP_NAME}.${APP_STAGING_DOMAIN}"),
            string(name: 'SERVER_PORT', value: '80'),
            string(name: 'CHECK_PATH', value: '/health'),
            string(name: 'VUCount', value: '1'),
            string(name: 'LoopCount', value: '1'),
            string(name: 'DT_LTN', value: "FuncCheck_${BUILD_NUMBER}"),
            string(name: 'FUNC_VALIDATION', value: 'yes'),
            string(name: 'AVG_RT_VALIDATION', value: '0')
          ]
      }
    }
    stage('Performance Check Staging') {
      steps {

        recordDynatraceSession(
          envId: 'Dynatrace Tenant',
          testCase: 'loadtest',
          tagMatchRules: [
            [
              meTypes: [
                [meType: 'SERVICE']
              ],
              tags: [
                [context: 'CONTEXTLESS', key: 'app', value: "${env.APP_NAME}"],
                [context: 'CONTEXTLESS', key: 'environment', value: 'jx-staging']
              ]
            ]
          ]) {
          build job: "${env.ORG}/jmeter-tests/master",
            parameters: [
              string(name: 'SCRIPT_NAME', value: "${env.APP_NAME}_load.jmx"),
              string(name: 'SERVER_URL', value: "${env.APP_NAME}.${APP_STAGING_DOMAIN}"),
              string(name: 'SERVER_PORT', value: '80'),
              string(name: 'CHECK_PATH', value: '/health'),
              string(name: 'VUCount', value: '10'),
              string(name: 'LoopCount', value: '250'),
              string(name: 'DT_LTN', value: "PerfCheck_${BUILD_NUMBER}"),
              string(name: 'FUNC_VALIDATION', value: 'no'),
              string(name: 'AVG_RT_VALIDATION', value: '250')
            ]
        }

        // Now we use the Performance Signature Plugin to pull in Dynatrace Metrics based on the spec file
        perfSigDynatraceReports envId: 'Dynatrace Tenant', nonFunctionalFailure: 1, specFile: "monspec/${env.APP_NAME}_perfsig.json"
      }
    }
  }
    post {
        always {
            cleanWs()
        }
    }
  }
