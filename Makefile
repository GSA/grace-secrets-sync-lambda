hooksPath := $(git config --get core.hooksPath)

export appenv := DEVELOPMENT
export TF_VAR_appenv := $(appenv)
GOBIN := $(GOPATH)/bin
TFSEC := $(GOBIN)/tfsec

.PHONY: precommit test deploy check lint_lambda test_lambda build_lambda release_lambda validate_terraform init_terraform apply_terraform apply_terraform_tests destroy_terraform_tests clean
test: test_lambda validate_terraform

deploy: build_lambda

check: precommit
ifeq ($(strip $(TF_VAR_appenv)),)
	@echo "TF_VAR_appenv must be provided"
	@exit 1
else
	@echo "appenv: $(TF_VAR_appenv)"
endif

lint_lambda: precommit
	make -C lambda lint

test_lambda: precommit
	make -C lambda test

build_lambda: precommit
	make -C lambda build

release_lambda: precommit
	make -C lambda release

validate_terraform: init_terraform $(TFSEC)
	terraform validate
	$(TFSEC)

init_terraform: check
	[[ -d release ]] || mkdir release
	[[ -e release/grace-secrets-sync-lambda.zip ]] || touch release/grace-secrets-sync-lambda.zip
	terraform init
	terraform fmt

apply_terraform: apply_terraform_tests

apply_terraform_tests:
	make -C tests apply

destroy_terraform_tests:
	make -C tests destroy

clean: precommit
	make -C lambda clean

precommit:
ifneq ($(strip $(hooksPath)),.github/hooks)
	@git config --add core.hooksPath .github/hooks
endif

$(TFSEC):
	go get -u github.com/liamg/tfsec/cmd/tfsec