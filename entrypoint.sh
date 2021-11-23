#!/bin/bash
set -e




name="$(basename $0)"


die()
{
    echo ERROR: $@ >&2
    exit -1
}

log()
{
    echo $name: $@
}




get_last_layer_version_arn()
{
    layer_name="$1"
    architecture="$2"
    runtime="$3"
    # TODO: could try all combinations of arch and runtimes
    result=$(aws lambda list-layer-versions --layer-name "$layer_name"	\
		 --compatible-architecture "$architecture"		\
		 --compatible-runtime "$runtime"			\
		 --max-items 1)
    jq .LayerVersions[0].LayerVersionArn <<< "$result"
}


make_archive()
{
    log "Building $INPUT_NAME $INPUT_TARGET archive..."
    archive="$(realpath .)/archive.zip"
    trap "rm -f -- '$archive'" EXIT
    log "Installing codes..."
    if [ -n "$INPUT_PATH" ]; then
	for path in $INPUT_PATH; do
	    [ -n "$INPUT_EXCLUDES" ] && opts="-x $INPUT_EXCLUDES" || opts=
	    pushd $path
	    zip -r $archive . $opts
	    popd
	done
    fi
    log "Installing dependencies..."
    if [ -n "$INPUT_PIP" ]; then
	tempdir=$(mktemp -d pip.XXXXXXXXXX)
	trap "rm -f -- '$archive' '$tempdir'" EXIT
	for path in $INPUT_PIP; do
	    pip install -t "$tempdir" -r "$path"
	done
	pushd "$tempdir"
	[ -n "$INPUT_EXCLUDES" ] && opts="-x $INPUT_EXCLUDES" || opts=
	zip -r $archive . $opts
	popd
	rm -f -- "$tempdir"
	trap "rm -f -- '$archive'" EXIT
    fi
    echo -n "$archive"
}

list_layer_version_arns()
{
    arns=
    for layer_name in $@; do
	layer_json="$(get_last_layer_version_arn "$layer_name")"
	arn="$(jq .LayerVersions[0].LayerVersionArn <<< $layer_json)"
	arns="$arns $arn"
    done
    echo -n $arns
}

deploy_lambda_function()
{
    log "Deploying lambda function: $INPUT_NAME..."
    s3_url="s3://${INPUT_S3_BUCKET}/${INPUT_NAME}.zip"
    aws s3 cp "$archive" "$s3_url"
    aws lambda update-function-code		\
        --architectures "$INPUT_ARCHITECTURES"	\
	--function-name "$INPUT_NAME"		\
	--zip-file "fileb://$archive"
    opts=""
    if [ -n "$INPUT_LAYERS" ]; then
	layers=$(list_layer_version_arns "$INPUT_LAYERS")
	opts="--layers $layers"
    fi
    aws lambda update-function-configuration --function-name "${INPUT_NAME}" \
	--runtime "${INPUT_RUNTIMES%% *}" $opts
    rm -f -- "$archive"
    trap - EXIT
}

deploy_lambda_layer()
{
    log "Deploying lambda layer: ${INPUT_NAME}..."
    local s3_url="s3://${INPUT_S3_BUCKET}/${INPUT_NAME}.zip"
    aws s3 cp "$archive" "$s3_url"
    local result="$(aws lambda publish-layer-version			 \
                       --layer-name "$INPUT_LAYER_LAMBDA_ARN"		 \
		       --compatible-architectures "$INPUT_ARCHITECTURES" \
		       --compatible-runtimes "$INPUT_RUNTIMES"		 \
		       --zip-file "fileb://$archive"			 \
	  )"
    arn="$(jq .LayerVersionArn <<< "$result")"
    echo -n $arn
}


TAG="${INPUT_NAME#*#}"
INPUT_NAME="${INPUT_NAME#*}"


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
