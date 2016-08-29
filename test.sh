#!/bin/bash

set -ex

IMAGE_NAME=$1

curl() {
  docker run --rm --net host planitar/base curl "$@"
}
nc_send() {
  local line
  read line
  docker run --rm --net host planitar/base bash -c "echo $line | nc $1 $2"
}

echo Booting the test docker container...

docker run --rm ${IMAGE_NAME} /bin/true

DOCKERID=$(docker run -dP ${IMAGE_NAME})
CARBON_PORT=$(docker port ${DOCKERID} 2003 | sed 's/^.*://')
RENDER_PORT=$(docker port ${DOCKERID} 81 | sed 's/^.*://')
GRAFANA_PORT=$(docker port ${DOCKERID} 80 | sed 's/^.*://')

echo Running the test...

# Carbon cache overrides all received values in the interval with the
# last recieved value. In our case the interval 1s. Hence wait -- 1s.
for i in 1 2 3 4 5; do \
  echo "test.count 1 `date +%s`" | nc_send localhost ${CARBON_PORT}; \
  sleep 1s; \
done

sleep 1s;
if ! curl -s "http://localhost:${RENDER_PORT}/render?target=test.count&format=raw&from=-10seconds" | \
  grep -q '^test.count,.*|.*1\.0,1\.0,1\.0,1\.0,1\.0'; then \
    echo 'Test failed...'; \
    curl -s "http://localhost:${RENDER_PORT}/render?target=test.count&format=raw&from=-20seconds"; \
    docker rm -f ${DOCKERID}; \
    false; \
fi

if !  curl -s "http://localhost:${GRAFANA_PORT}/" | \
  grep -q '<title>Grafana</title>'; then \
    echo 'Test failed...'; \
    curl -s "http://localhost:${GRAFANA_PORT}/"; \
    docker rm -f ${DOCKERID}; \
    false; \
fi

docker rm -f ${DOCKERID} >/dev/null
echo 'Test passed'
