# py-lambda-action

[![GitHubActions](https://img.shields.io/badge/listed%20on-GitHubActions-blue.svg)](https://github-actions.netlify.com/py-lambda)

A Github Action to deploy AWS Lambda functions written in Python with their dependencies in a separate layer. For now, only works with Python 3.6.

## Use
Doesn't take any arguments. Deploys everything in the repo as code to the Lambda function, and installs/zips/deploys the dependencies as a separate layer the function can then immediately use.
### Structure
- Lambda code should be structured normally/as Lambda would expect it.
- **Dependencies must be stored in a `requirements.txt`**.
### Required Parameters
Passed to the action through a `with` block, can be pulled from secrets. But also please don't put your AWS keys outside Secrets.
- **AWS Credentials**  
    That includes the `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, etc. It's used by `awscli`, so the docs for that [can be found here](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html).
- `LAMBDA_LAYER_ARN`  
    The ARN for the Lambda layer the dependencies should be pushed to **without the version** (every push is a new version).
- `LAMBDA_FUNCITON_NAME`  
    The Lambda function name. [From the AWS docs](https://docs.aws.amazon.com/cli/latest/reference/lambda/update-function-code.html), it can be any of the following:
    - Function name - `my-function`  
    - Function ARN - `arn:aws:lambda:us-west-2:123456789012:function:my-function`  
    - Partial ARN - `123456789012:function:my-function`
- `LAYER_VERSION`  
    The Lambda layer version. [AWS docs can be found here](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html).

### Example workflow
```
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v2
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.DEFAULT_AWS_REGION }}
      - name: Py Lambda Deploy
        uses: mariamrf/py-lambda-action@master
        with:
          lambda_layer_arn: ${{ secrets.LAMBDA_LAYER_ARN }}
          lambda_function_name: ${{ secrets.LAMBDA_FUNCTION_NAME }}
          layer_version: ${{ secrets.LAYER_VERSION }}
```
