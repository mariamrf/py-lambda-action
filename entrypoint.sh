#!/bin/bash
set -euo pipefail

install_zip_dependencies(){
	echo "Installing and zipping dependencies..."
	mkdir python
	pip install --target=python -r "${INPUT_REQUIREMENTS_TXT}"
	zip -r dependencies.zip ./python
}

publish_dependencies_as_layer(){
	echo "Publishing dependencies as a layer..."
	local result=$(aws lambda publish-layer-version --layer-name "${INPUT_LAMBDA_LAYER_ARN}" --zip-file fileb://dependencies.zip)
	LAYER_VERSION=$(jq '.Version' <<< "$result")
	rm -rf python
	rm dependencies.zip
}

files_to_exclude() {
    echo "exclude.lst" > exclude.lst
    echo ".git/*" >> exclude.lst
    read -ra ADDR <<< "$INPUT_EXCLUDE_FILES"
    for i in "${ADDR[@]}"; do
        echo "$i*" >> exclude.lst
    done
}

publish_function_code(){
	echo "Deploying the code itself..."
    files_to_exclude
	zip -r code.zip . -x@exclude.lst
	aws lambda update-function-code --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --zip-file fileb://code.zip
    rm exclude.lst
}

update_function_layers(){
	echo "Using the layer in the function..."
	aws lambda update-function-configuration --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --layers "${INPUT_LAMBDA_LAYER_ARN}:${LAYER_VERSION}"
}

deploy_lambda_function(){
	install_zip_dependencies
	publish_dependencies_as_layer
	publish_function_code
	update_function_layers
}

deploy_lambda_function
echo "Done."
