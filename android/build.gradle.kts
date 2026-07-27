allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Forcer compileSdk sur TOUS les sous-projets incluant les plugins
subprojects {
    afterEvaluate {
        if (extensions.findByName("android") != null) {
            extensions.configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion(35)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
