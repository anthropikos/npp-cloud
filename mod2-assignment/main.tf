## Notes - Anthony Lee 2024-10-31
## - Startup script apt install need to make sure to have yes flag. I realized
##   that the packages were not installed because bash was waiting for a user 
##   prompt of Y/n.
## - When a VM doesn't have a public IP, it doesn't have access to the internet.
## - Even when a VM doesn't have a public IP and thus cannot access the internet, 
##   it is still able to ping the other VM on the same VPC (even if they are in
##   two different subnets) assuming that the firewall policy allows for ICMP 
##   traffic.

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.51.0"
    }
  }
}


// Note: If you need to reference the outputs (assigned values)
// https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork#id
// https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network#id

// Create the VPC
// https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network

resource "google_compute_network" "mod2-vpc1" {
  name = "mod2-vpc1"
  auto_create_subnetworks = "false"
}
resource "google_compute_network" "mod2-vpc2" {
  name = "mod2-vpc2"
  auto_create_subnetworks = "false"
}



// Create the subnet
// https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork

resource "google_compute_subnetwork" "mod2-vpc1-sub1" {
  name          = "mod2-vpc1-sub1"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.mod2-vpc1.id
}
resource "google_compute_subnetwork" "mod2-vpc2-sub1" {
  name          = "mod2-vpc2-sub1"
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-central1"
  network       = google_compute_network.mod2-vpc2.id
}
resource "google_compute_subnetwork" "mod2-vpc2-sub2" {
  name          = "mod2-vpc2-sub2"
  ip_cidr_range = "10.0.3.0/24"
  region        = "us-central1"
  network       = google_compute_network.mod2-vpc2.id
}



// Create Firewall rule - allow icmp, tcp:22 (ssh), and tcp:1234 (custom)
//https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall
resource "google_compute_firewall" "mod2-vpc1-fwrule1" {
  project = "cloud-networking-course"
  name        = "mod2-vpc1-fwrule1"
  network     = google_compute_network.mod2-vpc1.id
  depends_on = [google_compute_network.mod2-vpc1]  # VPC needs to be created prior to the firewall rules

  allow {
    protocol  = "tcp"
    ports     = ["22", "1234"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}
resource "google_compute_firewall" "mod2-vpc2-fwrule1" {
  project = "cloud-networking-course"
  name        = "mod2-vpc2-fwrule1"
  network     = google_compute_network.mod2-vpc2.id
  depends_on = [google_compute_network.mod2-vpc2]  # VPC needs to be created prior to the firewall rules

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
// https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
resource "google_compute_instance" "mod2-vpc1-sub1-vm1" {
  name = "mod2-vpc1-sub1-vm1"
  machine_type = "e2-micro"
  zone = "us-central1-a"
  depends_on = [google_compute_network.mod2-vpc1, google_compute_subnetwork.mod2-vpc1-sub1]
  network_interface {
    
    # When access_config isn't provided, the VM would not have a public IP
    access_config {
      network_tier = "STANDARD" // This indicates to give a public IP address
    }
    
    nic_type = "VIRTIO_NET"
    stack_type = "IPV4_ONLY"
    network = google_compute_network.mod2-vpc1.self_link
    subnetwork = google_compute_subnetwork.mod2-vpc1-sub1.self_link
  }

  boot_disk {
    initialize_params {
      image = "debian-12-bookworm-v20240312"
    }
  } 
  metadata = {
    startup-script = "sudo apt -y update &>~/update.log; sudo apt -y install netcat-traditional ncat &>~/install.log;"
    }
  # metadata = {
  #   startup-script = <<-EOF
  #   sudo apt -y update &>~/update.log;
  #   sudo apt -y install netcat-traditional ncat &>~/install.log;
  #   EOF
  # }
}
resource "google_compute_instance" "mod2-vpc2-sub1-vm1" {
  name = "mod2-vpc2-sub1-vm1"
  machine_type = "e2-micro"
  zone = "us-central1-a"
  depends_on = [google_compute_network.mod2-vpc2, google_compute_subnetwork.mod2-vpc2-sub1]
  network_interface {
    
    # When access_config isn't provided, the VM would not have a public IP
    access_config {
      network_tier = "STANDARD" // This indicates to give a public IP address
    }
    
    nic_type = "VIRTIO_NET"
    stack_type = "IPV4_ONLY"
    network = google_compute_network.mod2-vpc2.self_link
    subnetwork = google_compute_subnetwork.mod2-vpc2-sub1.self_link
  }

  boot_disk {
    initialize_params {
      image = "debian-12-bookworm-v20240312"
    }
  } 
  metadata = {
    startup-script = "sudo apt -y update &>~/update.log; sudo apt -y install netcat-traditional ncat &>~/install.log;"
    }
  # metadata = {
  #   startup-script = <<-EOF
  #   sudo apt -y update &>~/update.log;
  #   sudo apt -y install netcat-traditional ncat &>~/install.log;
  #   EOF
  # }
}
resource "google_compute_instance" "mod2-vpc2-sub1-vm2" {
  name = "mod2-vpc2-sub1-vm2"
  machine_type = "e2-micro"
  zone = "us-central1-a"
  depends_on = [google_compute_network.mod2-vpc2, google_compute_subnetwork.mod2-vpc2-sub1]
  network_interface {
    
    # When access_config isn't provided, the VM would not have a public IP
    # access_config {
    #   network_tier = "STANDARD" // This indicates to give a public IP address
    # }
    
    nic_type = "VIRTIO_NET"
    stack_type = "IPV4_ONLY"
    network = google_compute_network.mod2-vpc2.self_link
    subnetwork = google_compute_subnetwork.mod2-vpc2-sub1.self_link
  }

  boot_disk {
    initialize_params {
      image = "debian-12-bookworm-v20240312"
    }
  } 
  metadata = {
    startup-script = "sudo apt -y update &>~/update.log; sudo apt -y install netcat-traditional ncat &>~/install.log;"
    }
  # metadata = {
  #   startup-script = <<-EOF
  #   sudo apt -y update &>~/update.log;
  #   sudo apt -y install netcat-traditional ncat &>~/install.log;
  #   EOF
  # }
}
resource "google_compute_instance" "mod2-vpc2-sub2-vm1" {
  name = "mod2-vpc2-sub2-vm1"
  machine_type = "e2-micro"
  zone = "us-central1-a"
  depends_on = [google_compute_network.mod2-vpc2, google_compute_subnetwork.mod2-vpc2-sub2]
  network_interface {
    
    # When access_config isn't provided, the VM would not have a public IP
    # access_config {
    #   network_tier = "STANDARD" // This indicates to give a public IP address
    # }
    
    nic_type = "VIRTIO_NET"
    stack_type = "IPV4_ONLY"
    network = google_compute_network.mod2-vpc2.self_link
    subnetwork = google_compute_subnetwork.mod2-vpc2-sub2.self_link
  }

  boot_disk {
    initialize_params {
      image = "debian-12-bookworm-v20240312"
    }
  } 
  metadata = {
    startup-script = "sudo apt update &>~/update.log; sudo apt install netcat-traditional ncat &>~/install.log;"
    }
  # metadata = {
  #   startup-script = <<-EOF
  #   sudo apt update &>~/update.log;
  #   sudo apt install netcat-traditional ncat &>~/install.log;
  #   EOF
  # }
}