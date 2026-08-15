import org.jetbrains.kotlin.gradle.dsl.JvmTarget

import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
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

    // Ensure consistent Java/Kotlin compatibility across plugins (e.g., image_gallery_saver)
    afterEvaluate {
        extensions.findByName("android")?.let { androidExt ->
            val android = androidExt as com.android.build.gradle.BaseExtension
            android.compileOptions.apply {
                sourceCompatibility = JavaVersion.VERSION_1_8
                targetCompatibility = JavaVersion.VERSION_1_8
            }
            if (android.namespace == null) {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val manifestContent = manifestFile.readText()
                    val packageRegex = """package=["']([^"']+)["']""".toRegex()
                    val match = packageRegex.find(manifestContent)
                    if (match != null) {
                        android.namespace = match.groupValues[1]
                    } else {
                        android.namespace = "com.example." + project.name.replace("-", "_")
                    }
                } else {
                    android.namespace = "com.example." + project.name.replace("-", "_")
                }
            }
        }
        // Set Kotlin JVM target to 1.8 for all Kotlin compilation tasks
        tasks.withType<KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(JvmTarget.JVM_1_8)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
