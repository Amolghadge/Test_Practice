# Configure the Google Cloud Provider
#To test the conflict#
#Updated comment in main#
provider "google" {
  project = "your-gcp-project-id" # REPLACE with your GCP Project ID
  region  = "us-central1"          # Change to your desired GCP region
}

# Create a VPC Network
resource "google_compute_network" "vpc_network" {
  name                    = "my-terraform-network"
  auto_create_subnetworks = true # Creates a default subnet in each region
}

# Create a firewall rule to allow SSH
resource "google_compute_firewall" "ssh_firewall" {
  name    = "my-terraform-ssh-firewall"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"] # WARNING: Allows SSH from anywhere. Restrict in production!
  target_tags   = ["allow-ssh"]
}

# Create a Compute Engine instance (VM)
resource "google_compute_instance" "my_gcp_vm" {
  name         = "my-terraform-gcp-vm"
  machine_type = "e2-micro" # Free tier eligible in some regions
  zone         = "us-central1-a" # Change to a zone within your chosen region
  tags         = ["allow-ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" # Or "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
      # This block creates an ephemeral external IP.
    }
  }

  # SSH Key for login
  metadata = {
    ssh-keys = "${var.gcp_username}:${file(var.ssh_public_key_path)}"
  }

  labels = {
    environment = "dev"
  }
}

# Define variables for username and SSH key path
variable "gcp_username" {
  description = "The username for SSH access to the GCP VM."
  type        = string
  default     = "gcpuser" # Choose your desired username
}

variable "ssh_public_key_path" {
  description = "The path to your local public SSH key (e.g., ~/.ssh/id_rsa.pub)."
  type        = string
  default     = "~/.ssh/id_rsa.pub" # Adjust this path!
}

# Output the public IP address of the VM
output "instance_public_ip" {
  description = "The public IP address of the GCP instance."
  value       = google_compute_instance.my_gcp_vm.network_interface[0].access_config[0].nat_ip
}

# Configure the Google Cloud Provider
# Replace "your-gcp-project-id" with your actual GCP Project ID
provider "google" {
  project = "your-gcp-project-id"
  region  = "us-central1" # You can choose a different region, but buckets are global with regional locations
}

# 1. Create a Google Cloud Storage Bucket
# This resource defines a new storage bucket.
resource "google_storage_bucket" "my_terraform_bucket" {
  # Required: Name of the bucket. Must be globally unique.
  # Best practice: Use a descriptive name, often including your project ID or a unique prefix.
  name          = "my-unique-terraform-bucket-06072025-pune" # Replace with a globally unique name!

  # Optional: Location of the bucket's data.
  # Can be a multi-region (e.g., "US", "ASIA", "EU") or a dual-region (e.g., "NAM4") or a single region (e.g., "us-central1").
  # For single-region buckets, it's good practice to set it to a specific region.
  location      = "US-CENTRAL1" # Example: "US", "EUROPE", "ASIA", "us-east1", "asia-south1", etc.

  # Optional: Storage class for the bucket.
  # Standard (default), Nearline, Coldline, Archive.
  storage_class = "STANDARD"

  # Optional: Versioning for objects in the bucket.
  # Keeps previous versions of objects when they are overwritten or deleted.
  versioning {
    enabled = true
  }

  # Optional: Lifecycle rules for objects.
  # Automatically manages objects (e.g., deletes after a period, moves to cheaper storage).
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 365 # Delete objects older than 365 days
    }
  }

  lifecycle_rule {
    action {
      type = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition {
      age = 30 # Move objects to COLDLINE after 30 days
    }
  }

  # Optional: Prevents accidental deletion of the bucket until manually removed.
  # Set to true for critical buckets. Requires `force_destroy = true` to delete the bucket.
  force_destroy = false # Set to true to allow Terraform to destroy the bucket even if it's not empty. Be careful!

  # Optional: Access control list (ACL) for the bucket.
  # "private" (default), "publicRead", "publicReadWrite", etc.
  # Generally, prefer IAM policies over ACLs for finer-grained control.
  # uniform_bucket_level_access = true # Recommended for simplifying access control. Set to true to disable object ACLs.

  # Optional: Labels for organization and billing.
  labels = {
    environment = "development"
    managed_by  = "terraform"
    project     = "demo"
  }

  # Optional: Encryption configuration (e.g., using Customer-Managed Encryption Keys - CMEK)
  # encryption {
  #   default_kms_key_name = "projects/your-gcp-project-id/locations/us-central1/keyRings/my-keyring/cryptoKeys/my-key"
  # }

  # Optional: Websites serving from the bucket
  # website {
  #   main_page_suffix = "index.html"
  #   not_found_page   = "404.html"
  # }
}

# 2. Upload an object to the bucket (optional, but common)
# This resource uploads a file from your local machine to the bucket.
resource "google_storage_bucket_object" "my_example_object" {
  name   = "hello-world.txt"                   # Name of the object in the bucket
  bucket = google_storage_bucket.my_terraform_bucket.name
  source = "files/hello.txt"                   # Path to the local file to upload. Create a 'files' directory and 'hello.txt'.
  # content_type = "text/plain"                # Optional: MIME type of the object
  # cache_control = "public, max-age=3600"     # Optional: Cache control headers
}

# 3. Grant IAM permissions on the bucket (optional, but important for access control)
# This resource grants a specific Google Cloud IAM member (user, service account, group)
# a role on the bucket.
resource "google_storage_bucket_iam_member" "viewer_access" {
  bucket = google_storage_bucket.my_terraform_bucket.name
  role   = "roles/storage.objectViewer" # Role to grant (e.g., viewer, editor, owner)
  member = "user:example-user@example.com" # Replace with the actual email of the user/service account
}

# 4. Output the bucket's self-link
# This output allows you to easily retrieve the bucket's URL after deployment.
output "bucket_self_link" {
  description = "The self_link of the created GCP Storage bucket."
  value       = google_storage_bucket.my_terraform_bucket.self_link
}

# 5. Output the object's public URL (if public)
output "object_public_url" {
  description = "The public URL of the uploaded object (if public)."
  value       = "gs://${google_storage_bucket.my_terraform_bucket.name}/${google_storage_bucket_object.my_example_object.name}"
}



##Test
