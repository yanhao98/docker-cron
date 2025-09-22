curl -fsSL https://Git.1-H.CC/Scripts/Linux/raw/branch/main/postgres-dump-zstd-docker-sock.sh |
	sh -s -- \
		--socket=/var/run/docker.sock \
		--api-version=v1.51 \
		--backup-dir=/backups \
		--container=postgres17 \
		--backup-prefix=postgres17_all_databases_zstd_
