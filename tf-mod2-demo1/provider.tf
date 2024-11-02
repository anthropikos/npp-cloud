
//https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference
provider "google" {
  credentials = file("~/cloud-networking-course-2323de37b6d1.json")

  project = "cloud-networking-course"
  region  = "us-central1"
  zone    = "us-central1-c"
}
