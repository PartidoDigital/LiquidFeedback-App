all:
	docker build -t liquid-feedback .

fresh:
	docker build --no-cache -t liquid-feedback .

run:
	open http://localhost:8080
	docker run --sig-proxy=false -p 8080:8080 liquid-feedback

clean:
	-docker rm -f $(shell docker ps -a -q)
	-docker rmi -f $(shell docker images -q)