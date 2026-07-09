provider "google" {
  project      = "${var.project}"
  region       = "us-west1"
  zone 	       = "us-west1-a"
}


data "google_compute_image" "latest_ubuntu" {
  family  = "ubuntu-2510-amd64"
  project = "ubuntu-os-cloud"
}

resource "google_compute_instance" "default" {
    count = var.node_count
    name = "${var.prefix}-${count.index}"
    machine_type = "e2-medium"
    #machine_type = "n2-standard-4"
    allow_stopping_for_update = true

    boot_disk {
         initialize_params {
             image =  data.google_compute_image.latest_ubuntu.self_link
             #image =  "projects/csnow-orca-test/global/machineImages/csnow-ubuntu-image-01"
             #image =  "ubuntu-2510-questing-amd64-v20260320"
             size  = 100
         }
    }

#    can_ip_forward = true
#    guest_accelerator {
#      type  = "nvidia-tesla-t4" # Example: T4 GPU
#      count = 1
#    }
#
#    scheduling {
#      on_host_maintenance = "TERMINATE" # Required for GPU instances
#      automatic_restart   = true
#    }
#
#    metadata = {
#      install-nvidia-driver = "True" # Installs drivers on startup
#    }

    network_interface {
        network = "${var.vpc}"
	        subnetwork = "${var.subnet}"
        access_config {
            # nat_ip is here
        }
    }

    #depends_on = ["google_compute_firewall.default"]
}

resource "google_storage_bucket" "scan_test_bucket" {
  name          = "${var.bucket_name}"
  location      = "US" # Multi-region US, or use a specific region like "US-CENTRAL1"
  force_destroy = true  # Allows Terraform to delete the bucket even if it contains objects

  # Optional: standard security and lifecycle settings
  public_access_prevention = "enforced"
  
  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "scan_test_bucket_2" {
  name          = "csnow-orca-test-bucket-02"
  location      = "us-west1" # Multi-region US, or use a specific region like "US-CENTRAL1"
  force_destroy = true  # Allows Terraform to delete the bucket even if it contains objects

  # Optional: standard security and lifecycle settings
  public_access_prevention = "enforced"

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true
}

resource "google_container_cluster" "orca-gke-public" {
  name     = "${var.prefix}-gke-02"
  location = "us-west1-a"
  deletion_protection = false
  remove_default_node_pool = false

  # We can define additional properties such as node pools, networking, etc.
  initial_node_count = 1
  node_config {
    machine_type = "e2-micro"

    # Configure the OAuth scopes to allow the nodes to access Google Cloud services
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  network = "${var.vpc}"
  subnetwork = "${var.subnet}"

  # Enable some addons for the cluster
  addons_config {
    http_load_balancing        { disabled = false }
    horizontal_pod_autoscaling { disabled = false }
  }
}

resource "google_container_cluster" "orca-gke-private" {
  name     = "${var.prefix}-private-gke-02"
  location = "us-west1-a"
  deletion_protection = false
  remove_default_node_pool = false

  # We can define additional properties such as node pools, networking, etc.
  initial_node_count = 1
  node_config {
    machine_type = "e2-small"

    # Configure the OAuth scopes to allow the nodes to access Google Cloud services
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "10.0.0.0/18"
      display_name = "internal-vpc-access"
    }
    #cidr_blocks {
    #  cidr_block   = "44.192.133.0/29"
    #  display_name = "Orca Security Scanner"
    #}
  }

  network = "${var.vpc}"
  subnetwork = "${var.subnet}"

  # Enable some addons for the cluster
  #addons_config {
  #  http_load_balancing        { disabled = false }
  #  horizontal_pod_autoscaling { disabled = false }
  #}
}
