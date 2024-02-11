FROM dhermes/python-multi

RUN apt-get update
RUN apt-get install -y jq zip
RUN pip install awscli

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
