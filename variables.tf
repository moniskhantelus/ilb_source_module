variable "project_id" {
  description = "The project to deploy to, if not set the default provider project is used."
}

variable "name" {
  description = "Name for the forwarding rule and prefix for supporting resources."
}

variable "region" {
  description = "Region for cloud resources."
  default     = "us-central1"
}

variable "global_access" {
  description = "Allow all regions on the same VPC network access."
  type        = bool
  default     = true
}

variable "network_project" {
  description = "Name of the project for the network. Useful for shared VPC. Default is var.project."
}

variable "network" {
  description = "Name of the network to create resources in."
}

variable "lb_subnet" {
  description = "Name of the LB subnetwork to create resources on."
}

variable "ip_address" {
  description = "IP address of the internal load balancer, if empty one will be assigned. Default is empty."
}

variable "fqdn" {
  description = "FQDN of the internal load balancer."
}

variable "backend_timeout_sec" {
  description = "The backend timeout in seconds."
  type        = number
  default     = 10
}

variable "session_affinity" {
  description = "Type of session affinity to use. The default is NONE. Session affinity is not applicable if the protocol is UDP. Possible values are NONE, CLIENT_IP, CLIENT_IP_PORT_PROTO, CLIENT_IP_PROTO, GENERATED_COOKIE, HEADER_FIELD, HTTP_COOKIE, and CLIENT_IP_NO_DESTINATION."
  default     = "NONE"
}

variable "locality_lb_policy" {
  description = "The load balancing algorithm used within the scope of the locality. The possible values are ROUND_ROBIN, LEAST_REQUEST, RING_HASH, RANDOM, ORIGNAL_DESTINATION, MAGLEV."
  default     = "RING_HASH"
}

variable "backends" {
  description = "List of backends, should be a map of key-value pairs for each backend, must have the 'group' key."
  type = list(object(
    { balancing_mode        = string,
      capacity_scaler       = string,
      group                 = string,
      description           = string,
      max_rate              = string,
      max_rate_per_instance = string,
      max_rate_per_endpoint = string,
  }))
}

variable "https_redirect" {
  description = "Set to `true` to enable https redirect on the lb."
  type        = bool
  default     = false
}

variable "http_forward" {
  description = "Set to `false` to disable HTTP port 80 forward"
  type        = bool
  default     = true
}

variable "ssl" {
  description = "Set to `true` to enable SSL support, requires variable `ssl_certificates` - a list of self_link certs"
  type        = bool
  default     = false
}

variable "ssl_certificates" {
  description = "SSL cert self_link list. Required if `ssl` is `true`."
  type        = list(string)
  default     = []
}

variable "health_check" {
  description = "Health check to determine whether instances are responsive and able to do work"
  type = object({
    type                = string
    check_interval_sec  = number
    healthy_threshold   = number
    timeout_sec         = number
    unhealthy_threshold = number
    response            = string
    proxy_header        = string
    port                = number
    port_name           = string
    request             = string
    request_path        = string
    host                = string
    enable_log          = bool
  })
}

variable "consistent_hash" {
  description = "Consistent Hash-based load balancing can be used to provide soft session affinity based on HTTP headers, cookies or other properties. This load balancing policy is applicable only for HTTP connections. The affinity to a particular destination host will be lost when one or more hosts are added/removed from the destination service. This field specifies parameters that control consistent hashing. This field only applies when locality_lb_policy is set tp RING_HASH or SESSION_AFFINITY is not NONE"
  type = object({
    http_cookie = object({
      ttl = object({
        seconds = number
        nanos   = number
      })
      name = string
      path = string
    })
    http_header_name  = string
    minimum_ring_size = number
  })
  default = null
}
