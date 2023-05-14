#!/bin/bash
set -ueo pipefail

ME=$(basename "$0")
S3_PATH="${S3_PATH:-s3://${AWS_BUCKET_NAME}/}"
S3_ENDPOINT="${S3_ENDPOINT:-}"

download() {
	if [[ -f "${LOCAL_DIR%/}/s3sync.downloaded" ]]; then return 0; fi

	if which s5cmd >/dev/null; then
		s5cmd --endpoint-url="${S3_ENDPOINT}" sync --delete "${S3_PATH%/}/*" "${LOCAL_DIR%/}/"
	else
		aws s3 sync "${S3_PATH}" "${LOCAL_DIR}" --endpoint="${S3_ENDPOINT}" --delete
	fi

	# fix any permissions issues%
	chmod -vR a=rwx "${LOCAL_DIR}"

	echo $(date '+%Y-%m-%d-%H:%M:%S') > "${LOCAL_DIR%/}/s3sync.downloaded"
}

upload() {
	if which s5cmd >/dev/null; then
		s5cmd --endpoint-url="${S3_ENDPOINT}" sync --delete "${LOCAL_DIR%/}/*" "${S3_PATH%/}/" 
	else
		aws s3 sync "${LOCAL_DIR}" "${S3_PATH}" --endpoint="${S3_ENDPOINT}" --delete
	fi
}

watch_upload() {
	inotifywait -mr "${LOCAL_DIR}" -e create -e delete -e move -e modify --format '%w%f %e' | \
	while read -r file _ ; do
		# ignore sqlite tmp files
		if [[ "${file}" =~ \.db-(journal|wal|shm)$ ]]; then
			continue
		fi
		# sleeping before execution to accumulate any other file changes...
		sleep 5
		upload
	done
}

main() {
	case "${1}" in
		download)
			download
			;;
		upload)
			watch_upload
			;;
		help|--help|-h)
			cat <<-EOF
			Usage: ${ME} [command]

			Commands:
			  upload - watch for changes in LOCAL_DIR and sync LOCAL_DIR to S3
			  download - download all remote files to LOCAL_DIR and exit
			EOF
			exit 0
			;;
		*)
			echo "$(date -u): Unknown command: ${1}" > /dev/stderr
			exit 1
			;;
	esac
}

if [[ -n "${ENABLE_S3_SYNC-}" ]]; then main "$@"; else echo 'ENABLE_S3_SYNC is not set'; while :; do sleep 1d; done; fi
