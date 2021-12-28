#!/bin/bash
set -e




name="$(basename $0)"
DEBUG=1


die()
{
    echo ERROR: $name: $@ >&2
    exit -1
}

log()
{
    echo INFO: $name: $@
}

debug()
{
    grep -q yes\\\|1\\\|on\\\|true <<< $DEBUG || return 0
    echo DEBUG: $name: $@
}


get_last_layer_version_arn()
{
    layer_name="$1"
    # TODO: could try all combinations of arch and runtimes
    result=$(aws lambda list-layer-versions --layer-name "$layer_name"	\
		 --compatible-architecture "${INPUT_ARCHITECTURES%% *}"	\
		 --compatible-runtime "${INPUT_RUNTIMES%% *}"		\
		 --max-items 1)
    arn="$(jq -e .LayerVersions[0].LayerVersionArn <<< "$result"|cut -d\" -f2)"
    [ $? != 0 ] || [ "$arn" == "null" ] && return 1
    echo -n $arn
}


make_archive()
{
    log "Building $INPUT_NAME $INPUT_TARGET archive..."
    archive="$(realpath .)/archive.zip"
    set -f
    trap "rm -f -- '$archive'" EXIT
        if [ -z "$INPUT_EXCLUDES" ]; then
	zip_opts=
    else
	zip_opts="-x $INPUT_EXCLUDES"
    fi
    debug "INPUT_EXCLUDES: $INPUT_EXCLUDES"
    debug "zip_opts: $zip_opts"
    set +f
    tempdir=$(mktemp -d pip.XXXXXXXXXX)
    trap "rm -rf -- '$archive' '$tempdir'" EXIT
    mkdir "$tempdir/python"
    if [ -n "$INPUT_PATH" ]; then
	log "Installing codes... : $INPUT_PATH"
	for path in $INPUT_PATH; do
	    ln -vs "$(realpath $path)/"* "$tempdir/python/"
	done
    fi
    if [ -n "$INPUT_PIP" ]; then
	log "Installing dependencies... : $INPUT_PIP"
	for path in $INPUT_PIP; do
	    pip install -t "$tempdir/python/" -r "$path"
	done
    fi
    log "Zipping archive..."
    set -f
    if [ "$INPUT_TARGET" == "layer" ]; then
	pushd "$tempdir"
	zip -r $archive python $zip_opts
	popd
    else
	pushd "$tempdir/python"
	zip -r $archive . $zip_opts
	popd
    fi
    set +f
    rm -rf -- "$tempdir"
    trap "rm -f -- '$archive'" EXIT
}

list_layer_version_arns()
{
    arns=
    for layer_name in $@; do
	layer_arn="$(get_last_layer_version_arn "$layer_name")"
	arns="$arns $layer_arn"
    done
    echo -n $arns
}

deploy_lambda_function()
{
    log "Deploying lambda function: $INPUT_NAME..."
    s3_url="s3://${INPUT_S3_BUCKET}/${INPUT_NAME}.zip"
    aws s3 cp "$archive" "$s3_url"
    log "Updating lambda function code: ${INPUT_NAME}"
    if aws lambda get-function --function-name "${INPUT_NAME}" >/dev/null 2>&1
    then
        aws lambda update-function-code                 \
            --architectures "$INPUT_ARCHITECTURES"      \
    	    --function-name "$INPUT_NAME"               \
    	    --zip-file "fileb://$archive"
        opts=
        if [ -n "$INPUT_LAYERS" ]; then
    	layers=$(list_layer_version_arns "$INPUT_LAYERS")
    	opts="--layers $layers"
        fi
        retry=4
        while ! aws lambda update-function-configuration    \
                --function-name "${INPUT_NAME}"             \
                --runtime "${INPUT_RUNTIMES%% *}" $opts; do
            retry="$(($retry - 1))"
            if [[ $retry -gt 0 ]]; then
                die "Cannot update-function-configuration: ${INPUT_NAME}"
            fi
            sleep 1
        done
        aws lambda publish-function "$INPUT_NAME"
    else
        log "No lambda function found: $INPUT_NAME"
    fi
    rm -f -- "$archive"
    trap - EXIT
}

deploy_lambda_layer()
{
    log "Deploying lambda layer: ${INPUT_NAME}..."
    local s3_url="s3://${INPUT_S3_BUCKET}/${INPUT_NAME}.zip"
    aws s3 cp "$archive" "$s3_url"
    local result="$(aws lambda publish-layer-version			\
                       --layer-name "$INPUT_LAMBDA_LAYER_ARN"		\
                       --compatible-architectures $INPUT_ARCHITECTURES	\
                       --compatible-runtimes $INPUT_RUNTIMES		\
                       --zip-file "fileb://$archive"			\
          )"
    arn="$(jq .LayerVersionArn <<< "$result")"
    [ $? != 0 ] || [ "$arn" == "null" ] && return 1
    echo -n $arn
}


TAG="${INPUT_NAME#*#}"
INPUT_NAME="${INPUT_NAME%#*}"


case "$INPUT_TARGET" in
    lambda)
	make_archive
	deploy_lambda_function
	;;
    layer)
	make_archive
	deploy_lambda_layer
	;;
    *)
	die Invalid resource target: $INPUT_TARGET
	;;
esac


log "Done."
