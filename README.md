# docker-youtrack

[![](https://imagelayers.io/badge/agross/youtrack:latest.svg)](https://imagelayers.io/?images=agross/youtrack:latest 'Get your own badge on imagelayers.io')

This Dockerfile allows you to build images to deploy your own [YouTrack](http://www.jetbrains.com/youtrack/) instance. It has been tested on [Fedora 23](https://getfedora.org/) and [CentOS 7](https://www.centos.org/).

*Please remember to back up your data directories often, especially before upgrading to a newer version.*

## Test it

1. [Install docker.](http://docs.docker.io/en/latest/installation/)
2. Run the container. (Stop with CTRL-C.)

  ```sh
  docker run -it -p 8080:8080 agross/youtrack
  ```

3. Open your browser and navigate to `http://localhost:8080`.

## Run it as service on systemd

1. Decide where to put YouTrack data and logs. Set domain name/server name and the public port.

  ```sh
  YOUTRACK_DATA="/var/data/youtrack"
  YOUTRACK_LOGS="/var/log/youtrack"

  DOMAIN=example.com
  PORT=8012
  ```

2. Create directories to store data and logs outside of the container.

  ```sh
  mkdir --parents "$YOUTRACK_DATA/backups" \
                  "$YOUTRACK_DATA/conf" \
                  "$YOUTRACK_DATA/data" \
                  "$YOUTRACK_LOGS"
  ```

3. Set permissions.

  The Dockerfile creates a `youtrack` user and group. This user has a `UID` and `GID` of `5000`. Make sure to add a user to your host system with this `UID` and `GID` and allow this user to read and write to `$YOUTRACK_DATA` and `$YOUTRACK_LOGS`. The name of the host user and group in not important.

  ```sh
  # Create youtrack group and user in docker host, e.g.:
  groupadd --gid 5000 --system youtrack
  useradd --uid 5000 --gid 5000 --system --shell /sbin/nologin --comment "JetBrains YouTrack" youtrack

  # 5000 is the ID of the youtrack user and group created by the Dockerfile.
  chown -R 5000:5000 "$YOUTRACK_DATA" "$YOUTRACK_LOGS"
  ```

4. Create your container.

  *Note:* The `:z` option on the volume mounts makes sure the SELinux context of the directories are [set appropriately.](http://www.projectatomic.io/blog/2015/06/using-volumes-with-docker-can-cause-problems-with-selinux/)

  ```sh
  docker create -it -p $PORT:8080 \
                    -v "$YOUTRACK_DATA/backups:/youtrack/backups:z" \
                    -v "$YOUTRACK_DATA/conf:/youtrack/conf:z" \
                    -v "$YOUTRACK_DATA/data:/youtrack/data:z" \
                    -v "$YOUTRACK_LOGS:/youtrack/logs:z" \
                    --name youtrack \
                    agross/youtrack
  ```

5. Create systemd unit, e.g. `/etc/systemd/system/youtrack.service`.

  ```sh
  cat <<EOF > "/etc/systemd/system/youtrack.service"
  [Unit]
  Description=JetBrains YouTrack
  Requires=docker.service
  After=docker.service

  [Service]
  Restart=always
  PrivateTmp=true
  ExecStart=/usr/bin/docker start --attach=true youtrack
  ExecStop=/usr/bin/docker stop --time=10 youtrack

  [Install]
  WantedBy=multi-user.target
  EOF

  systemctl enable youtrack.service
  systemctl start youtrack.service
  ```

6. Setup logrotate, e.g. `/etc/logrotate.d/youtrack`.

  ```sh
  cat <<EOF > "/etc/logrotate.d/youtrack"
  $YOUTRACK_LOGS/*.log
  $YOUTRACK_LOGS/hub/*.log
  $YOUTRACK_LOGS/hub/logs/*.log
  $YOUTRACK_LOGS/youtrack/*.log
  $YOUTRACK_LOGS/youtrack/logs/*.log
  $YOUTRACK_LOGS/internal/services/bundleProcess/*.log
  {
    rotate 7
    daily
    dateext
    missingok
    notifempty
    sharedscripts
    copytruncate
    compress
  }
  EOF
  ```
7. Add nginx configuration, e.g. `/etc/nginx/conf.d/youtrack.conf`.

  ```sh
  cat <<EOF > "/etc/nginx/conf.d/youtrack.conf"
  upstream youtrack {
    server localhost:$PORT;
  }

  server {
    listen           80;
    listen      [::]:80;

    server_name $DOMAIN;

    access_log  /var/log/nginx/$DOMAIN.access.log;
    error_log   /var/log/nginx/$DOMAIN.error.log;

    # Do not limit upload.
    client_max_body_size 0;

    # Required to avoid HTTP 411: see issue #1486 (https://github.com/dotcloud/docker/issues/1486)
    chunked_transfer_encoding on;

    location / {
      proxy_pass http://youtrack;

      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-Host \$http_host;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_http_version 1.1;
    }
  }
  EOF

  nginx -s reload
  ```

  Make sure SELinux policy allows nginx to access port `$PORT` (the first part of `-p $PORT:8080` of step 3).

  ```sh
  if [ $(semanage port --list | grep --count "^http_port_t.*$PORT") -eq 0 ]; then
    if semanage port --add --type http_port_t --proto tcp $PORT; then
      echo Added port $PORT as a valid port for nginx:
      semanage port --list | grep ^http_port_t
    else
      >&2 echo Could not add port $PORT as a valid port for nginx. Please add it yourself. More information: http://axilleas.me/en/blog/2013/selinux-policy-for-nginx-and-gitlab-unix-socket-in-fedora-19/
    fi
  else
    echo Port $PORT is already a valid port for nginx:
    semanage port --list | grep ^http_port_t
  fi
  ```

8. Configure YouTrack.

  Follow the steps of the installation [instructions for JetBrains YouTrack](https://confluence.jetbrains.com/display/YTD65/Installing+YouTrack+with+ZIP+Distribution) using paths inside the docker container located under

    * `/youtrack/backups`,
    * `/youtrack/data`,
    * `/youtrack/logs` and
    * `/youtrack/temp`.

9. Update to a newer version.

  ```sh
  docker pull agross/youtrack

  systemctl stop youtrack.service

  # Back up $YOUTRACK_DATA.
  tar -zcvf "youtrack-data-$(date +%F-%H-%M-%S).tar.gz" "$YOUTRACK_DATA"

  docker rm youtrack

  # Repeat step 4 and create a new image.
  docker create ...

  systemctl start youtrack.service
  ```

## Building and testing the `Dockerfile`

1. Build the `Dockerfile`.

  ```sh
  docker build --tag agross/youtrack:testing .

  docker images
  # Should contain:
  # REPOSITORY                        TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
  # agross/youtrack                   testing             0dcb8bf6093f        49 seconds ago      405.4 MB

  ```

2. Prepare directories for testing.

  ```sh
  TEST_DIR="/tmp/youtrack-testing"

  mkdir --parents "$TEST_DIR/backups" \
                  "$TEST_DIR/conf" \
                  "$TEST_DIR/data" \
                  "$TEST_DIR/logs"
  chown -R 5000:5000 "$TEST_DIR"
  ```

3. Run the container built in step 1.

  *Note:* The `:z` option on the volume mounts makes sure the SELinux context of the directories are [set appropriately.](http://www.projectatomic.io/blog/2015/06/using-volumes-with-docker-can-cause-problems-with-selinux/)

  ```sh
  docker run -it --rm \
                 --name youtrack-testing \
                 -p 8080:8080 \
                 -v "$TEST_DIR/backups:/youtrack/backups:z" \
                 -v "$TEST_DIR/conf:/youtrack/conf:z" \
                 -v "$TEST_DIR/data:/youtrack/data:z" \
                 -v "$TEST_DIR/logs:/youtrack/logs:z" \
                 agross/youtrack:testing
  ```

4. Open a shell to your running container.

  ```sh
  docker exec -it youtrack-testing bash
  ```

5. Run bash instead of starting YouTrack.

  *Note:* The `:z` option on the volume mounts makes sure the SELinux context of the directories are [set appropriately.](http://www.projectatomic.io/blog/2015/06/using-volumes-with-docker-can-cause-problems-with-selinux/)

  ```sh
  docker run -it -v "$TEST_DIR/backups:/youtrack/backups:z" \
                 -v "$TEST_DIR/conf:/youtrack/conf:z" \
                 -v "$TEST_DIR/data:/youtrack/data:z" \
                 -v "$TEST_DIR/logs:/youtrack/logs:z" \
                 agross/youtrack:testing bash
  ```

  Without mounted data directories:

  ```sh
  docker run -it agross/youtrack:testing bash
  ```

6. Clean up after yourself.

  ```sh
  docker ps -aq --no-trunc --filter ancestor=agross/youtrack:testing | xargs --no-run-if-empty docker rm
  docker images -q --no-trunc agross/youtrack:testing | xargs --no-run-if-empty docker rmi
  rm -rf "$TEST_DIR"
  ```
