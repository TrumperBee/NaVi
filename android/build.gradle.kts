plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}
allprojects {
    repositories {
        google()
        mavenCentral()
        // Mapbox Maven repository for native SDK downloads.
        // Supply SDK_REGISTRY_TOKEN locally only — ~/.gradle/gradle.properties
        // or the SDK_REGISTRY_TOKEN env var. Never commit a real value.
        // See docs/BUILD_SETUP.md.
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                create<BasicAuthentication>("basic")
            }
            credentials {
                username = "mapbox"
                password = project.findProperty("SDK_REGISTRY_TOKEN") as String?
                    ?: System.getenv("SDK_REGISTRY_TOKEN")
                    ?: ""
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
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
