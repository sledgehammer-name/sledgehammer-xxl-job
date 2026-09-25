# Jenkins deployment

This repository deploys `xxl-job-admin` through the `xxl-job-dev` Jenkins job.
The Jenkins node must have the `xxl-job-local` label and run as `jenkins`.

Build from the repository root:

```sh
mvn -B -ntp '-Pci,!release' -pl xxl-job-admin -am -Dmaven.test.skip=true clean package
```

The pipeline intentionally skips the existing environment-dependent tests.
Its success means compilation, packaging and deployment health checks passed,
not that the repository's test suite ran.

Before the first deployment, an administrator must prepare:

- The existing `xxl_job` database, backed up without reimporting initialization SQL.
- `/etc/xxl-job-admin/application.properties`, owned by `root:xxljob`, mode `0640`.
- The `xxl-job-admin` systemd unit and the unprivileged `xxljob` service user.
- `/opt/xxl-job-admin/releases`, writable by `jenkins`.
- `/usr/local/bin/deploy-xxl-job-admin`, installed from the script in this directory.
- Permission for `jenkins` to restart/stop only `xxl-job-admin` through sudo.
- `/etc/xxl-job-admin/logback.xml`, installed from `deploy/logback.xml`, owned by `root:xxljob`, mode `0640`.
- `/var/log/xxl-job-admin`, owned by `xxljob:xxljob`, mode `0750`.

The service selects the external Logback file with a JVM property so it is
available before Spring initializes. This avoids the packaged `logback.xml`
attempting to open a log file owned by the previous launch user.

Jenkins checks `main` every two minutes and publishes versioned JARs. The
application listens on 9020. Health checks use 127.0.0.1:19020/actuator/health.
The deployment script restores the previous JAR when a normal deployment
restart or health check fails, but reports the failed build as a failure.
A forced termination or power outage may require manual recovery.

Database passwords and executor tokens must come from external server
configuration or environment variables. Never commit real credentials.
JAR rollback does not roll back database changes or external configuration.

## Git checkout on this server

Use Pipeline script from SCM with lightweight checkout disabled. Set the Git
refspec to `+refs/heads/main:refs/remotes/origin/main`, honor the refspec on
initial clone, disable tag fetching, and enable a shallow clone of depth 1.
The pipeline preserves `.git` between builds and removes untracked build
outputs after checkout. GitHub remains the source of the selected revision.

## Jenkins plugins

Install the complete **Pipeline** plugin (`workflow-aggregator`) and **Git**.
Pipeline must include Declarative, Basic Steps, Nodes and Processes, and
Durable Task; merely having Pipeline: Job installed is insufficient. If the
console reports `No such DSL method 'pipeline'`, check plugin loading before
changing the Jenkinsfile.

Use `https://updates.jenkins.io/update-center.json` as the update site.
An old mirror returning HTTP 404 cannot provide a reliable plugin catalog.
Refresh Available plugins after saving the update site and verify each
dependency installed successfully. Restart Jenkins while idle if required.
