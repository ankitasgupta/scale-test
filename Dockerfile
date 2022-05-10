####
# This Dockerfile is used in order to build a container that runs a 
# Quarkus application in JVM mode on s390x architecture (IBM System Z)
#
# Before building the docker image run:
#
# mvn package
#
# Then, build the image with:
#
# podman build -f src/main/docker/Dockerfile.jvmZ -t quay.io/<username>/mannequin:0.0-z .
#
# Then run the container using:
#
# podman run -i --rm -p 8080:8080 quarkus/mannequin-jvm quay.io/<username>/mannequin:0.0-z .
#
# the instructions here are to put it in a public registry (e.g. quay.io)
# so that you can pull it into a pod deployment on OpenShift
#
###
FROM registry.access.redhat.com/ubi8/ubi:latest
RUN dnf -y update && dnf -y install java-1.8.0-openjdk-devel
ENV JAVA_OPTIONS=-Dquarkus.http.host=0.0.0.0
COPY target/lib/* /deployments/lib/
COPY target/*-runner.jar /deployments/app.jar
COPY ./java-runner.sh /deployments/java-runner.sh
ENTRYPOINT [ "/deployments/java-runner.sh" ]
