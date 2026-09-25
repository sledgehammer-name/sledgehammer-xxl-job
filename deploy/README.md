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
