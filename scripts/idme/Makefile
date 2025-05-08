# -------- variables you want to override --------
PROJECT       := $(shell gcloud config get-value project 2>/dev/null)
REGION        := us-east1
# single-zone VMs
ZONE          := $(REGION)-b
# GKE version (major.minor)
CLUSTER_VER   := 1.30
CLUSTER_NAME  := consul-cluster
IMAGE_FAMILY  := hashistack-client
IMAGE_NAME    := $(IMAGE_FAMILY)-$$(date +%Y%m%d%H%M)
CONSUL_CP_VER := 1.1.2
CONSUL_DP_VER := 1.1.2
CONSUL_VER    := 1.15.3-ent
NOMAD_VER     := 1.8.6+ent
NODE_MACHINE  := n2-custom-36-167936

# -------- targets --------
.PHONY: all cluster consul image clients nomad clean

all: cluster consul image clients nomad

cluster: scripts/01-gke-create.sh
	@bash $< "$(PROJECT)" "$(REGION)" "$(CLUSTER_NAME)" "$(CLUSTER_VER)" "$(NODE_MACHINE)"

consul: scripts/02-consul-install.sh
	@bash $< "$(CLUSTER_NAME)" "$(REGION)" "$(CONSUL_CP_VER)" "$(CONSUL_DP_VER)" "$(CONSUL_VER)"

image: scripts/03-image-build.sh
	@bash $< "$(PROJECT)" "$(REGION)" "$(IMAGE_NAME)" "$(IMAGE_FAMILY)" "$(NOMAD_VER)" "$(CONSUL_VER)"

clients: scripts/04-client-mig-create.sh
	@bash $< "$(PROJECT)" "$(ZONE)" "$(IMAGE_FAMILY)" "$(CLUSTER_NAME)"

nomad: scripts/05-nomad-servers-create.sh
	@bash $< "$(PROJECT)" "$(ZONE)" "$(IMAGE_FAMILY)"

clean:
	@echo "Cleanup steps left to the reader—for safety 🙃"
