# iSantePlus Custom Modules

These `.omod` files are iSantePlus-specific modules not available in the public OpenMRS Maven repository. They are pre-built and committed to this repo.

## Module List

| Module | Version | Source Repo |
|--------|---------|------------|
| isanteplus | 1.4.6 | [IsantePlus/openmrs-module-isanteplus-old](https://github.com/IsantePlus/openmrs-module-isanteplus-old) |
| xds-sender | 2.5.0-SNAPSHOT | [IsantePlus/openmrs-module-xds-sender](https://github.com/IsantePlus/openmrs-module-xds-sender) |
| santedb-mpiclient | 1.1.4 | [IsantePlus/openmrs-module-mpi-client](https://github.com/IsantePlus/openmrs-module-mpi-client) |
| outgoing-message-exceptions | 1.0.0 | [IsantePlus/openmrs-module-outgoing-exception](https://github.com/IsantePlus/openmrs-module-outgoing-exception) |
| m2sys-biometrics | 1.2.4 | [IsantePlus/openmrs-module-m2sys-biometrics](https://github.com/IsantePlus/openmrs-module-m2sys-biometrics) |
| haiticore | 1.0.0-SNAPSHOT | [IsantePlus/openmrs-module-haiticore](https://github.com/IsantePlus/openmrs-module-haiticore) |
| isanteplusreports | 1.1-SNAPSHOT | [IsantePlus/openmrs-module-isanteplusreports](https://github.com/IsantePlus/openmrs-module-isanteplusreports) |
| labintegration | 2.3.6-SNAPSHOT | [IsantePlus/openmrs-module-labintegration](https://github.com/IsantePlus/openmrs-module-labintegration) |
| addresshierarchy | 2.11.0-SNAPSHOT | [IsantePlus/isanteplus_installation](https://github.com/IsantePlus/isanteplus_installation/tree/main/modules) |
| patientflags | 2.0.0-SNAPSHOT | [IsantePlus/isanteplus_installation](https://github.com/IsantePlus/isanteplus_installation/tree/main/modules) |
| referencemetadata | 2.7.0-SNAPSHOT | Extracted from running iSantePlus instance |

## How to Rebuild a Module

```bash
# Example: rebuild xds-sender
git clone https://github.com/IsantePlus/openmrs-module-xds-sender.git
cd openmrs-module-xds-sender
mvn clean package -B -DskipTests
cp omod/target/xds-sender-*.omod ../docker/custom-modules/
```

Note: Some modules (like `isanteplus-old`) have transitive dependencies on other iSantePlus modules that aren't in public Maven repos. You may need to `mvn install` the dependencies first.

## Why Pre-built?

Building these modules from source in CI hits dependency resolution failures — they depend on each other and on artifacts only available in the archived IsantePlus GitHub Packages Maven repo. Since the upstream repos are archived and the code isn't changing, pre-built `.omod` files are the pragmatic choice.
