# Configure the Google Cloud Provider
#To test the conflict#
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