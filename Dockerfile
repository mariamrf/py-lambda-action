FROM python:3.6

RUN apt-get update
RUN apt-get install -y jq zip
RUN pip install awscli

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
