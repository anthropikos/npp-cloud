## Quick two VM setup for testing
## Anthony Lee 2024-11-02

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.51.0"
    }
  }
}


// Create the VPC
resource "google_compute_network" "vpc1" {
  name = "vpc1"
  auto_create_subnetworks = "false"
}


// Create the subnet
resource "google_compute_subnetwork" "sub1" {
  name = "sub1"
  ip_cidr_range = "172.16.0.0/24"
  region = "us-central1"
  network = google_compute_network.vpc1.self_link
  depends_on = [ google_compute_network.vpc1 ]
}
resource "google_compute_subnetwork" "sub2" {
  name = "sub2"
  ip_cidr_range = "172.16.1.0/24"
  region = "us-east1"
  network = google_compute_network.vpc1.self_link
  depends_on = [ google_compute_network.vpc1 ]
}




// Create Firewall rule - allow icmp, tcp:22 (ssh), and tcp:1234 (custom)
resource "google_compute_firewall" "fwrule1" {
  name = "fwrule1"
  network = google_compute_network.vpc1.self_link
  depends_on = [google_compute_network.vpc1]  # TF meta-argument

  allow {
    protocol  = "tcp"
    ports     = ["22", "1234"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}




// Create a VM, and put it inside of subnet1
resource "google_compute_instance" "vm1" {
  name = "vm1"
  machine_type = "e2-micro"
  zone = "us-central1-a"
  depends_on = [google_compute_network.vpc1, google_compute_subnetwork.sub1]
  network_interface {
    
    # When access_config isn't provided, the VM would not have a public IP
    access_config {
      network_tier = "STANDARD" // This indicates to give a public IP address
    }
    network_ip = "172.16.0.2"
    nic_type = "VIRTIO_NET"
    stack_type = "IPV4_ONLY"
    network = google_compute_network.vpc1.self_link
    subnetwork = google_compute_subnetwork.sub1.self_link
  }

  boot_disk {
    initialize_params {
      image = "debian-12-bookworm-v20240312"
    }
  } 
  metadata = {
    startup-script = <<-EOF
    sudo apt -y update &>~/update.log
    sudo apt -y install netcat-traditional ncat tshark iptables &>~/install.log
    EOF
  }
}
resource "google_compute_instance" "vm2" {
  name = "vm2"
  machine_type = "e2-micro"
  zone = "us-east1-d"  # us-east1-a zone is down when I ran this code
  depends_on = [google_compute_network.vpc1, google_compute_subnetwork.sub2]
  network_interface {
    
    # When access_config isn't provided, the VM would not have a public IP
    access_config {
      network_tier = "STANDARD" // This indicates to give a public IP address
    }
    
    network_ip = "172.16.1.2"
    nic_type = "VIRTIO_NET"
    stack_type = "IPV4_ONLY"
    network = google_compute_network.vpc1.self_link
    subnetwork = google_compute_subnetwork.sub2.self_link
  }

  boot_disk {
    initialize_params {
      image = "debian-12-bookworm-v20240312"
    }
  } 
  metadata = {
    startup-script = <<-EOF
    sudo apt -y update &>~/update.log
    sudo apt -y install netcat-traditional ncat tshark iptables &>~/install.log
    EOF
  }
}
resource "google_compute_instance" "vm3" {
  name = "vm3"
  machine_type = "e2-micro"
  zone = "us-central1-a"
  depends_on = [google_compute_network.vpc1, google_compute_subnetwork.sub1]
  network_interface {
    
    # When access_config isn't provided, the VM would not have a public IP
    access_config {
      network_tier = "STANDARD" // This indicates to give a public IP address
    }
    network_ip = "172.16.0.3"
    nic_type = "VIRTIO_NET"
    stack_type = "IPV4_ONLY"
    network = google_compute_network.vpc1.self_link
    subnetwork = google_compute_subnetwork.sub1.self_link
  }

  boot_disk {
    initialize_params {
      image = "debian-12-bookworm-v20240312"
    }
  } 
  metadata = {
    startup-script = <<-EOF
    sudo apt -y update &>~/update.log
    sudo apt -y install netcat-traditional ncat tshark iptables &>~/install.log
    EOF
  }
}