## Module 3 - Lab assignment
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
resource "google_compute_network" "vpc2" {
  name = "vpc2"
  auto_create_subnetworks = "false"
}


// Create VPC Peering
resource "google_compute_network_peering" "vpc-peer-1to2" {
  name = "vpc-peer-1to2"
  network = google_compute_network.vpc1.self_link
  peer_network = google_compute_network.vpc2.self_link
  
  import_custom_routes = true
  export_custom_routes = true

  ## Anthony suspects that the routes created in the startup scripts are not added to the VPC peering routing tables
  depends_on = [ google_compute_instance.vm1, google_compute_instance.vm2 ]
}
resource "google_compute_network_peering" "vpc-peer-2to1" {
  name = "vpc-peer-2to1"
  network = google_compute_network.vpc2.self_link
  peer_network = google_compute_network.vpc1.self_link

  import_custom_routes = true
  export_custom_routes = true

  ## Anthony suspects that the routes created in the startup scripts are not added to the VPC peering routing tables
  depends_on = [ google_compute_instance.vm1, google_compute_instance.vm2 ]
}


// Create the subnet
resource "google_compute_subnetwork" "sub1" {
  name = "sub1"
  ip_cidr_range = "172.16.0.0/24"
  region = "us-central1"
  network = google_compute_network.vpc1.self_link
}
resource "google_compute_subnetwork" "sub2" {
  name = "sub2"
  ip_cidr_range = "172.16.1.0/24"
  region = "us-east1"
  network = google_compute_network.vpc2.self_link
}


// Create Cloud Router
resource "google_compute_router" "cloud-router" {
  name = "cloud-router"
  network = google_compute_network.vpc2.self_link
  region = google_compute_subnetwork.sub2.region
}


// Create Cloud NAT
resource "google_compute_router_nat" "cloud-nat" {
  name = "cloud-nat"
  router = google_compute_router.cloud-router.name
  region = google_compute_subnetwork.sub2.region
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {  # Does this force NAT to the right region as the router?
    name = google_compute_subnetwork.sub2.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  # depends_on = [google_compute_router.cloud-router]  # Cannot add the NAT if the router is not up

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
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
    protocol  = "udp"  # vxlan runs on UDP
    ports     = ["50000"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}
resource "google_compute_firewall" "fwrule2" {
  name = "fwrule2"
  network = google_compute_network.vpc2.self_link
  depends_on = [google_compute_network.vpc2]  # TF meta-argument

  allow {
    protocol  = "tcp"
    ports     = ["22", "1234"]
  }
  allow {
    protocol  = "udp"  # vxlan runs on UDP
    ports     = ["50000"]
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
    # access_config {
    #   network_tier = "STANDARD" // This indicates to give a public IP address
    # }
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
    sudo apt -y install netcat-traditional ncat &>~/install.log

    sudo ip link add vxlan0 type vxlan id 5001 local 172.16.0.2 remote 172.16.1.2 dev ens4 dstport 50000
    sudo ip addr add 192.168.100.2/24 dev vxlan0  # Implicit route add
    sudo ip link set up dev vxlan0

    sudo ip route add 34.223.124.0/24 via 192.168.100.3  # Direct IP to neverssl.com - This works.
    # sudo ip route add 34.223.124.45/32 via 192.168.100.3  # Also works.

    EOF
  }
}
resource "google_compute_instance" "vm2" {
  name = "vm2"
  machine_type = "e2-micro"
  zone = "us-east1-d"  # us-east1-a zone is down when I ran this code
  depends_on = [google_compute_network.vpc2, google_compute_subnetwork.sub2]
  network_interface {
    
    # When access_config isn't provided, the VM would not have a public IP
    # access_config {
    #   network_tier = "STANDARD" // This indicates to give a public IP address
    # }
    
    network_ip = "172.16.1.2"
    nic_type = "VIRTIO_NET"
    stack_type = "IPV4_ONLY"
    network = google_compute_network.vpc2.self_link
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
    sudo apt -y install netcat-traditional ncat &>~/install.log

    sudo ip link add vxlan0 type vxlan id 5001 remote 172.16.0.2 local 172.16.1.2 dev ens4 dstport 50000
    sudo ip addr add 192.168.100.3/24 dev vxlan0  # Implicit route add
    sudo ip link set up dev vxlan0

    # Uncomment these lines to tell VM2 what to deal with packet from VM1 for neverssl.com
    sudo sh -c 'echo "1" > /proc/sys/net/ipv4/ip_forward'  # Can also edit the /etc/sysctl.conf
    sudo sysctl -p  # Load sysctl conf again
    sudo iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o ens4 -j MASQUERADE
    # sudo iptables -t nat -A POSTROUTING -s 192.168.0.0/16 -o ens4 -j MASQUERADE  # Also works.

    EOF
  }
}
