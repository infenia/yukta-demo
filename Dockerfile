# Public demo of Yukta: the released server on loopback, the standalone examples seeded at start,
# and nginx in front that adds an OPERATOR key to every request, so visitors run, approve and stop
# workflows without logging in but cannot create or change them.
ARG YUKTA_VERSION=0.1.0-alpha.5
FROM ghcr.io/infenia/yukta:${YUKTA_VERSION} AS yukta

# The server binary is glibc-linked (its own base is distroless/cc-debian12), so Debian, not Alpine.
FROM nginx:1.27-bookworm
ARG YUKTA_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends jq && rm -rf /var/lib/apt/lists/*
COPY --from=yukta /app/yukta /app/yukta
# The examples of the same release: run.sh scripts copy their helper files and apply supervisors,
# which the bundled /api/templates do not carry.
RUN curl -fsSL "https://codeload.github.com/infenia/yukta/tar.gz/refs/tags/v${YUKTA_VERSION}" \
      | tar -xz -C /opt --strip-components=1 --wildcards '*/examples' \
    && rm /etc/nginx/conf.d/default.conf \
    && sed -i -e '/^user /d' -e 's|^pid .*|pid /tmp/nginx.pid;|' /etc/nginx/nginx.conf \
    && chown -R nginx:nginx /etc/nginx/conf.d /var/cache/nginx
COPY nginx.conf.template /etc/nginx/templates/yukta.conf.template
COPY entrypoint.sh /entrypoint.sh

ENV PORT=10000
# Non-root throughout: hosts such as Render drop the capabilities needed to switch user later.
USER nginx
EXPOSE 10000
ENTRYPOINT ["/entrypoint.sh"]
