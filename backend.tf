terraform {
  backend "gcs" {
    bucket  = "csnow-orca-test-tfstate"
    prefix  = "terraform-gcp-simple-state"
  }
}
