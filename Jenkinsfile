/**
 * ----------------------------------------------------------------------------
 *          ____  _____________  __
 *         / __ \/ ____/ ___/\ \/ /                 _   _   _
 *        / / / / __/  \__ \  \  /                 / \ / \ / \
 *       / /_/ / /___ ___/ /  / /               = ( M | S | K )=
 *      /_____/_____//____/  /_/                   \_/ \_/ \_/
 *
 *-----------------------------------------------------------------------------

 * Default pipline for multibranch Jenkins piplen project
 * Checks linting Build and Publish tagged version to PyPi

 */

pipeline {
    agent any
    environment {
        PYPI_TOKEN = credentials('pypi-token-desyrdl')
    }
    stages {
        stage('Environment') {
            steps{
                sh 'git clean -f -d -x'
                sh 'git fetch -p -t -f'
                sh 'git reset --hard'
                sh """python3 -m venv venv
                    . ./venv/bin/activate
                    pip install -U pip
                    pip install hatch"""
            }
        }
        stage('Test') {
            steps {
                sh '. ./venv/bin/activate && hatch -e lint run all'
            }
        }
        stage('Build') {
            steps {
                sh '. ./venv/bin/activate && hatch build'
            }
            post {
                success {
                    archiveArtifacts 'dist/*'
                }
            }
        }
        stage('Publish') {
            when { buildingTag() }
            steps {
                sh '. ./venv/bin/activate && hatch publish -u __token__ -a $PYPI_TOKEN'
            }
        }
    }
}
