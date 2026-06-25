.PHONY: test fmt validate docs tidy help

SHELL := /bin/bash
TIMEOUT ?= 45m

help:
	@echo "Targets:"
	@echo "  test      Run the live Terratest integration test."
	@echo "  fmt       Format Terraform files."
	@echo "  validate  Validate the module and integration-test configuration."
	@echo "  docs      Generate the README Terraform reference."
	@echo "  tidy      Update Go module dependencies."

test:
	@command -v go >/dev/null 2>&1 || { echo "go is required"; exit 1; }
	@command -v terraform >/dev/null 2>&1 || { echo "terraform is required"; exit 1; }
	@echo "Running Terratest with timeout $(TIMEOUT) ..."
	go test -v -timeout $(TIMEOUT) ./test

fmt:
	terraform fmt -recursive

validate:
	terraform init -backend=false
	terraform validate -no-color
	cd test && terraform init -backend=false && terraform validate -no-color

docs:
	terraform-docs markdown table --output-file README.md --output-mode inject .

tidy:
	go mod tidy
