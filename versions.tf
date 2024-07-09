terraform {
  required_version = ">= 1.3"
  required_providers {

    google = {
      source  = "hashicorp/google"
      version = ">= 4.84, < 6"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.84, < 6"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 2.1"
    }
  }

  provider_meta "google" {
    module_name = "blueprints/terraform/terraform-google-lb-http:dynamic_backends/v11.1.0"
  }

  provider_meta "google-beta" {
    module_name = "blueprints/terraform/terraform-google-lb-http:dynamic_backends/v11.1.0"
  }

}
