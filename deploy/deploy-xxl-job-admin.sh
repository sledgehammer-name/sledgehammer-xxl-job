#!/usr/bin/env bash
set -Eeuo pipefail

base=/opt/xxl-job-admin
health=http://127.0.0.1:19020/actuator/health
artifact=${1:?Usage: deploy-xxl-job-admin JAR RELEASE_ID}
release_id=${2:?Missing RELEASE_ID}
[[ "$release_id" =~ ^[0-9]+-[0-9a-f]{7,40}$ ]] || { echo 'Invalid release ID'; exit 2; }
[[ -s "$artifact" ]] || { echo 'JAR missing or empty'; exit 2; }

exec 9>"$base/.deploy.lock"
flock -n 9 || { echo 'Another deployment or rollback is running'; exit 2; }

release="$base/releases/$release_id.jar"
[[ ! -e "$release" ]] || { echo 'Release already exists'; exit 2; }
old=$(readlink -f "$base/current.jar" 2>/dev/null || true)
install -m 0644 "$artifact" "$release"

switch_to() {
    ln -sfn "$1" "$base/current.jar.next"
    mv -Tf "$base/current.jar.next" "$base/current.jar"
}

healthy() {
    local i
    for i in $(seq 1 40); do
        if systemctl is-active --quiet xxl-job-admin && \
           curl -fsS --connect-timeout 2 --max-time 3 "$health" | \
           jq -e '.status == "UP"' >/dev/null 2>&1; then
            return 0
        fi
        sleep 3
    done
    return 1
}

switch_to "$release"
if sudo -n /usr/bin/systemctl restart xxl-job-admin && healthy; then
    if [[ -n "$old" && -f "$old" ]]; then
        printf '%s\n' "$old" > "$base/previous-release.txt"
    fi
    printf 'Deployment successful: %s\n' "$release_id"
    exit 0
fi

echo 'Deployment failed. Attempting to restore the previous JAR.'
if [[ -n "$old" && -f "$old" ]]; then
    switch_to "$old"
    if sudo -n /usr/bin/systemctl restart xxl-job-admin && healthy; then
        echo 'Previous release restored; this Jenkins build still fails.'
    else
        echo 'Rollback health check failed. Inspect journalctl immediately.'
    fi
else
    sudo -n /usr/bin/systemctl stop xxl-job-admin || true
    rm -f "$base/current.jar"
    echo 'First deployment failed; no previous release exists.'
fi
exit 1
