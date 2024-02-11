#!/bin/bash
set -e

install_zip_dependencies(){
	echo "Installing and zipping dependencies..."
	mkdir python
	pip${INPUT_PYTHON_VERSION} install --target=python -r "${INPUT_REQUIREMENTS_TXT}"
	zip -r dependencies.zip ./python
}

publish_dependencies_as_layer(){
	echo "Publishing dependencies as a layer..."
 	local result
	result=$(aws lambda publish-layer-version --layer-name "${INPUT_LAMBDA_LAYER_ARN}" --zip-file fileb://dependencies.zip --compatible-runtimes "python${INPUT_PYTHON_VERSION}" --compatible-architectures "x86_64")
	LAYER_VERSION=$(jq '.Version' <<< "$result")
	rm -rf python
	rm dependencies.zip
}

publish_function_code(){
	echo "Deploying the code..."
	zip -r code.zip . -x \*.git\*
	aws lambda update-function-code --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --zip-file fileb://code.zip
}

update_function_layers(){
	echo "Using the layer in the function..."
 	local function_state
  	local function_status
	function_state=$(aws lambda get-function --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --query 'Configuration.State')
 	function_status=$(aws lambda get-function --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --query 'Configuration.LastUpdateStatus')
	while [[ $function_state != "\"Active\"" && $function_status != "\"Successful\"" ]]
 	do
		function_state=$(aws lambda get-function --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --query 'Configuration.State')
  		function_status=$(aws lambda get-function --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --query 'Configuration.LastUpdateStatus')
		sleep 1
	done
 	echo "The Function State is: $function_state"
 	echo "The Function Status is: $function_status"
	aws lambda update-function-configuration --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --layers "${INPUT_LAMBDA_LAYER_ARN}:${LAYER_VERSION}"
}

deploy_lambda_function(){
	install_zip_dependencies
	publish_dependencies_as_layer
	publish_function_code
	update_function_layers
}

deploy_lambda_function
echo "DONE"
