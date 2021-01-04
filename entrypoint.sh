#!/bin/bash
set -e

poll_command="aws lambda get-function --function-name ${INPUT_LAMBDA_FUNCTION_NAME} --query Configuration.[State,LastUpdateStatus]"

wait_state(){
	echo "Waiting on function state update..."
	until ${poll_command} | grep "Active"
	do 
		sleep 1
	done
	until ${poll_command} | grep "Successful"
	do 
		sleep 1
	done
}

install_zip_dependencies(){
	echo "Installing and zipping dependencies..."
	mkdir python
	pip install --target=python -r "${INPUT_REQUIREMENTS_TXT}"
	zip -r dependencies.zip ./python
}

publish_dependencies_as_layer(){
	if [ "$INPUT_USE_S3" = true ]
	then
		echo "Uploading dependencies to S3..."
		aws s3 cp dependencies.zip s3://"${INPUT_S3_BUCKET_NAME}"/dependencies.zip
		echo "Publishing dependencies from S3 as a layer..."
		local result=$(aws lambda publish-layer-version --layer-name "${INPUT_LAMBDA_LAYER_ARN}" --content S3Bucket="${INPUT_S3_BUCKET_NAME}",S3Key=dependencies.zip)
	else
		echo "Publishing dependencies as a layer..."
		local result=$(aws lambda publish-layer-version --layer-name "${INPUT_LAMBDA_LAYER_ARN}" --zip-file fileb://dependencies.zip)
	fi
	LAYER_VERSION=$(jq '.Version' <<< "$result")
	rm -rf python
	rm dependencies.zip
}

publish_function_code(){
	echo "Deploying the code itself..."
	zip -r code.zip *.py -x \*.git\*
	aws lambda update-function-code --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --zip-file fileb://code.zip
}

update_function_layers(){
	echo "Using the layer in the function..."
	aws lambda update-function-configuration --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --layers "${INPUT_LAMBDA_LAYER_ARN}:${LAYER_VERSION}"
}

deploy_lambda_function(){
	install_zip_dependencies
	publish_dependencies_as_layer
	publish_function_code
	wait_state
	update_function_layers
}

deploy_lambda_function
echo "Done."
