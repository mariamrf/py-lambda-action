# py-lambda-action

[![GitHubActions](https://img.shields.io/badge/listed%20on-GitHubActions-blue.svg)](https://github-actions.netlify.com/py-lambda)

A GitHub Action to deploy AWS Lambda functions written in Python with their dependencies in a separate layer. Works with Python versions 3.8, 3.9, 3.10, 3.11, 3.12.

## Use
Deploys everything in the repo as code to the Lambda function, and installs/zips/deploys the dependencies as a separate layer the function can then immediately use.

### Pre-requisites
In order for the Action to have access to the code, you must use the `actions/checkout@main` job before it. See the example below.

### Structure
- Lambda code should be structured normally/as Lambda would expect it.
- **Dependencies must be stored in a `requirements.txt`** or a similar file (provide the filename explicitly if that's the case).

### Environment variables
Stored as secrets or env vars, doesn't matter. But also please don't put your AWS keys outside Secrets.
- **AWS Credentials**
    That includes the `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, etc. It's used by `awscli`, so the docs for that [can be found here](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html).

### Inputs
- `lambda_layer_arn`  
    The ARN for the Lambda layer the dependencies should be pushed to **without the version** (every push is a new version).
- `lambda_function_name`  
    The Lambda function name. [From the AWS docs](https://docs.aws.amazon.com/cli/latest/reference/lambda/update-function-code.html), it can be any of the following:
    - Function name - `my-function`  
    - Function ARN - `arn:aws:lambda:us-west-2:123456789012:function:my-function`  
    - Partial ARN - `123456789012:function:my-function`
- `requirements_txt`
    The name/path for the `requirements.txt` file. Defaults to `requirements.txt`.
- `python_version`
    The version of Python to build with. (3.8, 3.9, 3.10, 3.11, 3.12)


### Example workflow
```yaml
name: deploy-py-lambda
on:
  push:
    branches:
      - master
jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@main
    - name: Deploy code to Lambda
      uses: mariamrf/py-lambda-action@master
      with:
        lambda_layer_arn: 'arn:aws:lambda:us-east-1:123456789012:layer:my-layer'
        lambda_function_name: 'my-function'
        python_version: '3.12'
      env:
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        AWS_DEFAULT_REGION: 'us-east-1'

```
