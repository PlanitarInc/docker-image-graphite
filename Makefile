# XXX no versioning of the docker image

.PHONY: build push clean test

build:
	docker build -t planitar/graphite .

push:
	docker build planitar/graphite

clean:
	docker rmi -f planitar/graphite

test:
	@# XXX I'm sorry, mama...
	@echo Booting the test docker container...
	@docker run planitar/graphite /bin/true
	$(eval DOCKERID := $(shell docker run -dP planitar/graphite))
	$(eval CARBON_PORT := $(shell docker port ${DOCKERID} 2003 | sed 's/^.*://'))
	$(eval RENDER_PORT := $(shell docker port ${DOCKERID} 81 | sed 's/^.*://'))
	$(eval GRAFANA_PORT := $(shell docker port ${DOCKERID} 80 | sed 's/^.*://'))
	@sleep 3s
	@echo Running the test...
	@# Carbon cache overrides all received values in the interval with the
	@# last recieved value. In our case the interval 1s. Hence wait -- 1s.
	for i in 1 2 3 4 5; do \
	  echo "test.count 1 `date +%s`" | nc localhost ${CARBON_PORT}; \
	  sleep 1s; \
	done
	sleep 1s;
	if !  curl -s 'http://localhost:${RENDER_PORT}/render?target=test.count&format=raw&from=-10seconds' | \
	  grep -q '^test.count,.*|.*1\.0,1\.0,1\.0,1\.0,1\.0'; then \
	    echo 'Test failed...'; \
	    curl -s 'http://localhost:${RENDER_PORT}/render?target=test.count&format=raw&from=-20seconds'; \
	    docker rm -f ${DOCKERID}; \
	    false; \
	fi
	if !  curl -s 'http://localhost:${GRAFANA_PORT}/' | \
	  grep -q '<title>Grafana</title>'; then \
	    echo 'Test failed...'; \
	    curl -s 'http://localhost:${GRAFANA_PORT}/'; \
	    docker rm -f ${DOCKERID}; \
	    false; \
	fi
	@docker rm -f ${DOCKERID} >/dev/null
	@echo 'Test passed'
