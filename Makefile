# XXX no versioning of the docker image

.PHONY: build push clean test

build:
	docker build -t planitar/graphite .

push:
	docker build planitar/graphite

clean:
	docker rmi -f planitar/graphite
