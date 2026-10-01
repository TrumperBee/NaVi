plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}
allprojects {
    repositories {
        google()
        mavenCentral()
        // Mapbox Maven repository for native SDK downloads.
        // Requires SDK_REGISTRY_TOKEN in ~/.gradle/gradle.properties:
        //   SDK_REGISTRY_TOKEN=sk.YOUR_SECRET_MAPBOX_ACCESS_TOKEN
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                create<BasicAuthentication>("basic")
            }
            credentials {
                username = "mapbox"
                password = project.findProperty("SDK_REGISTRY_TOKEN") as String? ?: ""
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
