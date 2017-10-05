FROM ubuntu:16.04

MAINTAINER Mark Church <church@docker.com>

RUN apt-get update &&\
  apt-get install -y apt-transport-https ca-certificates curl jq unzip &&\
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - &&\
  echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable" > /etc/apt/sources.list.d/docker.list &&\
  apt-get update &&\
  apt-get install -y docker-ce &&\
  rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/docker.list

RUN mkdir /var/docker-backup

WORKDIR /var/docker-backup

COPY docker-ee-backup.sh /docker-ee-backup.sh

CMD ["/docker-ee-backup.sh"]



