#!/bin/bash
set -ueo pipefail

ME=$(basename "$0")
S3_BUCKET="${AWS_BUCKET_NAME:-}"
S3_ENDPOINT="${S3_ENDPOINT:-}"
S3_ENDPOINT_URL="${S3_ENDPOINT:-}"
S3SYNC_PATH="${S3SYNC_PATH:-s3://${AWS_BUCKET_NAME}/}"

download() {
	if [[ -f "${S3SYNC_LOCAL_DIR%/}/s3sync.downloaded" ]]; then return 0; fi

	if which s5cmd >/dev/null; then
		cmd="s5cmd --endpoint-url='${S3_ENDPOINT}' sync --delete '${S3SYNC_PATH%/}/*' '${S3SYNC_LOCAL_DIR%/}/'"
	else
		cmd="aws s3 sync '${S3SYNC_PATH}' '${S3SYNC_LOCAL_DIR}' --endpoint='${S3_ENDPOINT}' --delete"
	fi

	echo $cmd $@
	eval $cmd $@

	# fix any permissions issues%
	chmod -vR a=rwx "${S3SYNC_LOCAL_DIR}"

	echo $(date '+%Y-%m-%d-%H:%M:%S') > "${S3SYNC_LOCAL_DIR%/}/s3sync.downloaded"
}

upload() {
	if which s5cmd >/dev/null; then
		cmd="s5cmd --endpoint-url='${S3_ENDPOINT}' sync --delete '${S3SYNC_LOCAL_DIR%/}/*' '${S3SYNC_PATH%/}/'"
	else
		cmd="aws s3 sync '${S3SYNC_LOCAL_DIR}' '${S3SYNC_PATH}' --endpoint='${S3_ENDPOINT}' --delete"
	fi

	echo $cmd $@
	eval $cmd $@
}

watch_upload() {
	inotifywait -mr "${S3SYNC_LOCAL_DIR}" -e create -e delete -e move -e modify --format '%w%f %e' | \
	while read -r file _ ; do
		# ignore sqlite tmp files
		if [[ "${file}" =~ \.db-(journal|wal|shm)$ ]]; then
			continue
		fi
		# sleeping before execution to accumulate any other file changes...
		sleep 5
		upload "$@"
	done
}

main() {
	case "${1}" in
		download)
			download "${@:2}"
			;;
		upload)
			watch_upload "${@:2}"
			;;
		help|--help|-h)
			cat <<-EOF
			Usage: ${ME} [command] [extra parameters]

			Commands:
			  upload - watch for changes in S3SYNC_LOCAL_DIR and sync S3SYNC_LOCAL_DIR to S3
			    Example: /app/s3sync.sh upload --exclude "*.txt" --exclude "*.gz"
			  download - download all remote files to S3SYNC_LOCAL_DIR and exit
			EOF
			exit 0
			;;
		*)
			echo "$(date -u): Unknown command: ${1}" > /dev/stderr
			exit 1
			;;
	esac
}

if [[ -n "${S3SYNC_ENABLE-}" ]]; then main $@; else echo 'S3SYNC_ENABLE is not set'; sleep infinity; fi
