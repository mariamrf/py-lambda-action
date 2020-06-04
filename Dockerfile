FROM python:3.7

LABEL "com.github.actions.name"="Python Lambda Deploy"
LABEL "com.github.actions.description"="Deploy python code to AWS Lambda with dependencies in a separate layer."
LABEL "com.github.actions.icon"="layers"
LABEL "com.github.actions.color"="yellow"

LABEL "repository"="http://github.com/filipall/py-lambda-action"

RUN apt-get update
RUN apt-get install -y jq zip
RUN pip install awscli

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
