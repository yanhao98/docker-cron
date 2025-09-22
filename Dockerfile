FROM alpine:3.22.1 AS base

# 解决时区问题
ENV TZ=Asia/Shanghai
RUN apk add alpine-conf && \
    setup-timezone -z Asia/Shanghai && \
    apk del alpine-conf

FROM base AS final

# 安装 sqlite 工具，cron 默认已包含 (dcron)
RUN apk add --no-cache tini

# 时区
ENV TZ=Asia/Shanghai

# 启动脚本与任务脚本
COPY entrypoint.sh run-cron-tasks.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/run-cron-tasks.sh && \
    mkdir -p /docker-entrypoint-init.d /docker-cron.d /var/lib/cron-init

ENTRYPOINT ["/sbin/tini", "--", "entrypoint.sh"]
