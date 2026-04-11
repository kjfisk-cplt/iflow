variable "app_defaults" {
  type = object({
    location = string
    environm = string
    
  })
  default = {
    location = "swedencentral"
    env = "dev"
  }
}