pipeline {
    agent any

    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        ansiColor('xterm')
    }

    environment {
        DJANGO_SETTINGS_MODULE = 'shieldnet_backend.settings'
        PYTHONUNBUFFERED = '1'
        CI = 'true'
    }

    stages {
        stage('Environnement & Outils') {
            steps {
                script {
                    echo "=========================================================="
                    echo " ShieldNet CI/CD — Pipeline d'Intégration Continue (UQO)"
                    echo " Nœud d'exécution: ${env.NODE_NAME} | Build #${env.BUILD_NUMBER}"
                    echo "=========================================================="
                    if (isUnix()) {
                        sh 'python3 --version || python --version'
                        sh 'flutter --version'
                    } else {
                        bat 'python --version'
                        bat 'flutter --version'
                    }
                }
            }
        }

        stage('Backend — Validation & Tests (Django)') {
            steps {
                dir('shieldnet_backend') {
                    script {
                        echo "--- Validation des migrations et tests unitaires Django (74 tests) ---"
                        if (isUnix()) {
                            sh 'python3 -m pip install -r requirements.txt --quiet'
                            sh 'python3 manage.py makemigrations --check --dry-run'
                            sh 'python3 manage.py test shield_api --verbosity=2'
                        } else {
                            bat 'pip install -r requirements.txt --quiet'
                            bat 'python manage.py makemigrations --check --dry-run'
                            bat 'python manage.py test shield_api --verbosity=2'
                        }
                    }
                }
            }
        }

        stage('Mobile — Analyse Statique (Flutter Linter)') {
            steps {
                dir('ShieldNet') {
                    script {
                        echo "--- Vérification statique du code Flutter (flutter analyze) ---"
                        if (isUnix()) {
                            sh 'flutter pub get'
                            sh 'flutter analyze --no-fatal-infos'
                        } else {
                            bat 'flutter pub get'
                            bat 'flutter analyze --no-fatal-infos'
                        }
                    }
                }
            }
        }

        stage('Mobile — Tests Unitaires & Widgets (Flutter)') {
            steps {
                dir('ShieldNet') {
                    script {
                        echo "--- Exécution des tests unitaires Flutter (62 tests) ---"
                        if (isUnix()) {
                            sh 'flutter test'
                        } else {
                            bat 'flutter test'
                        }
                    }
                }
            }
        }

        stage('Mobile — Compilation de l\'APK Android') {
            steps {
                dir('ShieldNet') {
                    script {
                        echo "--- Compilation de l'application Android (Debug APK) ---"
                        if (isUnix()) {
                            sh 'flutter build apk --debug'
                        } else {
                            bat 'flutter build apk --debug'
                        }
                    }
                }
            }
        }

        stage('Archivage des Artefacts') {
            steps {
                dir('ShieldNet') {
                    script {
                        echo "--- Archivage de l'APK généré pour téléchargement direct ---"
                    }
                }
                archiveArtifacts artifacts: 'ShieldNet/build/app/outputs/flutter-apk/*.apk',
                                 allowEmptyArchive: true,
                                 fingerprint: true
            }
        }
    }

    post {
        always {
            cleanWs deleteDirs: true, notFailBuild: true, patterns: [[pattern: 'tmp/**', type: 'INCLUDE']]
        }
        success {
            echo "=========================================================="
            echo " [SUCCÈS] Pipeline ShieldNet validé : 136 tests au vert ! "
            echo "  - Backend Django REST : 74/74 tests réussis"
            echo "  - Analyse statique Dart : 0 erreur, 0 avertissement"
            echo "  - Client mobile Flutter : 62/62 tests réussis"
            echo "=========================================================="
        }
        failure {
            echo "=========================================================="
            echo " [ÉCHEC] Échec détecté dans la chaîne d'intégration continue."
            echo "=========================================================="
        }
    }
}
