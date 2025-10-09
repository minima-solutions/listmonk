# Builder: compile Go backend, build frontend, and pack assets
FROM golang:1.25-alpine AS builder

# Install GNU grep (for -P support) and other deps
RUN apk add --no-cache git build-base nodejs npm yarn grep

WORKDIR /src

# Speed up builds with dependency caching
COPY go.mod go.sum ./
RUN go mod download

# Frontend deps (cacheable layers)
COPY frontend/package.json frontend/yarn.lock frontend/
COPY frontend/email-builder/package.json frontend/email-builder/yarn.lock frontend/email-builder/
RUN mkdir -p static/public/static && cd frontend && yarn install --frozen-lockfile
RUN cd frontend/email-builder && yarn install --frozen-lockfile

# Copy the rest of the source
COPY . .

# Create .gitignore in frontend if it doesn't exist (for ESLint)
RUN touch frontend/.gitignore

# Optional: let CI pass a version string; Makefile reads LISTMONK_VERSION
ARG LISTMONK_VERSION
ENV LISTMONK_VERSION=${LISTMONK_VERSION}

# Build tool and final binary with packed assets
RUN go install github.com/knadh/stuffbin/...
RUN make dist

# Runtime: minimal image with entrypoint
FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata shadow su-exec
WORKDIR /listmonk

COPY --from=builder /src/listmonk .
COPY config.toml.sample config.toml
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 9000
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["./listmonk"]