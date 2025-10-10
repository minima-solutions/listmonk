#!/usr/bin/env bash
set -eu

printf '\n'

RED="$(tput setaf 1 2>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
NO_COLOR="$(tput sgr0 2>/dev/null || printf '')"

info() {
  printf '%s\n' "${BLUE}> ${NO_COLOR} $*"
}

error() {
  printf '%s\n' "${RED}x $*${NO_COLOR}" >&2
}

completed() {
  printf '%s\n' "${GREEN}✓ ${NO_COLOR} $*"
}

exists() {
  command -v "$1" >/dev/null 2>&1
}


is_healthy() {
	info "waiting for db container to be up. retrying in 3s"
	health_status="$(docker inspect -f "{{.State.Health.Status}}" "$1")"
	if [ "$health_status" = "healthy" ]; then
		return 0
	else
		return 1
	fi
}

is_running() {
	info "checking if $1 is running"
	status="$(docker inspect -f "{{.State.Status}}" "$1")"
	if [ "$status" = "running" ]; then
		return 0
	else
		return 1
	fi
}

run_migrations(){
	info "running migrations"
	docker compose -f docker-compose.dev.yml up -d db
	while ! is_healthy listmonk_db; do sleep 3; done
	docker compose -f docker-compose.dev.yml run --rm app ./listmonk --install
}

start_services(){
	info "starting app"
	docker compose -f docker-compose.dev.yml  up -d app db
}

show_output(){
	info "finishing setup"
	sleep 3

	if is_running listmonk_db && is_running listmonk_app
	then completed "Listmonk is now up and running. Visit http://localhost:9000 in your browser."
	else
		error "error running containers. something went wrong."
	fi
}

run_migrations
start_services
show_output