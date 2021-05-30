.PHONY: compile invoke plan apply
.DEFAULT_GOAL := help
VERSION := 0.0.2
PKG_LIST := $(shell go list ${PKG}/... | grep -v /vendor/)
GO_FILES := $(shell find . -name '*.go' | grep -v /vendor/)
COMMIT_HASH := $(shell git rev-parse --short HEAD)
CURRENT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
MAIN_BRANCH := main
EXECUTABLE := hello
S3_BUCKET := $(shell grep source_bucket deployments/settings.tfvars | awk -F'\"' '{print $$2}')
S3_KEY := $(shell grep source_key deployments/settings.tfvars | awk -F'\"' '{print $$2}')

help:           ## Show this help.
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'


clean-venv:
	rm -rf .venv
	python3 -m venv .venv
	( \
       source .venv/bin/activate; \
       pip install --upgrade pip setuptools; \
    )

tfplan: ## run terraform plan
	( \
	   cd deployments; \
	   terraform init; \
	   terraform plan -var-file="settings.tfvars"; \
	)

tfapply: tfplan ## run terraform apply
	( \
	   cd deployments; \
	   terraform apply -var-file="settings.tfvars"; \
	)

tfdestroy: ## destroy the terraform created resources
	( \
	   cd deployments; \
	   terraform destroy -var-file="settings.tfvars"; \
	)

compile: ## delete/rebuild the go binary in  bin/
	@mkdir -p bin
	@rm -f bin/$(EXECUTABLE)
	@rm -f deployments/$(EXECUTABLE).zip
	docker run -e GOOS=linux -e GOARCH=amd64 \
	-v $$(pwd):/function \
	-v $$(pwd)/bin:/bin \
	-w /function golang:1.15 go build -ldflags="-s -w" -o /bin/$(EXECUTABLE)
	(cd bin && zip ../$(EXECUTABLE).zip $(EXECUTABLE))
	aws s3 cp $(EXECUTABLE).zip s3://$(S3_BUCKET)/$(S3_KEY)
	mv $(EXECUTABLE).zip deployments

invoke: ## invoke the lambda
	aws lambda invoke \
    --function-name $(EXECUTABLE) \
    --payload file://request.json \
    out.json


bump: static clean-venv  ## bump version in main branch
ifeq ($(CURRENT_BRANCH), $(MAIN_BRANCH))
	( \
	   source .venv/bin/activate; \
	   pip install bump2version; \
	   bump2version $(part); \
	)
else
	@echo "UNABLE TO BUMP - not on Main branch"
	$(info Current Branch: $(CURRENT_BRANCH), main: $(MAIN_BRANCH))
endif


test:
	go test -short ${PKG_LIST}

vet:
	go vet ${PKG_LIST}

lint:
	for file in ${GO_FILES} ;  do \
		golint $$file ; \
	done

static: vet lint test