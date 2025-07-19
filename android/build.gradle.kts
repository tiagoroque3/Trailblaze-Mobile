allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://developer.huawei.com/repo/") }
        maven { url = uri("https://www.jitpack.io") }
        // Repositório para os plugins da Transistor Software
        maven {
            url = uri("https://maven.transistorsoft.com/")
            isAllowInsecureProtocol = false
            // Tentar adicionar configurações adicionais
            content {
                includeGroup("com.transistorsoft")
            }
        }
        // Adicionar repositório alternativo para alguns pacotes
        maven {
            url = uri("https://jcenter.bintray.com/")
            isAllowInsecureProtocol = false
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
